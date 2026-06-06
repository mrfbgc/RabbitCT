#include <cuda_runtime.h>
#include "rabbitCt.h"
/* ---------- GPU constant memory: projection matrix ---------- */
__constant__ double d_matrix[12]; // aN in its baseline implementation.

/* ---------- GPU global memory ---------- */
static float *d_volume = NULL;
static float *d_image  = NULL;
 
// Helper function to access pixel values with boundary check. the reason for using __device__ is, we access this function inside of the kernel(GPU). 
// Thus, we also need to use the data from the GPU memory.
__device__ static inline double pN(const float *image, int i, int j,
                                    int width, int height)
{
  if (i >= 0 && i < width && j >= 0 && j < height)
    return image[j * width + i];
  return 0.0;
}

// helper function for bilinear interpolation. as same reason as pN, we need to use __device__ here since we access this function inside of the kernel(GPU).
__device__ static inline double pHatN(const float *image, double x, double y,
                                       int width, int height)
{
  int i        = (int)x;
  int j        = (int)y;
  double alpha = x - (int)x;
  double beta  = y - (int)y;
  return (1.0 - alpha) * (1.0 - beta) * pN(image, i,   j,   width, height) +
         alpha          * (1.0 - beta) * pN(image, i+1, j,   width, height) +
         (1.0 - alpha)  * beta         * pN(image, i,   j+1, width, height) +
         alpha          * beta         * pN(image, i+1, j+1, width, height);
}


// this is the kernel function for backprojection which will be executed on the gpu. the reason for using __global__ is, this function will be called from the CPU and executed on the GPU.
__global__ void backprojectKernel(float *volume,
                                   const float *image,
                                   int l, float oL, float rL,
                                   int imageWidth, int imageHeight)
{
  int i = blockIdx.x * blockDim.x + threadIdx.x; // calculate the global thread index for x dimension.
  int j = blockIdx.y * blockDim.y + threadIdx.y; // calculate the global thread index for y dimension.
  if (i >= l || j >= l) return; // check if the grid can be divided to int.

  double x = oL + (double)i * rL; // real world coordinate of the voxel.
  double y = oL + (double)j * rL; // real world coordinate of the voxel.

  for (int k = 0; k < l; k++) {  // each thread will loop through the z dimension of the volume, and calculate the contribution of each voxel to the final image.
    double z = oL + (double)k * rL;
    double wN = d_matrix[2]*x + d_matrix[5]*y + d_matrix[8]*z  + d_matrix[11];
    double uN = (d_matrix[0]*x + d_matrix[3]*y + d_matrix[6]*z + d_matrix[9])  / wN;
    double vN = (d_matrix[1]*x + d_matrix[4]*y + d_matrix[7]*z + d_matrix[10]) / wN;
    volume[k*l*l + j*l + i] += (float)(1.0/(wN*wN) *
                                 pHatN(image, uN, vN, imageWidth, imageHeight));
  }
}
/* ---------- CPU part ---------- */
extern "C" int lolaCudaPrepare(RabbitCtGlobalData *r)
{
  int l = r->problemSize;
  cudaMalloc(&d_volume, (size_t)l*l*l * sizeof(float));
  cudaMemset(d_volume, 0, (size_t)l*l*l * sizeof(float));
  cudaMalloc(&d_image, r->imageWidth * r->imageHeight * sizeof(float));
  return 1;
}
extern "C" int lolaCudaBackprojection(RabbitCtGlobalData *r)
{
  int l           = r->problemSize;
  float oL        = r->O_Index;
  float rL        = r->voxelSize;
  int imageWidth  = r->imageWidth;
  int imageHeight = r->imageHeight;

  // the projection loop is still in CPU, because we need to process every projection sequentially. race condition (parallel)?
  for (int p = 0; p < (int)r->numberOfProjections; p++) {
    cudaMemcpyToSymbol(d_matrix,
                       r->projectionBuffer[p].matrix,
                       12 * sizeof(double));
    cudaMemcpy(d_image,
               r->projectionBuffer[p].image,
               imageWidth * imageHeight * sizeof(float),
               cudaMemcpyHostToDevice);
    dim3 block(16, 16); // 32 thread block, called warp.
    dim3 grid((l + 15) / 16, (l + 15) / 16); 
    
    // grid = 1024 block, block = 256 threads. Total= 262144 threads.
    backprojectKernel<<<grid, block>>>(d_volume, d_image,
                                       l, oL, rL,
                                       imageWidth, imageHeight);
    cudaDeviceSynchronize(); // cpu needs to wait for the gpu to finish the backprojection.
  }

  // copy all result back to the host memory at once, and return.
  cudaMemcpy(r->volumeData, d_volume,
             (size_t)l*l*l * sizeof(float),
             cudaMemcpyDeviceToHost); 
  return 1;
}
extern "C" int lolaCudaFinish(RabbitCtGlobalData *r)
{
  cudaFree(d_volume);
  cudaFree(d_image);
  d_volume = NULL;
  d_image  = NULL;
  return 1;
}
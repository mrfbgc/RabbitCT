/* Copyright (C) NHR@FAU, University Erlangen-Nuremberg.
 * All rights reserved. This file is part of RabbitCT.
 * Use of this source code is governed by a MIT style
 * license that can be found in the LICENSE file. */
#include <stdio.h>

#include "rabbitCt.h"

static RabbitCtGlobalData *SRcgd = NULL;
// this static pointer is used only in this file and it's a global memory address. It exists because pN and pHatN functions do not take parameters, however they need to know the image volume.

static inline double pN(const float *image, int i, int j)
{
  /*Reads a pixel from the projection image.
  Parameters:
  image: pointer to the projection image. It's a 2D image but stored in a 1D array.
  i: column index of the pixel to read.
  j: row index of the pixel to read.
  */
  if (i >= 0 && i < (int)SRcgd->imageWidth && j >= 0 && j < (int)SRcgd->imageHeight)
    return image[j * SRcgd->imageWidth + i];
    // e.g. i = 0 j = 0 width = 512 returns image[0*width+0] = image[0]
    // e.g. i = 1 j = 0 width = 512 returns image[0*width+1] = image[1]
    // e.g. i = 2 j = 0 width = 512 returns image[0*width+2] = image[2]
    // e.g. i = 0 j = 1 width = 512 returns image[1*width+0] = image[512]
    // e.g. i = 1 j = 1 width = 512 returns image[1*width+1] = image[513]
    // e.g. i = 2 j = 1 width = 512 returns image[1*width+2] = image[514]
    // e.g. i = 0 j = 2 width = 512 returns image[2*width+0] = image[1024]
    // e.g. i = 1 j = 2 width = 512 returns image[2*width+1] = image[1025]
    // e.g. i = 2 j = 2 width = 512 returns image[2*width+2] = image[1026]
  return 0.0; 
}

static inline double pHatN(const float *image, double x, double y)
{
  /* Returns the pixel value at the fractional (non integer coordinates). It uses bilinear interpolation to compute the value. The parameters are:
  image: pointer to the projection image. It's a 2D image but stored in a 1D array.
  x: column index of the pixel to read. It can be a fractional value.
  y: row index of the pixel to read. It can be a fractional value.
  */
  int i        = (int)x;
  int j        = (int)y;
  double alpha = x - (int)x;
  double beta  = y - (int)y;

  // Bilinear interpolation formula:
  return (1.0 - alpha) * (1.0 - beta) * pN(image, i, j) +
         alpha * (1.0 - beta) * pN(image, i + 1, j) +
         (1.0 - alpha) * beta * pN(image, i, j + 1) +
         alpha * beta * pN(image, i + 1, j + 1);
}

int lolaBunnyPrepare(RabbitCtGlobalData *rcgd)
{
  (void)rcgd;
  return 1;
}

int lolaBunnyFinish(RabbitCtGlobalData *rcgd)
{
  (void)rcgd;
  return 1;
}

int lolaBunnyBackprojection(RabbitCtGlobalData *r)
{
  unsigned int l = r->problemSize; // number of voxel ? 
  float oL       = r->O_Index; // origin of the volume
  float rL       = r->voxelSize; // size of the voxel
  float *fL      = r->volumeData; // pointer to the volume data

  SRcgd          = r; // update the pointer to enable the pN and pHatN functions to access the projection images and the volume data.

  for (int p = 0; p < (int)r->numberOfProjections; p++) {
    double *aN         = r->projectionBuffer[p].matrix;
    const float *image = r->projectionBuffer[p].image; // projectionBuffer??

    // projection: finding x,y,z (location in real world as mm) from the i,j,k (voxel coord.))
    for (unsigned int k = 0; k < l; k++) {
      double z = oL + (double)k * rL;
      for (unsigned int j = 0; j < l; j++) {
        double y = oL + (double)j * rL;
        for (unsigned int i = 0; i < l; i++) {
          double x  = oL + (double)i * rL;

          // where the formulas comes from? I guess it's a back projection formula (finding 2D coordinates in the projection image from the 3D coordinates in the volume).
          double wN = aN[2] * x + aN[5] * y + aN[8] * z + aN[11];
          double uN = (aN[0] * x + aN[3] * y + aN[6] * z + aN[9]) / wN;
          double vN = (aN[1] * x + aN[4] * y + aN[7] * z + aN[10]) / wN;

          fL[k * l * l + j * l + i] += (float)(1.0 / (wN * wN) * pHatN(image, uN, vN)); // voxel's location in the memory (e.g. 134m index for 512 volume)
        }
      }
    }
  }

  return 1;
}

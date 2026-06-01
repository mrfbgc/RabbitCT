# ISPC support: compile fastRabbit.ispc and include LolaISPC variant
ifeq ($(ENABLE_ISPC),true)
ISPC      ?= ispc
ISPCFLAGS  = --pic --opt=fast-math
ifeq ($(SIMD),SSE)
ISPCFLAGS += --target=sse4-i32x4
endif
ifeq ($(SIMD),AVX)
ISPCFLAGS += --target=avx2-i32x8
endif
ifeq ($(SIMD),AVX512)
ISPCFLAGS += --target=avx512skx-i32x16
endif
ifeq ($(SIMD),NEON)
ISPCFLAGS += --target=neon-i32x4
endif
DEFINES   += -DENABLE_ISPC
else
# Exclude LolaISPC.c when ISPC is disabled (missing symbols)
OBJ       := $(filter-out $(BUILD_DIR)/LolaISPC.o,$(OBJ))
endif

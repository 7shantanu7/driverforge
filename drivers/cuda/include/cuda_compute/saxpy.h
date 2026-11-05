#pragma once

#include <cstddef>

namespace cuda_compute {

enum class Status {
    kOk,
    kNoDevice,
    kCudaError,
};

// Number of CUDA devices visible to this process (0 on a GPU-less CI runner).
int DeviceCount();

// y = a * x + y on the GPU. Returns kNoDevice when no GPU is present, which
// is the expected result on a build-only CI runner.
Status Saxpy(float a, const float* x, float* y, std::size_t n);

}  // namespace cuda_compute

#include <cuda_runtime.h>

#include "cuda_compute/saxpy.h"

namespace cuda_compute {
namespace {

__global__ void SaxpyKernel(float a, const float* x, float* y, std::size_t n) {
    const std::size_t i = blockIdx.x * static_cast<std::size_t>(blockDim.x) + threadIdx.x;
    if (i < n) {
        y[i] = a * x[i] + y[i];
    }
}

}  // namespace

int DeviceCount() {
    int count = 0;
    if (cudaGetDeviceCount(&count) != cudaSuccess) {
        return 0;
    }
    return count;
}

Status Saxpy(float a, const float* x, float* y, std::size_t n) {
    if (DeviceCount() == 0) {
        return Status::kNoDevice;
    }
    const std::size_t bytes = n * sizeof(float);
    float* device_x = nullptr;
    float* device_y = nullptr;
    if (cudaMalloc(&device_x, bytes) != cudaSuccess ||
        cudaMalloc(&device_y, bytes) != cudaSuccess) {
        cudaFree(device_x);
        return Status::kCudaError;
    }
    cudaMemcpy(device_x, x, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(device_y, y, bytes, cudaMemcpyHostToDevice);

    constexpr unsigned kThreads = 256;
    const unsigned blocks = static_cast<unsigned>((n + kThreads - 1) / kThreads);
    SaxpyKernel<<<blocks, kThreads>>>(a, device_x, device_y, n);

    const bool ok = cudaGetLastError() == cudaSuccess &&
                    cudaMemcpy(y, device_y, bytes, cudaMemcpyDeviceToHost) == cudaSuccess;
    cudaFree(device_x);
    cudaFree(device_y);
    return ok ? Status::kOk : Status::kCudaError;
}

}  // namespace cuda_compute

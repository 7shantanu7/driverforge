#include <gtest/gtest.h>

#include <vector>

#include "cuda_compute/saxpy.h"

// Build-only CI runners have no GPU. The test still compiles and links
// against the CUDA runtime, then skips instead of failing. On a GPU runner
// (see infra/k8s/arc) it runs for real.
TEST(CudaSaxpyTest, ComputesOnGpuWhenAvailable) {
    if (cuda_compute::DeviceCount() == 0) {
        GTEST_SKIP() << "no CUDA device visible";
    }
    std::vector<float> x(1024, 1.0F);
    std::vector<float> y(1024, 2.0F);

    ASSERT_EQ(cuda_compute::Saxpy(3.0F, x.data(), y.data(), x.size()), cuda_compute::Status::kOk);
    for (float value : y) {
        EXPECT_FLOAT_EQ(value, 5.0F);
    }
}

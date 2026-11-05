#include <gtest/gtest.h>

#include "software_rasterizer/software_rasterizer.h"

TEST(SoftwareRasterizerTest, ReportsGraphicsSupportOnly) {
    gpu_core::SoftwareRasterizer device;

    EXPECT_TRUE(device.Supports(gpu_core::DeviceCapability::kGraphics));
    EXPECT_FALSE(device.Supports(gpu_core::DeviceCapability::kCompute));
}

TEST(SoftwareRasterizerTest, SubmitReturnsIncreasingFences) {
    gpu_core::SoftwareRasterizer device;

    EXPECT_EQ(device.Submit(4), 1u);
    EXPECT_EQ(device.Submit(4), 2u);
}

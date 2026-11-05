#include <gtest/gtest.h>

#include <string>

#include "gpu_core/version.h"

TEST(VersionTest, BuildInfoMatchesHeader) {
    const gpu_core::BuildInfo info = gpu_core::GetBuildInfo();
    EXPECT_STREQ(info.version, GPU_CORE_VERSION_STRING);
    EXPECT_NE(std::string(info.git_sha), "");
    EXPECT_NE(std::string(info.compiler), "");
}

TEST(VersionTest, VersionStringIsMajorMinorPatch) {
    const std::string expected = std::to_string(GPU_CORE_VERSION_MAJOR) + "." +
                                 std::to_string(GPU_CORE_VERSION_MINOR) + "." +
                                 std::to_string(GPU_CORE_VERSION_PATCH);
    EXPECT_EQ(expected, GPU_CORE_VERSION_STRING);
}

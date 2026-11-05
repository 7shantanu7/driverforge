#include <gtest/gtest.h>

#include <memory>
#include <string>

#include "gpu_core/plugin_loader.h"

using gpu_core::LoadedPlugin;
using gpu_core::PluginLoadError;

namespace {

// Returns the loader's error message, or "" if loading unexpectedly worked.
std::string LoadError(const std::string& path) {
    try {
        LoadedPlugin::Load(path);
    } catch (const PluginLoadError& error) {
        return error.what();
    }
    return "";
}

}  // namespace

TEST(PluginLoaderTest, MissingFileIsRejected) {
    EXPECT_NE(LoadError("/nonexistent/libnope.so").find("cannot load plugin"), std::string::npos);
}

TEST(PluginLoaderTest, FutureOnlyAbiIsRejected) {
    EXPECT_NE(LoadError(TEST_PLUGIN_FUTURE_ABI).find("cannot support plugin ABI"),
              std::string::npos);
}

TEST(PluginLoaderTest, MissingEntryPointIsRejected) {
    EXPECT_NE(LoadError(TEST_PLUGIN_MISSING_SYMBOL).find("does not export"), std::string::npos);
}

TEST(PluginLoaderTest, NullFunctionTableEntriesAreRejected) {
    EXPECT_NE(LoadError(TEST_PLUGIN_NULL_TABLE).find("null entries"), std::string::npos);
}

#if defined(NVK_DRIVER_PATH)
TEST(PluginLoaderTest, LoadsNvkDriverAndNegotiatesCurrentAbi) {
    LoadedPlugin plugin = LoadedPlugin::Load(NVK_DRIVER_PATH);

    EXPECT_EQ(plugin.Name(), "nvk_driver");
    EXPECT_EQ(plugin.AbiVersion(), GPU_CORE_PLUGIN_ABI_VERSION);
    EXPECT_FALSE(plugin.Version().empty());
}

TEST(PluginLoaderTest, DeviceOutlivesLoadedPlugin) {
    std::unique_ptr<gpu_core::Device> device;
    {
        LoadedPlugin plugin = LoadedPlugin::Load(NVK_DRIVER_PATH);
        device = plugin.CreateDevice();
    }
    // The plugin object is gone, but the device still holds the library.
    ASSERT_NE(device, nullptr);
    EXPECT_TRUE(device->Supports(gpu_core::DeviceCapability::kCompute));
    EXPECT_NE(device->Name().find("nvk"), std::string::npos);
    EXPECT_EQ(device->Submit(2), 1u);
    EXPECT_EQ(device->Submit(2), 2u);
}
#endif

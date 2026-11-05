#pragma once

#include <cstdint>
#include <memory>
#include <stdexcept>
#include <string>

#include "gpu_core/device.h"
#include "gpu_core/gpu_core_export.h"
#include "gpu_core/plugin_abi.h"

namespace gpu_core {

class GPU_CORE_EXPORT PluginLoadError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

// Loads one driver plugin with dlopen(), negotiates the ABI version and
// validates the function table before anything is called. Devices created
// from a plugin keep the library loaded, so it is safe to destroy the
// LoadedPlugin before its devices.
class GPU_CORE_EXPORT LoadedPlugin {
public:
    // Throws PluginLoadError with a precise reason on any failure.
    static LoadedPlugin Load(const std::string& path);

    std::unique_ptr<Device> CreateDevice() const;

    const std::string& Path() const { return path_; }
    std::string Name() const;
    std::string Version() const;
    uint32_t AbiVersion() const { return abi_version_; }

private:
    LoadedPlugin(std::string path, std::shared_ptr<void> library, const gpu_core_plugin_api* api,
                 uint32_t abi_version);

    std::string path_;
    std::shared_ptr<void> library_;
    const gpu_core_plugin_api* api_;
    uint32_t abi_version_;
};

}  // namespace gpu_core

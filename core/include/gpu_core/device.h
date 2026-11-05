#pragma once

#include <cstdint>
#include <string>

#include "gpu_core/gpu_core_export.h"

namespace gpu_core {

enum class DeviceCapability {
    kGraphics,
    kCompute,
};

// Abstract interface every driver backend (plugin, software fallback, CUDA)
// implements inside the host process, so the rest of the stack never depends
// on a concrete backend type. Plugins never implement this directly: they
// speak the C ABI in plugin_abi.h, and PluginLoader adapts that to Device.
class GPU_CORE_EXPORT Device {
public:
    Device() = default;
    Device(const Device&) = delete;
    Device& operator=(const Device&) = delete;
    Device(Device&&) = delete;
    Device& operator=(Device&&) = delete;
    virtual ~Device();

    virtual std::string Name() const = 0;
    virtual bool Supports(DeviceCapability capability) const = 0;

    // Submits a batch of recorded commands and returns a monotonically
    // increasing fence value, like a timeline semaphore.
    virtual uint64_t Submit(uint32_t command_count) = 0;
};

}  // namespace gpu_core

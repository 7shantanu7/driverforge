#pragma once

#include <atomic>
#include <cstdint>
#include <string>

#include "gpu_core/plugin_abi.h"

namespace nvk_driver {

// Private implementation of the mock NVK-inspired device. Nothing in this
// header is part of the plugin ABI: the host only ever sees the opaque
// gpu_core_device_handle and the C function table.
class NvkDevice {
public:
    NvkDevice();

    const std::string& Name() const { return name_; }
    static bool Supports(gpu_core_capability capability);

    // Simulates pushing commands to a hardware ring and returns the fence
    // value the "GPU" will signal when the batch completes.
    uint64_t Submit(uint32_t command_count);

private:
    std::string name_;
    std::atomic<uint64_t> fence_{0};
    std::atomic<uint64_t> commands_submitted_{0};
};

}  // namespace nvk_driver

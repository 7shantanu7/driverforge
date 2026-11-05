#include <new>

#include "gpu_core/plugin_abi.h"
#include "nvk_device.h"
#include "nvk_driver_version.h"

namespace nvk_driver {

NvkDevice::NvkDevice() : name_("nvk_driver (mock NVIDIA/Vulkan backend)") {}

bool NvkDevice::Supports(gpu_core_capability capability) {
    return capability == GPU_CORE_CAPABILITY_GRAPHICS || capability == GPU_CORE_CAPABILITY_COMPUTE;
}

uint64_t NvkDevice::Submit(uint32_t command_count) {
    commands_submitted_.fetch_add(command_count, std::memory_order_relaxed);
    return fence_.fetch_add(1, std::memory_order_acq_rel) + 1;
}

namespace {

NvkDevice* FromHandle(gpu_core_device_handle handle) {
    return reinterpret_cast<NvkDevice*>(handle);
}

gpu_core_device_handle CreateDevice() {
    // nothrow: a C++ exception must never unwind across the C ABI boundary.
    return reinterpret_cast<gpu_core_device_handle>(new (std::nothrow) NvkDevice());
}

void DestroyDevice(gpu_core_device_handle device) {
    // The plugin allocated it, so the plugin frees it. The host never calls
    // delete on plugin memory.
    delete FromHandle(device);
}

const char* DeviceName(gpu_core_device_handle device) { return FromHandle(device)->Name().c_str(); }

int DeviceSupports(gpu_core_device_handle /*device*/, gpu_core_capability capability) {
    return NvkDevice::Supports(capability) ? 1 : 0;
}

uint64_t DeviceSubmit(gpu_core_device_handle device, uint32_t command_count) {
    return FromHandle(device)->Submit(command_count);
}

constexpr gpu_core_plugin_api kApi = {
    sizeof(gpu_core_plugin_api),
    GPU_CORE_PLUGIN_ABI_VERSION,
    "nvk_driver",
    NVK_DRIVER_VERSION_STRING,
    &CreateDevice,
    &DestroyDevice,
    &DeviceName,
    &DeviceSupports,
    &DeviceSubmit,
};

}  // namespace
}  // namespace nvk_driver

// The only two symbols this library exports (enforced by nvk_driver.map and
// checked in CI by scripts/check_exported_symbols.sh).
extern "C" {

GPU_CORE_PLUGIN_EXPORT gpu_core_plugin_result
gpu_core_plugin_negotiate_abi_version(uint32_t* in_out_version) {
    if (in_out_version == nullptr) {
        return GPU_CORE_PLUGIN_ERROR_INVALID_ARGUMENT;
    }
    if (*in_out_version < GPU_CORE_PLUGIN_ABI_MIN_VERSION) {
        return GPU_CORE_PLUGIN_ERROR_INCOMPATIBLE_VERSION;
    }
    if (*in_out_version > GPU_CORE_PLUGIN_ABI_VERSION) {
        *in_out_version = GPU_CORE_PLUGIN_ABI_VERSION;
    }
    return GPU_CORE_PLUGIN_OK;
}

GPU_CORE_PLUGIN_EXPORT const gpu_core_plugin_api* gpu_core_plugin_get_api(void) {
    return &nvk_driver::kApi;
}

}  // extern "C"

/* A minimal driver plugin as an outside vendor would write it: only the
 * installed plugin_abi.h, no gpu_core, no access to this repository. */
#include <stdlib.h>

#include "gpu_core/plugin_abi.h"

struct gpu_core_device_s {
    uint64_t fence;
};

static gpu_core_device_handle create_device(void) {
    return (gpu_core_device_handle)calloc(1, sizeof(struct gpu_core_device_s));
}
static void destroy_device(gpu_core_device_handle device) { free(device); }
static const char* device_name(gpu_core_device_handle device) {
    (void)device;
    return "third-party mock device";
}
static int device_supports(gpu_core_device_handle device, gpu_core_capability capability) {
    (void)device;
    return capability == GPU_CORE_CAPABILITY_COMPUTE;
}
static uint64_t device_submit(gpu_core_device_handle device, uint32_t command_count) {
    (void)command_count;
    return ++device->fence;
}

static const gpu_core_plugin_api kApi = {sizeof(gpu_core_plugin_api),
                                         GPU_CORE_PLUGIN_ABI_VERSION,
                                         "third_party_plugin",
                                         "0.0.1",
                                         create_device,
                                         destroy_device,
                                         device_name,
                                         device_supports,
                                         device_submit};

GPU_CORE_PLUGIN_EXPORT gpu_core_plugin_result
gpu_core_plugin_negotiate_abi_version(uint32_t* in_out_version) {
    if (in_out_version == NULL || *in_out_version < GPU_CORE_PLUGIN_ABI_MIN_VERSION) {
        return GPU_CORE_PLUGIN_ERROR_INCOMPATIBLE_VERSION;
    }
    if (*in_out_version > GPU_CORE_PLUGIN_ABI_VERSION) {
        *in_out_version = GPU_CORE_PLUGIN_ABI_VERSION;
    }
    return GPU_CORE_PLUGIN_OK;
}

GPU_CORE_PLUGIN_EXPORT const gpu_core_plugin_api* gpu_core_plugin_get_api(void) { return &kApi; }

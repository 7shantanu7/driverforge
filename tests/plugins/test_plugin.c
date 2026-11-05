/*
 * One source, three deliberately broken plugins (selected by a compile
 * definition). The loader must reject each one with a clear error instead of
 * crashing or calling into an incompatible table.
 */
#include <stddef.h>

#include "gpu_core/plugin_abi.h"

#if defined(TEST_PLUGIN_FUTURE_ABI)
/* Built for a future ABI 2 that dropped support for ABI 1. */
GPU_CORE_PLUGIN_EXPORT gpu_core_plugin_result
gpu_core_plugin_negotiate_abi_version(uint32_t* in_out_version) {
    if (in_out_version == NULL || *in_out_version < 2u) {
        return GPU_CORE_PLUGIN_ERROR_INCOMPATIBLE_VERSION;
    }
    *in_out_version = 2u;
    return GPU_CORE_PLUGIN_OK;
}
GPU_CORE_PLUGIN_EXPORT const gpu_core_plugin_api* gpu_core_plugin_get_api(void) { return NULL; }

#elif defined(TEST_PLUGIN_MISSING_SYMBOL)
/* Exports the negotiation entry point but forgot gpu_core_plugin_get_api. */
GPU_CORE_PLUGIN_EXPORT gpu_core_plugin_result
gpu_core_plugin_negotiate_abi_version(uint32_t* in_out_version) {
    (void)in_out_version;
    return GPU_CORE_PLUGIN_OK;
}

#elif defined(TEST_PLUGIN_NULL_TABLE)
/* Negotiates fine but hands back a table with missing functions. */
static const gpu_core_plugin_api kBrokenApi = {sizeof(gpu_core_plugin_api),
                                               GPU_CORE_PLUGIN_ABI_VERSION,
                                               "broken",
                                               "0",
                                               NULL,
                                               NULL,
                                               NULL,
                                               NULL,
                                               NULL};
GPU_CORE_PLUGIN_EXPORT gpu_core_plugin_result
gpu_core_plugin_negotiate_abi_version(uint32_t* in_out_version) {
    (void)in_out_version;
    return GPU_CORE_PLUGIN_OK;
}
GPU_CORE_PLUGIN_EXPORT const gpu_core_plugin_api* gpu_core_plugin_get_api(void) {
    return &kBrokenApi;
}

#else
#error "select a TEST_PLUGIN_* variant"
#endif

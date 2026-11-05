/*
 * gpu_core driver plugin ABI.
 *
 * This is the ONLY contract between the host (gpu_core's PluginLoader) and a
 * driver plugin (.so). It is plain C on purpose: C++ classes, std::string and
 * new/delete must never cross a shared-library boundary, because the two
 * sides may be built by different compilers, standard libraries or
 * allocators. Real Vulkan ICDs talk to the loader the same way.
 *
 * Versioning follows the Vulkan loader/ICD interface negotiation model:
 *   1. The host calls gpu_core_plugin_negotiate_abi_version() with the
 *      highest ABI version it supports.
 *   2. The plugin lowers the value to the highest version it also supports
 *      and returns GPU_CORE_PLUGIN_OK, or returns an error if it cannot
 *      support any version at or below the host's.
 *   3. The host rejects the plugin if the agreed version is below its own
 *      minimum.
 *
 * Any change to this file that breaks existing plugins must bump
 * GPU_CORE_PLUGIN_ABI_VERSION and the plugin SOVERSION. CI enforces this with
 * libabigail (scripts/check_abi.sh).
 */
#ifndef GPU_CORE_PLUGIN_ABI_H
#define GPU_CORE_PLUGIN_ABI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GPU_CORE_PLUGIN_ABI_VERSION 1u
#define GPU_CORE_PLUGIN_ABI_MIN_VERSION 1u

#if defined(_WIN32)
#define GPU_CORE_PLUGIN_EXPORT __declspec(dllexport)
#else
#define GPU_CORE_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

#define GPU_CORE_PLUGIN_NEGOTIATE_SYMBOL "gpu_core_plugin_negotiate_abi_version"
#define GPU_CORE_PLUGIN_GET_API_SYMBOL "gpu_core_plugin_get_api"

typedef enum gpu_core_plugin_result {
    GPU_CORE_PLUGIN_OK = 0,
    GPU_CORE_PLUGIN_ERROR_INCOMPATIBLE_VERSION = 1,
    GPU_CORE_PLUGIN_ERROR_INVALID_ARGUMENT = 2
} gpu_core_plugin_result;

typedef enum gpu_core_capability {
    GPU_CORE_CAPABILITY_GRAPHICS = 0,
    GPU_CORE_CAPABILITY_COMPUTE = 1
} gpu_core_capability;

/* Opaque device handle. Only the plugin knows what it points to. */
typedef struct gpu_core_device_s* gpu_core_device_handle;

/*
 * Function table a plugin hands to the host. struct_size lets a newer host
 * detect an older, smaller table (new members are only ever appended).
 * Strings returned by the plugin stay owned by the plugin and stay valid for
 * as long as the plugin is loaded (plugin_name, plugin_version) or the
 * device exists (device_name).
 */
typedef struct gpu_core_plugin_api {
    uint32_t struct_size;
    uint32_t abi_version;
    const char* plugin_name;
    const char* plugin_version;

    gpu_core_device_handle (*create_device)(void);
    void (*destroy_device)(gpu_core_device_handle device);
    const char* (*device_name)(gpu_core_device_handle device);
    int (*device_supports)(gpu_core_device_handle device, gpu_core_capability capability);
    uint64_t (*device_submit)(gpu_core_device_handle device, uint32_t command_count);
} gpu_core_plugin_api;

typedef gpu_core_plugin_result (*gpu_core_plugin_negotiate_fn)(uint32_t* in_out_version);
typedef const gpu_core_plugin_api* (*gpu_core_plugin_get_api_fn)(void);

/* Entry points every plugin must export (declared here so plugins get the
 * exact signatures checked by the compiler). */
GPU_CORE_PLUGIN_EXPORT gpu_core_plugin_result
gpu_core_plugin_negotiate_abi_version(uint32_t* in_out_version);
GPU_CORE_PLUGIN_EXPORT const gpu_core_plugin_api* gpu_core_plugin_get_api(void);

#ifdef __cplusplus
}
#endif

#endif /* GPU_CORE_PLUGIN_ABI_H */

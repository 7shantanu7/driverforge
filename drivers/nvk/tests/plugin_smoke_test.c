/*
 * Loads the built nvk_driver plugin exactly the way a third-party host would:
 * plain C, dlopen() by path, no gpu_core library involved at all. This proves
 * the plugin contract is genuinely a C ABI, usable from any language that can
 * call C.
 */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

#include "gpu_core/plugin_abi.h"

int main(void) {
    void* handle = dlopen(NVK_DRIVER_PATH, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        fprintf(stderr, "dlopen failed: %s\n", dlerror());
        return 1;
    }

    gpu_core_plugin_negotiate_fn negotiate = NULL;
    gpu_core_plugin_get_api_fn get_api = NULL;
    /* POSIX-blessed way to convert dlsym's void* to a function pointer. */
    *(void**)(&negotiate) = dlsym(handle, GPU_CORE_PLUGIN_NEGOTIATE_SYMBOL);
    *(void**)(&get_api) = dlsym(handle, GPU_CORE_PLUGIN_GET_API_SYMBOL);
    if (negotiate == NULL || get_api == NULL) {
        fprintf(stderr, "plugin is missing a required entry point\n");
        dlclose(handle);
        return 1;
    }

    /* Ask for a far-future version: the plugin must lower it, not fail. */
    uint32_t version = 1000u;
    if (negotiate(&version) != GPU_CORE_PLUGIN_OK || version != GPU_CORE_PLUGIN_ABI_VERSION) {
        fprintf(stderr, "ABI negotiation failed (got version %u)\n", (unsigned)version);
        dlclose(handle);
        return 1;
    }

    const gpu_core_plugin_api* api = get_api();
    int ok = api != NULL && api->struct_size >= sizeof(gpu_core_plugin_api);
    if (ok) {
        gpu_core_device_handle device = api->create_device();
        ok = device != NULL && api->device_supports(device, GPU_CORE_CAPABILITY_COMPUTE) &&
             strstr(api->device_name(device), "nvk") != NULL &&
             api->device_submit(device, 3) == 1 && api->device_submit(device, 1) == 2;
        if (device != NULL) {
            api->destroy_device(device);
        }
    }

    if (!ok) {
        fprintf(stderr, "loaded plugin failed sanity checks\n");
    }
    dlclose(handle);
    return ok ? 0 : 1;
}

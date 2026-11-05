/* Compiles plugin_abi.h as strict C11 and checks a few layout invariants
 * that the ABI promises (append-only struct, fixed-width fields). */
#include <stddef.h>
#include <stdio.h>

#include "gpu_core/plugin_abi.h"

_Static_assert(offsetof(gpu_core_plugin_api, struct_size) == 0,
               "struct_size must stay the first member");
_Static_assert(offsetof(gpu_core_plugin_api, abi_version) == 4,
               "abi_version must stay the second member");
_Static_assert(sizeof(uint32_t) == 4, "uint32_t must be 32 bits");

int main(void) {
    if (GPU_CORE_PLUGIN_ABI_MIN_VERSION > GPU_CORE_PLUGIN_ABI_VERSION) {
        fprintf(stderr, "min ABI version is above current ABI version\n");
        return 1;
    }
    printf("plugin ABI %u, table size %zu bytes\n", (unsigned)GPU_CORE_PLUGIN_ABI_VERSION,
           sizeof(gpu_core_plugin_api));
    return 0;
}

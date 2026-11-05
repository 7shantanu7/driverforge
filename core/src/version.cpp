#include "gpu_core/version.h"

#include "gpu_core_build_info.h"

namespace gpu_core {

BuildInfo GetBuildInfo() {
    return BuildInfo{GPU_CORE_VERSION_STRING, GPU_CORE_BUILD_GIT_SHA, GPU_CORE_BUILD_COMPILER,
                     GPU_CORE_BUILD_TYPE};
}

}  // namespace gpu_core

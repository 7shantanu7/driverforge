#include "software_rasterizer/software_rasterizer.h"

namespace gpu_core {

std::string SoftwareRasterizer::Name() const { return "software_rasterizer (CPU fallback)"; }

bool SoftwareRasterizer::Supports(DeviceCapability capability) const {
    return capability == DeviceCapability::kGraphics;
}

uint64_t SoftwareRasterizer::Submit(uint32_t /*command_count*/) {
    // Work happens synchronously on the CPU, so the fence is already
    // signalled by the time we return it.
    return fence_.fetch_add(1, std::memory_order_acq_rel) + 1;
}

}  // namespace gpu_core

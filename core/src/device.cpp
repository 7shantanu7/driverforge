#include "gpu_core/device.h"

namespace gpu_core {

// Out-of-line so the vtable and typeinfo have exactly one home (gpu_core),
// instead of a weak copy in every library that includes device.h.
Device::~Device() = default;

}  // namespace gpu_core

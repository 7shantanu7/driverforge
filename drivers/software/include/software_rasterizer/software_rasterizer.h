#pragma once

#include <atomic>
#include <cstdint>
#include <string>

#include "gpu_core/device.h"

namespace gpu_core {

// CPU fallback backend: always available, used in headless/CI environments
// where no real (or mock) GPU driver is present. Linked statically into the
// host, which makes the static-vs-plugin contrast with nvk_driver concrete.
class SoftwareRasterizer final : public Device {
public:
    std::string Name() const override;
    bool Supports(DeviceCapability capability) const override;
    uint64_t Submit(uint32_t command_count) override;

private:
    std::atomic<uint64_t> fence_{0};
};

}  // namespace gpu_core

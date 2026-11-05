#include <iostream>
#include <memory>

#include "gpu_core/plugin_loader.h"
#include "gpu_core/version.h"
#include "software_rasterizer/software_rasterizer.h"

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cerr << "usage: consumer_app <plugin.so>\n";
        return 2;
    }
    std::cout << "built against gpu_core " << GPU_CORE_VERSION_STRING << ", running "
              << gpu_core::GetBuildInfo().version << "\n";

    gpu_core::SoftwareRasterizer fallback;
    if (!fallback.Supports(gpu_core::DeviceCapability::kGraphics)) {
        return 1;
    }

    try {
        gpu_core::LoadedPlugin plugin = gpu_core::LoadedPlugin::Load(argv[1]);
        std::unique_ptr<gpu_core::Device> device = plugin.CreateDevice();
        if (device->Submit(1) == 0) {
            std::cerr << "unexpected fence value\n";
            return 1;
        }
        std::cout << plugin.Name() << ": ok (" << device->Name() << ")\n";
    } catch (const gpu_core::PluginLoadError& error) {
        std::cerr << error.what() << "\n";
        return 1;
    }
    return 0;
}

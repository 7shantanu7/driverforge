// driverforge-info: the host side of the stack, as shipped in the runtime
// package. It discovers driver plugins, loads them through gpu_core's
// PluginLoader, and falls back to the built-in software rasterizer when no
// plugin loads. Package install tests run it to prove an installed package
// works end to end, not just that files landed on disk.
#include <unistd.h>

#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#include "gpu_core/plugin_loader.h"
#include "gpu_core/version.h"

#if defined(DRIVERFORGE_HAVE_SOFTWARE_RENDERER)
#include "software_rasterizer/software_rasterizer.h"
#endif

namespace {

std::vector<std::string> SplitPaths(const std::string& value) {
    std::vector<std::string> paths;
    std::stringstream stream(value);
    std::string item;
    while (std::getline(stream, item, ':')) {
        if (!item.empty()) {
            paths.push_back(item);
        }
    }
    return paths;
}

// Default plugin location relative to the executable, so a relocated
// install (e.g. an unpacked tarball) still finds its own plugins.
std::string DefaultPluginPath() {
    std::vector<char> buffer(4096);
    ssize_t length = readlink("/proc/self/exe", buffer.data(), buffer.size() - 1);
    if (length <= 0) {
        return {};
    }
    std::string exe(buffer.data(), static_cast<std::size_t>(length));
    std::string bin_dir = exe.substr(0, exe.find_last_of('/'));
    return bin_dir + "/" + DRIVERFORGE_RELATIVE_PLUGIN_PATH;
}

const char* YesNo(bool value) { return value ? "yes" : "no"; }

void PrintDevice(gpu_core::Device& device) {
    std::cout << "  device:   " << device.Name() << "\n"
              << "  graphics: " << YesNo(device.Supports(gpu_core::DeviceCapability::kGraphics))
              << "\n"
              << "  compute:  " << YesNo(device.Supports(gpu_core::DeviceCapability::kCompute))
              << "\n"
              << "  submit:   fence " << device.Submit(1) << "\n";
}

}  // namespace

int main(int argc, char** argv) {
    bool require_plugin = false;
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--version") == 0) {
            const gpu_core::BuildInfo info = gpu_core::GetBuildInfo();
            std::cout << "driverforge-info " << info.version << " (" << info.git_sha << ", "
                      << info.compiler << ", " << info.build_type << ")\n";
            return 0;
        }
        if (std::strcmp(argv[i], "--require-plugin") == 0) {
            require_plugin = true;
        } else {
            std::cerr << "usage: driverforge-info [--version] [--require-plugin]\n"
                         "  DRIVERFORGE_DRIVERS=a.so:b.so overrides plugin discovery\n";
            return 2;
        }
    }

    std::vector<std::string> candidates;
    // Single-threaded at this point, so getenv() is safe.
    const char* env = std::getenv("DRIVERFORGE_DRIVERS");  // NOLINT(concurrency-mt-unsafe)
    if (env != nullptr && *env != '\0') {
        candidates = SplitPaths(env);
    } else if (std::string fallback = DefaultPluginPath(); !fallback.empty()) {
        candidates.push_back(fallback);
    }

    int loaded = 0;
    for (const std::string& path : candidates) {
        try {
            gpu_core::LoadedPlugin plugin = gpu_core::LoadedPlugin::Load(path);
            std::cout << "plugin " << plugin.Name() << " " << plugin.Version() << " (ABI "
                      << plugin.AbiVersion() << ") from " << plugin.Path() << "\n";
            std::unique_ptr<gpu_core::Device> device = plugin.CreateDevice();
            PrintDevice(*device);
            ++loaded;
        } catch (const gpu_core::PluginLoadError& error) {
            std::cerr << "warning: " << error.what() << "\n";
        }
    }

    if (loaded == 0) {
        if (require_plugin) {
            std::cerr << "error: no driver plugin could be loaded\n";
            return 1;
        }
#if defined(DRIVERFORGE_HAVE_SOFTWARE_RENDERER)
        std::cout << "no plugin loaded, using built-in fallback\n";
        gpu_core::SoftwareRasterizer fallback;
        PrintDevice(fallback);
#else
        std::cerr << "error: no driver plugin loaded and no software fallback built\n";
        return 1;
#endif
    }
    return 0;
}

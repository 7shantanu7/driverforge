#include "gpu_core/plugin_loader.h"

#include <dlfcn.h>

#include <utility>

namespace gpu_core {
namespace {

// Adapts a plugin's C function table to the in-process C++ Device interface.
// Holds a reference to the library so the code it calls cannot be unloaded
// underneath it.
class PluginDevice final : public Device {
public:
    PluginDevice(std::shared_ptr<void> library, const gpu_core_plugin_api* api,
                 gpu_core_device_handle handle)
        : library_(std::move(library)), api_(api), handle_(handle) {}

    PluginDevice(const PluginDevice&) = delete;
    PluginDevice& operator=(const PluginDevice&) = delete;
    PluginDevice(PluginDevice&&) = delete;
    PluginDevice& operator=(PluginDevice&&) = delete;
    ~PluginDevice() override { api_->destroy_device(handle_); }

    std::string Name() const override {
        const char* name = api_->device_name(handle_);
        return name != nullptr ? name : "";
    }

    bool Supports(DeviceCapability capability) const override {
        const auto c_capability = capability == DeviceCapability::kGraphics
                                      ? GPU_CORE_CAPABILITY_GRAPHICS
                                      : GPU_CORE_CAPABILITY_COMPUTE;
        return api_->device_supports(handle_, c_capability) != 0;
    }

    uint64_t Submit(uint32_t command_count) override {
        return api_->device_submit(handle_, command_count);
    }

private:
    std::shared_ptr<void> library_;
    const gpu_core_plugin_api* api_;
    gpu_core_device_handle handle_;
};

std::string DlError() {
    // glibc and musl keep the dlerror() state per thread.
    const char* error = dlerror();  // NOLINT(concurrency-mt-unsafe)
    return error != nullptr ? error : "unknown dlopen error";
}

template <typename Fn>
Fn LookupSymbol(void* library, const char* name, const std::string& path) {
    // Clear any stale error before dlsym, as POSIX recommends.
    dlerror();  // NOLINT(concurrency-mt-unsafe)
    void* symbol = dlsym(library, name);
    if (symbol == nullptr) {
        throw PluginLoadError("plugin '" + path + "' does not export '" + name + "'");
    }
    // POSIX guarantees object and function pointers round-trip through void*.
    return reinterpret_cast<Fn>(symbol);
}

}  // namespace

LoadedPlugin::LoadedPlugin(std::string path, std::shared_ptr<void> library,
                           const gpu_core_plugin_api* api, uint32_t abi_version)
    : path_(std::move(path)), library_(std::move(library)), api_(api), abi_version_(abi_version) {}

LoadedPlugin LoadedPlugin::Load(const std::string& path) {
    // RTLD_LOCAL keeps one plugin's symbols from leaking into another's.
    void* raw = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
    if (raw == nullptr) {
        throw PluginLoadError("cannot load plugin '" + path + "': " + DlError());
    }
    std::shared_ptr<void> library(raw, [](void* handle) { dlclose(handle); });

    auto negotiate =
        LookupSymbol<gpu_core_plugin_negotiate_fn>(raw, GPU_CORE_PLUGIN_NEGOTIATE_SYMBOL, path);
    auto get_api =
        LookupSymbol<gpu_core_plugin_get_api_fn>(raw, GPU_CORE_PLUGIN_GET_API_SYMBOL, path);

    uint32_t version = GPU_CORE_PLUGIN_ABI_VERSION;
    if (negotiate(&version) != GPU_CORE_PLUGIN_OK) {
        throw PluginLoadError("plugin '" + path + "' cannot support plugin ABI version " +
                              std::to_string(GPU_CORE_PLUGIN_ABI_VERSION) + " or older");
    }
    if (version < GPU_CORE_PLUGIN_ABI_MIN_VERSION || version > GPU_CORE_PLUGIN_ABI_VERSION) {
        throw PluginLoadError("plugin '" + path + "' negotiated unsupported ABI version " +
                              std::to_string(version));
    }

    const gpu_core_plugin_api* api = get_api();
    if (api == nullptr || api->struct_size < sizeof(gpu_core_plugin_api) ||
        api->abi_version != version) {
        throw PluginLoadError("plugin '" + path + "' returned an invalid function table");
    }
    if (api->create_device == nullptr || api->destroy_device == nullptr ||
        api->device_name == nullptr || api->device_supports == nullptr ||
        api->device_submit == nullptr) {
        throw PluginLoadError("plugin '" + path + "' function table has null entries");
    }

    return LoadedPlugin(path, std::move(library), api, version);
}

std::unique_ptr<Device> LoadedPlugin::CreateDevice() const {
    gpu_core_device_handle handle = api_->create_device();
    if (handle == nullptr) {
        throw PluginLoadError("plugin '" + path_ + "' failed to create a device");
    }
    return std::make_unique<PluginDevice>(library_, api_, handle);
}

std::string LoadedPlugin::Name() const {
    return api_->plugin_name != nullptr ? api_->plugin_name : "";
}

std::string LoadedPlugin::Version() const {
    return api_->plugin_version != nullptr ? api_->plugin_version : "";
}

}  // namespace gpu_core

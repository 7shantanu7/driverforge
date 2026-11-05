# ADR 0001: The driver plugin interface is a versioned C ABI

**Status:** accepted (release 1.0.0)

## Context

In 0.1.0 the plugin exported a factory that returned a C++ `Device*`. The
host called virtual methods on it, received `std::string` values from it,
and finally called `delete` on it. This works only while the host and the
plugin use the same compiler, the same standard library ABI and the same
allocator. A driver plugin is usually built separately from the host and
updated on its own schedule, so none of that is guaranteed. The library
also exported 11 dynamic symbols (vtables, typeinfo, methods), all of which
became accidental ABI.

## Decision

- The only contract is `plugin_abi.h`, a plain C header: an opaque device
  handle, fixed-width integers, and a function table with `struct_size`
  first, so new members can be appended later.
- Version negotiation follows the Vulkan loader and driver model: the host
  offers its highest version, and the plugin answers with the highest
  version both sides support, or refuses.
- The plugin owns its memory: it creates and destroys devices. The host never
  frees plugin memory, and no C++ exception crosses the boundary.
- The plugin exports exactly two symbols, enforced by a linker version script
  and a test against an allow-list.
- `gpu_core::LoadedPlugin` validates everything (symbols, negotiated version,
  table size, null entries) before it calls any plugin function.

## Consequences

- Plugins can be written in C, C++ or any language with a C FFI, with any
  compiler. `tests/consumer` builds one from the installed SDK only.
- The C++ convenience API is still available inside the host (`Device`),
  through an adapter.
- This broke every 0.x plugin, which is why 1.0.0 bumped the plugin
  SOVERSION to 1.

#include "gpu_core/command_buffer.h"

#include <utility>

namespace gpu_core {

void CommandBuffer::Record(Command command) { commands_.push_back(std::move(command)); }

void CommandBuffer::Reset() { commands_.clear(); }

}  // namespace gpu_core

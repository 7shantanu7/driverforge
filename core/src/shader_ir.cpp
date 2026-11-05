#include "gpu_core/shader_ir.h"

#include <utility>

namespace gpu_core {

void ShaderIR::AddInstruction(ShaderInstruction instruction) {
    instructions_.push_back(std::move(instruction));
}

}  // namespace gpu_core

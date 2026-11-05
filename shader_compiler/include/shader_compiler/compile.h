#pragma once

#include <istream>
#include <ostream>

namespace shader_compiler {

// Deliberately fake "compilation": writes a magic header + version byte and
// copies the input bytes through unchanged. Just enough of an
// input -> output transformation for the build pipeline to exercise a real
// build-time codegen step, not an actual GLSL -> SPIR-V compiler.
//
// Returns false if the input could not be read or the output not written.
bool CompileMock(std::istream& input, std::ostream& output);

}  // namespace shader_compiler

#include "shader_compiler/compile.h"

namespace shader_compiler {

bool CompileMock(std::istream& input, std::ostream& output) {
    output << "MSPV" << '\x01';
    if (input.peek() != std::istream::traits_type::eof()) {
        output << input.rdbuf();
    }
    return static_cast<bool>(output);
}

}  // namespace shader_compiler

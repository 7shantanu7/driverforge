#include <cstring>
#include <fstream>
#include <iostream>

#include "shader_compiler/compile.h"

int main(int argc, char** argv) {
    if (argc == 2 && std::strcmp(argv[1], "--version") == 0) {
        std::cout << "shader_compiler (mock) " << SHADER_COMPILER_VERSION << "\n";
        return 0;
    }
    if (argc != 3) {
        std::cerr << "usage: shader_compiler <input.glsl> <output.spv>\n"
                     "       shader_compiler --version\n";
        return 2;
    }

    std::ifstream input(argv[1], std::ios::binary);
    if (!input) {
        std::cerr << "shader_compiler: cannot open input '" << argv[1] << "'\n";
        return 1;
    }
    std::ofstream output(argv[2], std::ios::binary);
    if (!output) {
        std::cerr << "shader_compiler: cannot open output '" << argv[2] << "'\n";
        return 1;
    }

    if (!shader_compiler::CompileMock(input, output)) {
        std::cerr << "shader_compiler: failed to write '" << argv[2] << "'\n";
        return 1;
    }
    return 0;
}

#include <gtest/gtest.h>

#include <sstream>
#include <string>

#include "shader_compiler/compile.h"

TEST(ShaderCompilerTest, PrependsMockHeaderAndCopiesInput) {
    std::istringstream input("hello");
    std::ostringstream output;

    ASSERT_TRUE(shader_compiler::CompileMock(input, output));

    const std::string result = output.str();
    EXPECT_EQ(result.substr(0, 4), "MSPV");
    EXPECT_EQ(result[4], '\x01');
    EXPECT_EQ(result.substr(5), "hello");
}

TEST(ShaderCompilerTest, EmptyInputStillProducesHeader) {
    std::istringstream input("");
    std::ostringstream output;

    ASSERT_TRUE(shader_compiler::CompileMock(input, output));
    EXPECT_EQ(output.str().size(), 5u);
}

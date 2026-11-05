// Placeholder shader source. Content is irrelevant, since CompileMock does
// not parse GLSL. A second shader proves the codegen helper scales past one
// hard-coded file.
void main() {
    vec2 uv = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
    gl_Position = vec4(uv * 2.0 - 1.0, 0.0, 1.0);
}

#ifdef GL_ES
precision mediump float;
#endif

uniform mat4 modelViewProjectionMatrix;
attribute vec4 position;
attribute vec2 texcoord0;
varying vec2 vTexCoord;

void main() {
    vTexCoord   = texcoord0;
    gl_Position = modelViewProjectionMatrix * position;
}

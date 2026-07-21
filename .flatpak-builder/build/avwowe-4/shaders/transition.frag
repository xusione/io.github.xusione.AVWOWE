#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2DRect texFrom;
uniform sampler2DRect texTo;
uniform float         progress;
uniform int           type;
uniform vec2          resolution;

varying vec2 vTexCoord;

#define PI 3.14159265358979

void main() {
    vec2 uv  = vTexCoord;
    vec2 uvn = uv / resolution;

    vec4 colFrom = texture2DRect(texFrom, uv);
    vec4 colTo   = texture2DRect(texTo,   uv);

    float mask = 0.0;

    if (type == 0) {
        mask = progress;
    } else if (type == 1) {
        mask = step(uvn.x, progress);
    } else if (type == 2) {
        mask = step(1.0 - uvn.x, progress);
    } else if (type == 3) {
        mask = step(uvn.y, progress);
    } else if (type == 4) {
        float dist = abs(uvn.x - 0.5) * 2.0;
        mask = step(dist, 1.0 - progress);
    } else if (type == 5) {
        float dist = length(uvn - vec2(0.5)) * 1.42;
        mask = step(dist, progress);
    } else if (type == 6) {
        float band = fract(uvn.y * 8.0);
        mask = step(band, progress);
    } else if (type == 7) {
        vec2  d     = uvn - vec2(0.5);
        float angle = atan(d.x, -d.y) / (2.0 * PI) + 0.5;
        mask = step(angle, progress);
    }

    gl_FragColor = mix(colFrom, colTo, mask);
}

#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uBaseColor;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    
    // Subtle noise for grain effect
    float noise = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
    
    // Dynamic shimmer based on time
    float shimmer = sin(uTime + uv.x * 10.0 + uv.y * 5.0) * 0.05;
    
    vec4 color = uBaseColor;
    color.rgb += shimmer;
    color.rgb += noise * 0.02; // Fine crystalline grain
    
    fragColor = color;
}

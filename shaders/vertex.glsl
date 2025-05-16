precision highp float;

out vec2 vUv; // to send to fragment shader

void main() {
  // Compute view direction in world space
  vec4 worldPos = modelViewMatrix * vec4(position, 1.0);
  // Output vertex position
  gl_Position = projectionMatrix * worldPos;
  vUv = uv;
}
precision mediump float;

// From vertex shader
in vec2 vUv;

// From CPU
uniform vec3 u_clearColor;

uniform float u_eps;
uniform float u_maxDis;
uniform int u_maxSteps;

uniform vec3 u_camPos;
uniform mat4 u_camToWorldMat;
uniform mat4 u_camInvProjMat;

uniform vec3 u_lightDir;
uniform vec3 u_lightColor;

uniform float u_diffIntensity;
uniform float u_specIntensity;
uniform float u_ambientIntensity;
uniform float u_shininess;

uniform float u_time;

float sinDisplace(vec3 position, float time) {
  float timeScale = 0.1;
  float frequency = 7.0;
  float amplitude = 0.05;

  float displacementX = sin(frequency * (position.x + timeScale * time)) * amplitude;
  float displacementY = sin(frequency * (position.y + timeScale * time)) * amplitude;
  float displacementZ = sin(frequency * (position.z + timeScale * time)) * amplitude;

  return displacementX + displacementY + displacementZ;
}

float scene(vec3 p) {
  // distance to sphere 1
  float sphere1Dis = distance(p, vec3(0.0, 0.0, 0.0)) - 1.0 + sinDisplace(p, u_time); // Centered and static

  return sphere1Dis;
}

float rayMarch(vec3 ro, vec3 rd) {
  float d = 0.0; // total distance travelled
  float cd; // current scene distance
  vec3 p; // current position of ray

  for(int i = 0; i < u_maxSteps; ++i) { // main loop
    p = ro + d * rd; // calculate new position
    cd = scene(p); // get scene distance

    // if we have hit anything or our distance is too big, break loop
    if(cd < u_eps || d >= u_maxDis)
      break;

    // otherwise, add new scene distance to total distance
    d += cd;
  }

  return d; // finally, return scene distance
}

vec3 sceneCol(vec3 p) {
  return vec3(1.0, 0.5, 0.0);
}

vec3 normal(vec3 p) { // from https://iquilezles.org/articles/normalsSDF/
  vec3 n = vec3(0.0, 0.0, 0.0);
  vec3 e;
  for(int i = 0; i < 4; i++) {
    e = 0.5773 * (2.0 * vec3((((i + 3) >> 1) & 1), ((i >> 1) & 1), (i & 1)) - 1.0);
    n += e * scene(p + e * u_eps);
  }
  return normalize(n);
}

vec4 gammaCorrect(vec4 color) {
  return pow(color, vec4(1.0 / 2.2));
}

void main() {
  // Get UV from vertex shader
  vec2 uv = vUv.xy;

  // Get ray origin and direction from camera uniforms
  vec3 ro = u_camPos;
  vec3 rd = (u_camInvProjMat * vec4(uv * 2.0 - 1.0, 0.0, 1.0)).xyz;
  rd = (u_camToWorldMat * vec4(rd, 0.0)).xyz;
  rd = normalize(rd);

  // Ray marching and find total distance travelled
  float disTravelled = rayMarch(ro, rd); // use normalized ray

  // Find the hit position
  vec3 hp = ro + disTravelled * rd;

  // Get normal of hit point
  vec3 n = normal(hp);

  if(disTravelled >= u_maxDis) { // if ray doesn't hit anything
    // Sky gradient
    float skyFactor = smoothstep(0.0, 0.5, rd.y); // Use the y-component of the ray direction
    vec3 skyColor = mix(vec3(0.5, 0.7, 1.0), vec3(0.1, 0.3, 0.7), skyFactor); // Light blue to darker blue
    gl_FragColor = gammaCorrect(vec4(skyColor, 1.0));
  } else { // if ray hits something
    // Calculate Diffuse model
    float dotNL = dot(n, u_lightDir);
    float diff = max(dotNL, 0.0) * u_diffIntensity;
    float spec = pow(diff, u_shininess) * u_specIntensity;
    float ambient = u_ambientIntensity;

    vec3 color = u_lightColor * (sceneCol(hp) * (spec + ambient + diff));
    gl_FragColor = gammaCorrect(vec4(color, 1.0)); // color output
  }
}
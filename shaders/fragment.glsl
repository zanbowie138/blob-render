precision highp float;

// --- Inputs ---
in vec2 vUv;

// --- Camera uniforms ---
uniform vec3 u_camPos;
uniform mat4 u_camToWorldMat;
uniform mat4 u_camInvProjMat;

// --- Ray marching parameters ---
uniform float u_eps;
uniform float u_maxDis;
uniform int u_maxSteps;

// --- Lighting ---
uniform vec3 u_lightDir;
uniform vec3 u_lightColor;

// --- Material parameters ---
uniform float u_roughness;
uniform float u_metalness;
uniform float u_envMapIntensity;
uniform float u_clearcoat;
uniform float u_clearcoatRoughness;
uniform float u_transmission;

// --- Noise parameters ---
uniform float u_noiseFreqX;
uniform float u_noiseFreqY;
uniform float u_noiseAmpX;
uniform float u_noiseAmpY;
uniform float u_noiseTimeMult;

// --- Sphere parameters ---
uniform float u_sphereSpeed;
uniform float u_sphereRadius;
uniform float u_sphereDistance;
uniform float u_smoothingFactor;

// --- Environment ---
uniform sampler2D u_skybox;
uniform float u_time;

// --- SDF Functions ---
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float bandedNoise(vec3 p) {
    vec3 np = normalize(p);
    float phase = u_time * u_noiseTimeMult;
    return sin(np.x * u_noiseFreqX + phase) * u_noiseAmpX
         * sin(np.y * u_noiseFreqY + phase) * u_noiseAmpY;
}

float sphereSDF(vec3 p, vec3 center, float radius) {
    vec3 localP = p - center;
    return length(localP) - radius;
}

float sceneSDF(vec3 p) {
    // Base sphere
    float baseSphere = length(p) - 1.0 + bandedNoise(p);
    
    // Additional spheres
    float t = u_time * u_sphereSpeed;
    float sphere1 = sphereSDF(p, vec3(sin(t) * u_sphereDistance, cos(t) * u_sphereDistance, 0.0), u_sphereRadius) + bandedNoise(p);
    float sphere2 = sphereSDF(p, vec3(cos(t * 0.7) * u_sphereDistance, 0.0, sin(t * 0.7) * u_sphereDistance), u_sphereRadius) + bandedNoise(p);
    float sphere3 = sphereSDF(p, vec3(0.0, sin(t * 0.3) * u_sphereDistance, cos(t * 0.3) * u_sphereDistance), u_sphereRadius) + bandedNoise(p);
    
    // Smooth interpolation between spheres
    float result = smin(baseSphere, sphere1, u_smoothingFactor);
    result = smin(result, sphere2, u_smoothingFactor);
    result = smin(result, sphere3, u_smoothingFactor);
    
    return result;
}

// --- Ray Marching ---
bool rayIntersectsSphere(vec3 ro, vec3 rd, float radius, out float t0, out float t1) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - radius * radius;
    float h = b * b - c;
    if (h < 0.0) return false;
    h = sqrt(h);
    t0 = -b - h;
    t1 = -b + h;
    return true;
}

float rayMarch(vec3 ro, vec3 rd) {
    float maxDisp = abs(u_noiseAmpX) * abs(u_noiseAmpY);
    float radius = 1.0 + maxDisp;
    float t0, t1;
    
    // if (!rayIntersectsSphere(ro, rd, radius, t0, t1)) {
    //     return u_maxDis;
    // }
    
    float d = max(t0, 0.0);
    for(int i = 0; i < u_maxSteps; ++i) {
        vec3 p = ro + d * rd;
        float cd = sceneSDF(p);
        if(cd < u_eps || d >= u_maxDis) break;
        d += cd;
    }
    return d;
}

// --- Environment Functions ---
vec3 customSkybox(vec3 dir) {
    vec2 uv = vec2(
        atan(dir.z, dir.x) / (2.0 * 3.14159265) + 0.5,
        asin(dir.y) / 3.14159265 + 0.5
    );
    return texture(u_skybox, uv).rgb;
}

vec3 envMap(vec3 R) {
    return customSkybox(R) * u_envMapIntensity;
}

// --- Surface Functions ---
vec3 sceneCol(vec3 p) {
    vec3 np = normalize(p);
    float t = (np.y + 1.0) * 0.5;
    vec3 color1 = vec3(1.0, 0.3, 0.6);
    vec3 color2 = vec3(1.0, 0.7, 0.2);
    return mix(color1, color2, t);
}

vec3 normal(vec3 p) {
    vec3 n = vec3(0.0);
    for(int i = 0; i < 4; i++) {
        vec3 e = 0.5773 * (2.0 * vec3((((i + 3) >> 1) & 1), ((i >> 1) & 1), (i & 1)) - 1.0);
        n += e * sceneSDF(p + e * u_eps);
    }
    return normalize(n);
}


// --- PBR Functions ---
vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float distributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    float denom = NdotH2 * (a2 - 1.0) + 1.0;
    return a2 / (3.14159265 * denom * denom);
}

float geometrySchlickGGX(float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

float geometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    return geometrySchlickGGX(NdotV, roughness) * geometrySchlickGGX(NdotL, roughness);
}

// --- Reflection Functions ---
vec3 getReflection(vec3 ro, vec3 rd) {
    vec3 reflection = vec3(0.0);
    vec3 rayOrigin = ro;
    vec3 rayDir = rd;
    float reflectionStrength = 1.0;
    
    // Fixed number of iterations instead of variable
    for(int bounce = 0; bounce < 2; bounce++) {
        float disTravelled = rayMarch(rayOrigin, rayDir);
        if(disTravelled >= u_maxDis) {
            // Add environment map contribution
            reflection += reflectionStrength * envMap(rayDir);
            break;
        }
        
        vec3 hitPoint = rayOrigin + disTravelled * rayDir;
        vec3 normal = normal(hitPoint);
        
        // Get material properties at hit point
        vec3 albedo = sceneCol(hitPoint);
        float metalness = u_metalness;
        float roughness = u_roughness;
        
        // Calculate reflection
        vec3 reflectedDir = reflect(rayDir, normal);
        
        // Add direct lighting contribution
        vec3 V = normalize(rayOrigin - hitPoint);
        vec3 L = normalize(u_lightDir);
        vec3 H = normalize(V + L);
        float NdotL = max(dot(normal, L), 0.0);
        
        // PBR calculations
        vec3 F0 = mix(vec3(0.04), albedo, metalness);
        float D = distributionGGX(normal, H, roughness);
        float G = geometrySmith(normal, V, L, roughness);
        vec3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);
        vec3 specular = D * G * F / (4.0 * max(dot(normal, V), 0.0) * NdotL + 0.001);
        
        // Add contribution to reflection
        reflection += reflectionStrength * (specular * NdotL * u_lightColor);
        
        // Update for next bounce
        reflectionStrength *= 0.5; // Reduce reflection strength each bounce
        rayOrigin = hitPoint + normal * u_eps * 2.0; // Increased offset to prevent self-intersection
        rayDir = reflectedDir;
    }
    
    return reflection;
}








// --- Utility Functions ---
vec4 gammaCorrect(vec4 color) {
    return pow(color, vec4(1.0 / 2.2));
}

// --- Main ---
void main() {
    // Setup ray
    vec2 uv = vUv.xy;
    vec3 ro = u_camPos;
    vec3 rd = (u_camInvProjMat * vec4(uv * 2.0 - 1.0, 0.0, 1.0)).xyz;
    rd = (u_camToWorldMat * vec4(rd, 0.0)).xyz;
    rd = normalize(rd);

    // Ray march
    float disTravelled = rayMarch(ro, rd);
    vec3 hp = ro + disTravelled * rd;

    if(disTravelled >= u_maxDis) {
        float skyFactor = smoothstep(0.0, 0.5, rd.y);
        vec3 skyColor = mix(vec3(0.5, 0.7, 1.0), vec3(0.1, 0.3, 0.7), skyFactor);
        gl_FragColor = gammaCorrect(vec4(skyColor, 1.0));
    } else {
        // Surface properties
        vec3 N = normal(hp);
        vec3 V = normalize(u_camPos - hp);
        vec3 L = normalize(u_lightDir);
        vec3 H = normalize(V + L);
        
        // Material properties
        float roughness = clamp(u_roughness, 0.04, 1.0);
        float metalness = clamp(u_metalness, 0.0, 1.0);
        float clearcoat = clamp(u_clearcoat, 0.0, 1.0);
        float clearcoatRoughness = clamp(u_clearcoatRoughness, 0.04, 1.0);
        float transmission = clamp(u_transmission, 0.0, 1.0);
        
        // PBR calculations
        vec3 albedo = sceneCol(hp);
        vec3 F0 = mix(vec3(0.04), albedo, metalness);
        float NdotL = max(dot(N, L), 0.0);
        
        // Diffuse
        vec3 diffuse = (1.0 - metalness) * albedo / 3.14159265;
        
        // Specular
        float D = distributionGGX(N, H, roughness);
        float G = geometrySmith(N, V, L, roughness);
        vec3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);
        vec3 specular = D * G * F / (4.0 * max(dot(N, V), 0.0) * NdotL + 0.001);
        
        // Clearcoat
        float Dcc = distributionGGX(N, H, clearcoatRoughness);
        float Gcc = geometrySmith(N, V, L, clearcoatRoughness);
        float Fcc = fresnelSchlick(max(dot(H, V), 0.0), vec3(0.04)).r;
        float clearcoatSpec = clearcoat * Dcc * Gcc * Fcc / (4.0 * max(dot(N, V), 0.0) * NdotL + 0.001);
        
        // Reflections
        vec3 R = reflect(-V, N);
        vec3 reflection = getReflection(hp + N * u_eps * 2.0, R); // Removed bounce parameter
        vec3 env = envMap(R);
        vec3 transmissionCol = transmission * env;
        
        // Final color with adjusted reflection contribution
        vec3 color = (diffuse + specular + clearcoatSpec) * NdotL * u_lightColor 
                   + reflection * (1.0 - roughness) // More reflection for less rough surfaces
                   + env * 0.1 // Reduced environment contribution
                   + transmissionCol;
                   
        gl_FragColor = gammaCorrect(vec4(color, 1.0));
    }
}
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import vertCode from "./shaders/vertex.glsl?raw";
import fragCode from "./shaders/fragment.glsl?raw";
import Stats from "stats.js";
import * as dat from 'dat.gui';
import { RGBELoader } from 'three/examples/jsm/loaders/RGBELoader.js';

// Create a scene
const scene = new THREE.Scene();

// Create a camera
const camera = new THREE.PerspectiveCamera(
  75,
  window.innerWidth / window.innerHeight,
  0.1,
  1000
);
camera.position.z = 5;

// Create a renderer
const renderer = new THREE.WebGLRenderer();
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);

var stats = new Stats();
stats.showPanel(0); // 0: fps, 1: ms, 2: memory
document.body.appendChild(stats.dom);

// Set background color
const backgroundColor = new THREE.Color(0x3399ee);
renderer.setClearColor(backgroundColor, 1);

// Add orbit controls
const controls = new OrbitControls(camera, renderer.domElement);
controls.maxDistance = 10;
controls.minDistance = 2;
controls.enableDamping = true;

// Add directional light
const light = new THREE.DirectionalLight(0xffffff, 1);
light.position.set(1, 1, 1);
scene.add(light);

// Create a ray marching plane
const geometry = new THREE.PlaneGeometry();
const material = new THREE.ShaderMaterial();
const rayMarchPlane = new THREE.Mesh(geometry, material);

// Get the wdith and height of the near plane
const nearPlaneWidth =
  camera.near *
  Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) *
  camera.aspect *
  2;
const nearPlaneHeight = nearPlaneWidth / camera.aspect;

// Scale the ray marching plane
rayMarchPlane.scale.set(nearPlaneWidth, nearPlaneHeight, 1);

// Add uniforms
const uniforms = {
  u_eps: { value: 0.001 },
  u_maxDis: { value: 1000 },
  u_maxSteps: { value: 100 },

  u_camPos: { value: camera.position },
  u_camToWorldMat: { value: camera.matrixWorld },
  u_camInvProjMat: { value: camera.projectionMatrixInverse },

  u_lightDir: { value: light.position },
  u_lightColor: { value: light.color },

  u_diffIntensity: { value: 0.5 },
  u_specIntensity: { value: 3 },
  u_ambientIntensity: { value: 0.15 },
  u_shininess: { value: 16 },

  u_time: { value: 0 },

  // New noise parameters
  u_noiseFreqX: { value: 6.0 },
  u_noiseFreqY: { value: 6.0 },
  u_noiseAmpX: { value: 0.25 },
  u_noiseAmpY: { value: 0.25 },
  u_noiseTimeMult: { value: 1.0 },

  u_roughness: { value: 0.05 },
  u_metalness: { value: 0.0 },
  u_envMapIntensity: { value: 0.1 },
  u_clearcoat: { value: 1.0 },
  u_clearcoatRoughness: { value: 0.05 },
  u_transmission: { value: 0.0 },
  u_skybox: { value: null },
  u_sphereSpeed: { value: 0.5 },
  u_sphereRadius: { value: 0.5 },
  u_sphereDistance: { value: 2.0 },
  u_smoothingFactor: { value: 0.5 }
};

// Remove CubeTextureLoader code, use RGBELoader for HDR
const rgbeLoader = new RGBELoader();
rgbeLoader.setDataType(THREE.FloatType);
rgbeLoader.load('./blob-render/sunrise.hdr', function (texture) {
  uniforms.u_skybox.value = texture;
  texture.needsUpdate = true;
});

material.uniforms = uniforms;

material.vertexShader = vertCode;
material.fragmentShader = fragCode;

// Add plane to scene
scene.add(rayMarchPlane);

// Needed inside update function
let cameraForwardPos = new THREE.Vector3(0, 0, -1);

let time = Date.now();

// Create GUI
const gui = new dat.GUI();
const params = {
  noiseScale: 1.0,
  noiseTimeScale: 0.2,
  noiseAmplitude: 0.1,
  diffuseIntensity: 0.5,
  specularIntensity: 3.0,
  ambientIntensity: 0.15,
  shininess: 16.0,
  backgroundColor: '#3399ee',
  roughness: 0.0,
  metalness: 0.0,
  clearcoat: 0.0,
  clearcoatRoughness: 0.0,
  transmission: 0.0,
  envMapIntensity: 0.1,
  sphereSpeed: 0.5,
  sphereRadius: 0.5,
  sphereDistance: 2.0,
  smoothingFactor: 0.5
};

// Noise controls
const noiseFolder = gui.addFolder('Noise');
noiseFolder.add(uniforms.u_noiseFreqX, 'value', 1.0, 20.0).name('Freq X');
noiseFolder.add(uniforms.u_noiseFreqY, 'value', 1.0, 20.0).name('Freq Y');
noiseFolder.add(uniforms.u_noiseAmpX, 'value', 0.0, 1.0).name('Amp X');
noiseFolder.add(uniforms.u_noiseAmpY, 'value', 0.0, 1.0).name('Amp Y');
noiseFolder.add(uniforms.u_noiseTimeMult, 'value', 0.0, 5.0).name('Time Mult');

// Lighting controls
const lightingFolder = gui.addFolder('Lighting');
lightingFolder.add(params, 'diffuseIntensity', 0.0, 1.0).onChange((value) => {
  uniforms.u_diffIntensity.value = value;
});
lightingFolder.add(params, 'specularIntensity', 0.0, 10.0).onChange((value) => {
  uniforms.u_specIntensity.value = value;
});
lightingFolder.add(params, 'ambientIntensity', 0.0, 1.0).onChange((value) => {
  uniforms.u_ambientIntensity.value = value;
});
lightingFolder.add(params, 'shininess', 1.0, 100.0).onChange((value) => {
  uniforms.u_shininess.value = value;
});

// Material controls
const materialFolder = gui.addFolder('Material');
materialFolder.add(params, 'roughness', 0.0, 1.0).onChange((value) => {
  uniforms.u_roughness.value = value;
});
materialFolder.add(params, 'metalness', 0.0, 1.0).onChange((value) => {
  uniforms.u_metalness.value = value;
});
materialFolder.add(params, 'envMapIntensity', 0.0, 2.0).onChange((value) => {
  uniforms.u_envMapIntensity.value = value;
});
materialFolder.add(params, 'clearcoat', 0.0, 1.0).onChange((value) => {
  uniforms.u_clearcoat.value = value;
});
materialFolder.add(params, 'clearcoatRoughness', 0.0, 1.0).onChange((value) => {
  uniforms.u_clearcoatRoughness.value = value;
});
materialFolder.add(params, 'transmission', 0.0, 1.0).onChange((value) => {
  uniforms.u_transmission.value = value;
});

// Add sphere controls
const sphereFolder = gui.addFolder('Spheres');
sphereFolder.add(params, 'sphereSpeed', 0.1, 2.0).onChange((value) => {
  uniforms.u_sphereSpeed = { value: value };
});
sphereFolder.add(params, 'sphereRadius', 0.1, 1.0).onChange((value) => {
  uniforms.u_sphereRadius = { value: value };
});
sphereFolder.add(params, 'sphereDistance', 1.0, 4.0).onChange((value) => {
  uniforms.u_sphereDistance = { value: value };
});
sphereFolder.add(params, 'smoothingFactor', 0.1, 1.0).onChange((value) => {
  uniforms.u_smoothingFactor = { value: value };
});

// Add new uniforms
uniforms.u_sphereSpeed = { value: params.sphereSpeed };
uniforms.u_sphereRadius = { value: params.sphereRadius };
uniforms.u_sphereDistance = { value: params.sphereDistance };
uniforms.u_smoothingFactor = { value: params.smoothingFactor };

// Render the scene
const animate = () => {
  stats.begin(); // Start measuring performance

  // Update screen plane position and rotation
  cameraForwardPos = camera.position
    .clone()
    .add(
      camera
        .getWorldDirection(new THREE.Vector3(0, 0, 0))
        .multiplyScalar(camera.near)
    );
  rayMarchPlane.position.copy(cameraForwardPos);
  rayMarchPlane.rotation.copy(camera.rotation);

  renderer.render(scene, camera);

  uniforms.u_time.value = (Date.now() - time) / 1000;

  controls.update();

  stats.end(); // End measuring performance

  requestAnimationFrame(animate);
};
animate();

// Handle window resize
window.addEventListener("resize", () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();

  const nearPlaneWidth =
    camera.near *
    Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) *
    camera.aspect *
    2;
  const nearPlaneHeight = nearPlaneWidth / camera.aspect;
  rayMarchPlane.scale.set(nearPlaneWidth, nearPlaneHeight, 1);

  if (renderer) renderer.setSize(window.innerWidth, window.innerHeight);
});

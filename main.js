import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import vertCode from "./public/shaders/vertex.glsl?raw";
import fragCode from "./public/shaders/fragment.glsl?raw";
import Stats from "stats.js";

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

  u_clearColor: { value: backgroundColor },

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
};

material.uniforms = uniforms;

material.vertexShader = vertCode;
material.fragmentShader = fragCode;

// Add plane to scene
scene.add(rayMarchPlane);

// Needed inside update function
let cameraForwardPos = new THREE.Vector3(0, 0, -1);

let time = Date.now();

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

import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { STLLoader } from "three/addons/loaders/STLLoader.js";

const canvas = document.getElementById("c");
const statusEl = document.getElementById("status");
const titleEl = document.getElementById("viewer-title");

function setStatus(msg) {
  if (statusEl) statusEl.textContent = msg;
}

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x0d1117);

const camera = new THREE.PerspectiveCamera(50, 1, 0.01, 500);
camera.position.set(1.4, 1.0, 1.8);

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));

const hemi = new THREE.HemisphereLight(0x9fb8ff, 0x1a1a22, 0.85);
scene.add(hemi);
const dir = new THREE.DirectionalLight(0xffffff, 1.1);
dir.position.set(2, 4, 3);
scene.add(dir);

const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true;
controls.dampingFactor = 0.06;
controls.target.set(0, 0.35, 0);

const group = new THREE.Group();
scene.add(group);

const loader = new STLLoader();
const meshes = [];

let explodeT = 0;
let explodeTarget = 0;
const EXPLODE_SPEED = 2.2;

function resize() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  const ui = document.querySelector(".bh-toolbar");
  const barH = ui ? ui.offsetHeight : 56;
  const avail = Math.max(120, h - barH);
  camera.aspect = w / avail;
  camera.updateProjectionMatrix();
  renderer.setSize(w, avail, false);
}
window.addEventListener("resize", resize);

function updateMeshPositions() {
  for (const { mesh, explode } of meshes) {
    mesh.position.set(
      explode[0] * explodeT,
      explode[1] * explodeT,
      explode[2] * explodeT
    );
  }
}

function tick() {
  requestAnimationFrame(tick);
  const d = explodeTarget - explodeT;
  if (Math.abs(d) > 0.001) {
    const step = Math.sign(d) * Math.min(Math.abs(d), (1 / 60) * EXPLODE_SPEED);
    explodeT += step;
    updateMeshPositions();
  } else {
    explodeT = explodeTarget;
    updateMeshPositions();
  }
  controls.update();
  renderer.render(scene, camera);
}

async function main() {
  setStatus("Loading…");
  let cfg;
  try {
    const res = await fetch(new URL("manifest.json", import.meta.url), {
      cache: "no-store",
    });
    cfg = await res.json();
  } catch (e) {
    setStatus("Could not load manifest.json");
    console.error(e);
    return;
  }

  if (titleEl && cfg.title) titleEl.textContent = cfg.title;
  const baseUrl = new URL(".", import.meta.url).href;

  const material = new THREE.MeshStandardMaterial({
    color: 0xc9a66b,
    metalness: 0.12,
    roughness: 0.55,
    flatShading: true,
  });

  for (const part of cfg.parts || []) {
    const url = new URL(part.url, baseUrl).href;
    try {
      const geom = await new Promise((resolve, reject) => {
        loader.load(url, resolve, undefined, reject);
      });
      geom.computeVertexNormals();
      const mesh = new THREE.Mesh(geom, material.clone());
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      mesh.userData.partId = part.id;
      group.add(mesh);
      meshes.push({
        mesh,
        explode: part.explode || [0, 0, 0],
        label: part.label || part.id,
      });
    } catch (e) {
      console.error("STL load failed", part.url, e);
      setStatus("Failed: " + (part.label || part.id));
      return;
    }
  }

  const box = new THREE.Box3().setFromObject(group);
  const center = box.getCenter(new THREE.Vector3());
  const size = box.getSize(new THREE.Vector3());
  group.position.sub(center);
  controls.target.set(0, 0, 0);

  const maxDim = Math.max(size.x, size.y, size.z, 0.01);
  const dist = maxDim * 2.2;
  camera.position.set(dist * 0.75, dist * 0.45, dist * 0.9);

  updateMeshPositions();
  setStatus(meshes.length + " part" + (meshes.length === 1 ? "" : "s"));
  resize();
  tick();
}

document.getElementById("btn-assemble")?.addEventListener("click", () => {
  explodeTarget = 0;
});
document.getElementById("btn-explode")?.addEventListener("click", () => {
  explodeTarget = 1;
});

main().catch((e) => {
  console.error(e);
  setStatus("Error — see console");
});

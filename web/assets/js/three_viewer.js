class ThreeViewer {
  constructor(containerId) {
    this.container = document.getElementById(containerId);
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 1000);
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    this.controls = null;
    this.model = null;
    this.meshes = new Map();
    this.originalMaterials = new Map();
    
    this.init();
    this.setupLights();
    this.setupControls();
    this.animate();
  }

  init() {
    this.renderer.setSize(this.container.clientWidth, this.container.clientHeight);
    this.renderer.setPixelRatio(window.devicePixelRatio);
    this.container.appendChild(this.renderer.domElement);

    // Set initial camera position
    this.camera.position.set(0, 1, 3);
    this.camera.lookAt(0, 0, 0);

    // Handle window resize
    window.addEventListener('resize', () => this.onWindowResize(), false);
  }

  setupLights() {
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.5);
    this.scene.add(ambientLight);

    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
    directionalLight.position.set(1, 1, 1);
    this.scene.add(directionalLight);
  }

  setupControls() {
    this.controls = new THREE.OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.05;
    this.controls.screenSpacePanning = true;
  }

  async loadModel(url) {
    try {
      const loader = new THREE.GLTFLoader();
      const gltf = await loader.loadAsync(url);
      
      if (this.model) {
        this.scene.remove(this.model);
      }
      
      this.model = gltf.scene;
      this.scene.add(this.model);
      
      // Store meshes and materials
      this.meshes.clear();
      this.originalMaterials.clear();
      
      this.model.traverse((child) => {
        if (child.isMesh) {
          this.meshes.set(child.name, child);
          this.originalMaterials.set(child.name, child.material.clone());
        }
      });
      
      // Center and scale model
      const box = new THREE.Box3().setFromObject(this.model);
      const center = box.getCenter(new THREE.Vector3());
      const size = box.getSize(new THREE.Vector3());
      const maxDim = Math.max(size.x, size.y, size.z);
      const scale = 2 / maxDim;
      
      this.model.position.sub(center.multiplyScalar(scale));
      this.model.scale.multiplyScalar(scale);
      
      // Reset camera
      this.resetCamera();
      
      return true;
    } catch (error) {
      console.error('Error loading model:', error);
      return false;
    }
  }

  focusOnMesh(meshName, status = 'active', severity = 'moderate') {
    const targetMesh = this.findMesh(meshName);
    if (!targetMesh) {
      console.error('Mesh not found:', meshName);
      return;
    }

    // Reset all meshes
    this.meshes.forEach((mesh) => {
      mesh.material = this.originalMaterials.get(mesh.name).clone();
      mesh.material.transparent = true;
      mesh.material.opacity = 0.3;
    });

    // Set color based on status
    const color = status === 'active' ? 0xff0000 :
                 status === 'past' ? 0xffa500 :
                 0x00ff00;

    // Highlight target mesh
    targetMesh.material = new THREE.MeshPhongMaterial({
      color: color,
      transparent: false,
      opacity: 1.0,
      shininess: 30
    });

    // Focus camera on mesh
    this.focusCameraOnMesh(targetMesh);
  }

  findMesh(meshName) {
    const searchName = meshName.toLowerCase();
    return Array.from(this.meshes.values()).find(mesh => 
      mesh.name.toLowerCase().includes(searchName)
    );
  }

  focusCameraOnMesh(mesh) {
    const box = new THREE.Box3().setFromObject(mesh);
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z);
    
    const direction = new THREE.Vector3(1, 0.5, 1).normalize();
    const distance = maxDim * 2;
    const target = center.clone();
    
    // Animate camera movement
    const startPosition = this.camera.position.clone();
    const startTarget = this.controls.target.clone();
    const duration = 1000; // ms
    const startTime = Date.now();
    
    const animate = () => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const eased = this.easeInOutCubic(progress);
      
      this.camera.position.lerpVectors(
        startPosition,
        center.clone().add(direction.multiplyScalar(distance)),
        eased
      );
      
      this.controls.target.lerpVectors(startTarget, target, eased);
      
      if (progress < 1) {
        requestAnimationFrame(animate);
      }
    };
    
    animate();
  }

  resetCamera() {
    if (!this.model) return;
    
    const box = new THREE.Box3().setFromObject(this.model);
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z);
    
    this.camera.position.set(maxDim * 2, maxDim, maxDim * 2);
    this.controls.target.copy(center);
    this.controls.update();
  }

  easeInOutCubic(x) {
    return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
  }

  onWindowResize() {
    this.camera.aspect = this.container.clientWidth / this.container.clientHeight;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(this.container.clientWidth, this.container.clientHeight);
  }

  animate() {
    requestAnimationFrame(() => this.animate());
    this.controls.update();
    this.renderer.render(this.scene, this.camera);
  }
}

// Make ThreeViewer available globally
window.ThreeViewer = ThreeViewer; 
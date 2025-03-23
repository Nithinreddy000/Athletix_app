class EnhancedThreeViewer {
  constructor(containerId) {
    console.log(`Initializing EnhancedThreeViewer with container ID: ${containerId}`);
    this.container = document.getElementById(containerId);
    if (!this.container) {
      console.error(`Container with ID ${containerId} not found!`);
      return;
    }
    
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 1000);
    this.renderer = new THREE.WebGLRenderer({ 
      antialias: true, 
      alpha: true,
      powerPreference: 'high-performance'
    });
    this.controls = null;
    this.model = null;
    this.meshes = new Map();
    this.originalMaterials = new Map();
    this.isLoadingModel = false;
    this.modelLoadedCallback = null;
    
    this.init();
    this.setupLights();
    this.setupControls();
    this.animate();
    
    // Add a flag to track if the viewer has been disposed
    this.isDisposed = false;
    
    // Track the current model URL to prevent reloading the same model
    this.currentModelUrl = null;
    
    console.log('EnhancedThreeViewer initialized successfully');
  }
  
  init() {
    // Configure renderer
    this.renderer.setPixelRatio(window.devicePixelRatio);
    this.renderer.setClearColor(0x000000, 0); // Transparent background
    this.renderer.outputEncoding = THREE.sRGBEncoding;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.0;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    
    // Set renderer size
    const width = this.container.clientWidth;
    const height = this.container.clientHeight;
    this.renderer.setSize(width, height);
    
    // Add renderer to container
    this.container.appendChild(this.renderer.domElement);
    
    // Set up camera
    this.camera.position.set(0, 0, 5);
    this.camera.lookAt(0, 0, 0);
    
    // Add window resize listener
    window.addEventListener('resize', this.onWindowResize.bind(this));
    
    // Initialize the composer for post-processing
    this.setupPostProcessing();
  }
  
  setupPostProcessing() {
    try {
      // Create composer
      this.composer = new THREE.EffectComposer(this.renderer);
      
      // Add render pass
      const renderPass = new THREE.RenderPass(this.scene, this.camera);
      this.composer.addPass(renderPass);
      
      // Add FXAA pass for anti-aliasing
      const fxaaPass = new THREE.ShaderPass(THREE.FXAAShader);
      const pixelRatio = this.renderer.getPixelRatio();
      fxaaPass.material.uniforms['resolution'].value.x = 1 / (this.container.offsetWidth * pixelRatio);
      fxaaPass.material.uniforms['resolution'].value.y = 1 / (this.container.offsetHeight * pixelRatio);
      this.composer.addPass(fxaaPass);
      
      // Add bloom pass for glow effects
      const bloomPass = new THREE.UnrealBloomPass(
        new THREE.Vector2(window.innerWidth, window.innerHeight),
        0.5,  // strength
        0.4,  // radius
        0.85  // threshold
      );
      this.composer.addPass(bloomPass);
      
      // Add color correction pass
      const colorCorrectionPass = new THREE.ShaderPass(THREE.ColorCorrectionShader);
      colorCorrectionPass.uniforms['powRGB'].value = new THREE.Vector3(1.1, 1.1, 1.1);
      colorCorrectionPass.uniforms['mulRGB'].value = new THREE.Vector3(1.2, 1.2, 1.2);
      this.composer.addPass(colorCorrectionPass);
      
      console.log('Post-processing setup complete');
    } catch (error) {
      console.error('Error setting up post-processing:', error);
      // Continue without post-processing
    }
  }
  
  setupLights() {
    // Ambient light
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.5);
    this.scene.add(ambientLight);
    
    // Directional light (sun)
    const mainLight = new THREE.DirectionalLight(0xffffff, 1.0);
    mainLight.position.set(5, 10, 5);
    mainLight.castShadow = true;
    
    // Improve shadow quality
    mainLight.shadow.mapSize.width = 2048;
    mainLight.shadow.mapSize.height = 2048;
    mainLight.shadow.camera.near = 0.5;
    mainLight.shadow.camera.far = 50;
    mainLight.shadow.bias = -0.0001;
    
    const d = 15;
    mainLight.shadow.camera.left = -d;
    mainLight.shadow.camera.right = d;
    mainLight.shadow.camera.top = d;
    mainLight.shadow.camera.bottom = -d;
    
    this.scene.add(mainLight);
    
    // Add a secondary light from the opposite direction
    const secondaryLight = new THREE.DirectionalLight(0xffffcc, 0.5);
    secondaryLight.position.set(-5, 5, -5);
    this.scene.add(secondaryLight);
    
    // Add a hemisphere light for better ambient illumination
    const hemiLight = new THREE.HemisphereLight(0xffffff, 0x444444, 0.5);
    hemiLight.position.set(0, 20, 0);
    this.scene.add(hemiLight);
  }
  
  setupControls() {
    this.controls = new THREE.OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.05;
    this.controls.screenSpacePanning = false;
    this.controls.minDistance = 1;
    this.controls.maxDistance = 20;
    this.controls.maxPolarAngle = Math.PI;
    this.controls.target.set(0, 0, 0);
  }
  
  onWindowResize() {
    if (this.isDisposed) return;
    
    const width = this.container.clientWidth;
    const height = this.container.clientHeight;
    
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    
    this.renderer.setSize(width, height);
    
    if (this.composer) {
      this.composer.setSize(width, height);
      
      // Update FXAA uniforms
      const pixelRatio = this.renderer.getPixelRatio();
      const fxaaPass = this.composer.passes.find(pass => pass.material && pass.material.uniforms && pass.material.uniforms['resolution']);
      
      if (fxaaPass) {
        fxaaPass.material.uniforms['resolution'].value.x = 1 / (width * pixelRatio);
        fxaaPass.material.uniforms['resolution'].value.y = 1 / (height * pixelRatio);
      }
    }
  }
  
  animate() {
    if (this.isDisposed) return;
    
    requestAnimationFrame(this.animate.bind(this));
    
    if (this.controls) {
      this.controls.update();
    }
    
    if (this.composer && this.composer.enabled) {
      this.composer.render();
    } else {
      this.renderer.render(this.scene, this.camera);
    }
  }
  
  resetCamera() {
    if (this.isDisposed) return;
    
    if (!this.model) return;
    
    // Calculate bounding box
    const box = new THREE.Box3().setFromObject(this.model);
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    
    // Set controls target to center of model
    this.controls.target.copy(center);
    
    // Adjust camera position based on model size
    const maxDim = Math.max(size.x, size.y, size.z);
    const fov = this.camera.fov * (Math.PI / 180);
    const distance = maxDim / (2 * Math.tan(fov / 2));
    
    const direction = new THREE.Vector3();
    this.camera.getWorldDirection(direction);
    direction.multiplyScalar(-distance * 1.5);
    this.camera.position.copy(center).add(direction);
    
    // Update controls
    this.controls.update();
  }
  
  showLoadingIndicator(show) {
    const loadingIndicator = document.getElementById('loading-indicator');
    if (loadingIndicator) {
      loadingIndicator.style.display = show ? 'flex' : 'none';
    }
  }

  async loadModel(url) {
    if (this.isLoadingModel) {
      console.log('Already loading a model, ignoring this request');
        return false;
      }
      
    this.isLoadingModel = true;
      this.showLoadingIndicator(true);
    console.log(`Loading model from: ${url}`);

    // Clear previous model if any
    if (this.model) {
      this.scene.remove(this.model);
      this.modelMeshes = {};
      this.model = null;
    }

    let successfulLoad = false;
    let errorMessage = '';

    try {
      // Try several options for loading the model with different CORS settings
      const loadOptions = [
        // Option 1: Standard fetch with CORS
        { mode: 'cors', credentials: 'same-origin' },
        // Option 2: No CORS mode
        { mode: 'no-cors' },
        // Option 3: Direct GLTFLoader without fetch first
        null
      ];

      for (let i = 0; i < loadOptions.length; i++) {
        try {
          if (loadOptions[i] !== null) {
            // Try to fetch first to check if URL is accessible
            console.log(`Trying fetch with options: ${JSON.stringify(loadOptions[i])}`);
            const response = await fetch(url, loadOptions[i]);
            
            if (!response.ok && loadOptions[i].mode === 'cors') {
              console.log(`Fetch failed with status: ${response.status}`);
              continue; // Try next option
            }
          }
          
          // If fetch succeeded or we're trying direct loading
          console.log(`Loading model with ${loadOptions[i] ? loadOptions[i].mode : 'direct'} mode`);
          
          // Set up loaders
          const gltfLoader = new THREE.GLTFLoader();
          const dracoLoader = new THREE.DRACOLoader();
          dracoLoader.setDecoderPath('https://www.gstatic.com/draco/versioned/decoders/1.5.5/');
          gltfLoader.setDRACOLoader(dracoLoader);
          
          // Load the model
          const gltf = await new Promise((resolve, reject) => {
            gltfLoader.load(
              url,
              resolve,
              (xhr) => {
                const percent = Math.round((xhr.loaded / xhr.total) * 100);
                console.log(`Loading progress: ${percent}%`);
                
                // Update loading indicator
                const loadingElement = document.getElementById('loading-indicator');
                if (loadingElement) {
                  const msgElement = loadingElement.querySelector('div:not(.loading-spinner)');
                  if (msgElement) {
                    msgElement.textContent = `Loading model... ${percent}%`;
                  }
                }
              },
              reject
            );
          });
          
          // If we got here, the model loaded successfully
          this.onModelLoaded(gltf);
          successfulLoad = true;
          break; // Exit the loop once loaded
          
        } catch (optionError) {
          console.warn(`Loading attempt ${i+1} failed:`, optionError);
          errorMessage = optionError.message || 'Unknown error loading model';
          // Continue to the next option unless we're at the last one
          if (i === loadOptions.length - 1) {
            throw optionError; // Re-throw the last error
          }
        }
      }
    } catch (error) {
      console.error('All loading attempts failed:', error);
      this.showLoadingIndicator(false);
      this.isLoadingModel = false;
      
      // Notify about the error
      if (this.modelLoadedCallback) {
        this.modelLoadedCallback(false);
      }
      
      return false;
    }

    this.showLoadingIndicator(false);
    this.isLoadingModel = false;
    
    // Notify about successful loading
    if (this.modelLoadedCallback) {
      this.modelLoadedCallback(successfulLoad);
    }
    
    return successfulLoad;
  }
  
  notifyModelLoaded(success) {
    // Try multiple methods to notify
    try {
      // Method 1: Call a global callback function if defined
      if (typeof ModelViewerCallback !== 'undefined' && ModelViewerCallback.postMessage) {
        console.log('Calling ModelViewerCallback.postMessage with:', success.toString());
        ModelViewerCallback.postMessage(success.toString());
      }
    } catch (e) {
      console.error('Error calling ModelViewerCallback:', e);
    }
    
    try {
      // Method 2: PostMessage to parent window (for iframe approach)
      window.parent.postMessage(success ? 'modelLoaded' : 'modelLoadError', '*');
      console.log('Posted message to parent window:', success ? 'modelLoaded' : 'modelLoadError');
    } catch (e) {
      console.error('Error posting message to parent:', e);
    }
    
    try {
      // Method 3: Use a custom callback if provided
      if (this.modelLoadedCallback) {
        console.log('Calling custom modelLoadedCallback with:', success);
        this.modelLoadedCallback(success);
      }
    } catch (e) {
      console.error('Error calling custom callback:', e);
    }
  }
  
  dispose() {
    if (this.isDisposed) return;
    
    console.log('Disposing EnhancedThreeViewer');
    this.isDisposed = true;
    
    // Stop animation loop
    cancelAnimationFrame(this.animationId);
    
    // Remove event listeners
    window.removeEventListener('resize', this.onWindowResize);
    
    // Dispose of model
    if (this.model) {
      this.scene.remove(this.model);
      this.model.traverse((child) => {
        if (child.isMesh) {
          if (child.geometry) child.geometry.dispose();
          if (child.material) {
            if (Array.isArray(child.material)) {
              child.material.forEach(material => material.dispose());
            } else {
              child.material.dispose();
            }
          }
        }
      });
    }
    
    // Dispose of meshes map
    this.meshes.clear();
    
    // Dispose of materials
    this.originalMaterials.forEach((material) => {
      material.dispose();
    });
    this.originalMaterials.clear();
    
    // Dispose of renderer
    if (this.renderer) {
      this.renderer.dispose();
      this.container.removeChild(this.renderer.domElement);
    }
    
    // Dispose of composer
    if (this.composer) {
      this.composer.passes.forEach(pass => {
        if (pass.dispose) pass.dispose();
      });
    }
    
    // Dispose of controls
    if (this.controls) {
      this.controls.dispose();
    }
    
    console.log('EnhancedThreeViewer disposed successfully');
  }

  onModelLoaded(gltf) {
    console.log('Model data received, setting up scene...');
    
    // Remove previous model if exists
    if (this.model) {
      this.scene.remove(this.model);
      // Also dispose of resources
      this.model.traverse((child) => {
        if (child.isMesh) {
          if (child.geometry) child.geometry.dispose();
          if (child.material) {
            if (Array.isArray(child.material)) {
              child.material.forEach(material => material.dispose());
            } else {
              child.material.dispose();
            }
          }
        }
      });
    }
    
    this.model = gltf.scene;
    this.scene.add(this.model);
    
    // Clear existing meshes
    this.meshes.clear();
    this.originalMaterials.clear();
    
    this.model.traverse((child) => {
      if (child.isMesh) {
        // Store mesh by name for easy access later
        this.meshes.set(child.name, child);
        
        // Create and store original material
        const originalMaterial = child.material.clone();
        originalMaterial._isClone = true;
        this.originalMaterials.set(child.name, originalMaterial);
        
        // Determine if this is an outer mesh (we'll make these transparent)
        const isOuterMesh = child.name.toLowerCase().includes('outer') || 
                           child.name.toLowerCase().includes('external') ||
                           child.name.toLowerCase().includes('shell');
        
        if (isOuterMesh) {
          // Make outer meshes transparent
          child.material = new THREE.MeshStandardMaterial({
            color: originalMaterial.color || 0xffffff,
            map: originalMaterial.map,
            normalMap: originalMaterial.normalMap,
            transparent: true,
            opacity: 0.05,
            roughness: 0.9,
            metalness: 0.0,
            side: THREE.DoubleSide
          });
        } else {
          // Apply enhanced material to inner meshes
          child.material = new THREE.MeshStandardMaterial({
            color: originalMaterial.color || 0xffffff,
            map: originalMaterial.map,
            normalMap: originalMaterial.normalMap,
            roughness: 0.7,
            metalness: 0.0,
            envMapIntensity: 0.5
          });
        }
        
        // Enable shadows
        child.castShadow = true;
        child.receiveShadow = true;
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
  }
}

// Make EnhancedThreeViewer available globally
window.EnhancedThreeViewer = EnhancedThreeViewer; 
class BabylonViewer {
    constructor(containerId) {
        this.container = document.getElementById(containerId);
        this.canvas = document.createElement('canvas');
        this.container.appendChild(this.canvas);
        this.engine = new BABYLON.Engine(this.canvas, true);
        this.scene = null;
        this.camera = null;
        this.model = null;
        this.meshes = new Map();
        this.originalMaterials = new Map();
        
        this.init();
    }

    init() {
        this.scene = new BABYLON.Scene(this.engine);
        this.scene.clearColor = new BABYLON.Color4(0, 0, 0, 0);
        
        this.camera = new BABYLON.ArcRotateCamera(
            "camera",
            0,
            Math.PI / 3,
            10,
            BABYLON.Vector3.Zero(),
            this.scene
        );
        this.camera.attachControl(this.canvas, true);
        this.camera.wheelPrecision = 50;
        this.camera.pinchPrecision = 50;
        
        this.setupLights();
        
        window.addEventListener('resize', () => {
            this.engine.resize();
        });
        
        this.engine.runRenderLoop(() => {
            this.scene.render();
        });
    }

    setupLights() {
        new BABYLON.HemisphericLight(
            "light1",
            new BABYLON.Vector3(0, 1, 0),
            this.scene
        );
        const dirLight = new BABYLON.DirectionalLight(
            "light2",
            new BABYLON.Vector3(-1, -2, -1),
            this.scene
        );
        dirLight.intensity = 0.5;
    }

    async loadModel(url) {
        try {
            if (this.model) {
                this.model.dispose();
                this.meshes.clear();
                this.originalMaterials.clear();
            }

            const result = await BABYLON.SceneLoader.ImportMeshAsync(
                "",
                url,
                "",
                this.scene,
                (evt) => {
                    const loadedPercent = (evt.loaded * 100 / evt.total).toFixed();
                    console.log(`Loading: ${loadedPercent}%`);
                }
            );

            this.model = result;
            
            result.meshes.forEach((mesh) => {
                if (mesh.name !== "__root__") {
                    this.meshes.set(mesh.name, mesh);
                    this.originalMaterials.set(mesh.name, mesh.material.clone());
                }
            });

            this.resetView();
            ModelViewerCallback.postMessage('true');
            return true;
        } catch (error) {
            console.error('Error loading model:', error);
            ModelViewerCallback.postMessage('false');
            return false;
        }
    }

    focusOnMesh(meshName, status = 'active', severity = 'moderate') {
        const targetMesh = this.findMesh(meshName);
        if (!targetMesh) {
            console.error('Mesh not found:', meshName);
            return;
        }

        // Get target mesh bounding info
        const targetBoundingInfo = targetMesh.getBoundingInfo();
        const targetCenter = targetBoundingInfo.boundingBox.centerWorld;
        
        // Get camera position
        const cameraPosition = this.camera.position;
        const cameraDirection = targetCenter.subtract(cameraPosition).normalize();

        // Reset all meshes to their original materials first
        this.meshes.forEach((mesh, name) => {
            mesh.material = this.originalMaterials.get(name).clone();
            mesh.material.alpha = 1.0; // Start with full opacity
        });

        // Create highlight material for target mesh
        const highlightMaterial = new BABYLON.StandardMaterial("highlightMaterial", this.scene);
        
        // Set color based on status
        switch (status) {
            case 'active':
                highlightMaterial.diffuseColor = new BABYLON.Color3(1, 0, 0); // Red
                break;
            case 'recovered':
                highlightMaterial.diffuseColor = new BABYLON.Color3(0, 1, 0); // Green
                break;
            default:
                highlightMaterial.diffuseColor = new BABYLON.Color3(1, 0.65, 0); // Orange
        }

        highlightMaterial.specularColor = new BABYLON.Color3(0.5, 0.6, 0.87);
        highlightMaterial.emissiveColor = highlightMaterial.diffuseColor.scale(0.3);
        highlightMaterial.alpha = 1.0;

        // Apply highlight material to target mesh
        targetMesh.material = highlightMaterial;

        // Check each mesh for obstruction
        this.meshes.forEach((mesh, name) => {
            if (mesh !== targetMesh) {
                const isObstructing = this.isMeshObstructing(mesh, targetMesh, cameraPosition, cameraDirection);
                if (isObstructing) {
                    mesh.material.alpha = 0.2; // Make obstructing meshes more transparent
                }
            }
        });

        this.focusCameraOnMesh(targetMesh);
    }

    isMeshObstructing(mesh, targetMesh, cameraPosition, cameraDirection) {
        // Skip if mesh is behind the camera
        const meshCenter = mesh.getBoundingInfo().boundingBox.centerWorld;
        const targetCenter = targetMesh.getBoundingInfo().boundingBox.centerWorld;
        
        // Vector from camera to mesh center
        const cameraToMesh = meshCenter.subtract(cameraPosition);
        const cameraToTarget = targetCenter.subtract(cameraPosition);
        
        // Project vectors onto camera direction
        const meshDist = BABYLON.Vector3.Dot(cameraToMesh, cameraDirection);
        const targetDist = BABYLON.Vector3.Dot(cameraToTarget, cameraDirection);
        
        // If mesh is behind target, it's not obstructing
        if (meshDist > targetDist) {
            return false;
        }
        
        // Check if mesh intersects the line of sight
        const rayOrigin = cameraPosition;
        const rayDirection = targetCenter.subtract(cameraPosition).normalize();
        const ray = new BABYLON.Ray(rayOrigin, rayDirection, targetDist);
        
        // Use mesh picking to check for intersection
        const hit = mesh.intersects(ray, false);
        return hit;
    }

    findMesh(meshName) {
        const searchName = meshName.toLowerCase();
        return Array.from(this.meshes.values()).find(mesh => 
            mesh.name.toLowerCase().includes(searchName)
        );
    }

    focusCameraOnMesh(mesh) {
        const boundingBox = mesh.getBoundingInfo().boundingBox;
        const center = boundingBox.centerWorld;
        const radius = boundingBox.extendSizeWorld.length();

        // Calculate optimal camera position
        const targetRadius = radius * 2.5;
        
        // Animate camera movement
        BABYLON.Animation.CreateAndStartAnimation(
            "cameraMove",
            this.camera,
            "target",
            60,
            30,
            this.camera.target,
            center,
            BABYLON.Animation.ANIMATIONLOOPMODE_CONSTANT
        );

        BABYLON.Animation.CreateAndStartAnimation(
            "cameraRadius",
            this.camera,
            "radius",
            60,
            30,
            this.camera.radius,
            targetRadius,
            BABYLON.Animation.ANIMATIONLOOPMODE_CONSTANT
        );

        // After camera movement, update mesh visibility
        setTimeout(() => {
            this.updateMeshVisibility(mesh);
        }, 500);
    }

    updateMeshVisibility(targetMesh) {
        const cameraPosition = this.camera.position;
        const targetCenter = targetMesh.getBoundingInfo().boundingBox.centerWorld;
        const cameraDirection = targetCenter.subtract(cameraPosition).normalize();
        
        this.meshes.forEach((mesh, name) => {
            if (mesh !== targetMesh) {
                const isObstructing = this.isMeshObstructing(mesh, targetMesh, cameraPosition, cameraDirection);
                if (isObstructing) {
                    mesh.material.alpha = 0.2;
                } else {
                    mesh.material.alpha = 1.0;
                }
            }
        });
    }

    resetView() {
        if (!this.model) return;

        const boundingInfo = new BABYLON.BoundingInfo(
            BABYLON.Vector3.MinimumFromArray(this.model.meshes.map(mesh => mesh.getBoundingInfo().boundingBox.minimumWorld)),
            BABYLON.Vector3.MaximumFromArray(this.model.meshes.map(mesh => mesh.getBoundingInfo().boundingBox.maximumWorld))
        );

        const center = boundingInfo.boundingBox.centerWorld;
        const radius = boundingInfo.boundingBox.extendSizeWorld.length();

        this.camera.setTarget(center);
        this.camera.setPosition(new BABYLON.Vector3(
            center.x + radius * 2,
            center.y + radius,
            center.z + radius * 2
        ));
    }
}

// Initialize viewer when page loads
window.addEventListener('load', function() {
    window.viewer = new BabylonViewer('modelViewer');
}); 
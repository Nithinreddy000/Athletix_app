// Custom interface for model-viewer to handle injury visualization
class ModelViewerInterface {
  constructor(modelViewer) {
    this.modelViewer = modelViewer;
    this.injuries = new Map();
    this.setupEventListeners();
  }

  setupEventListeners() {
    // Handle model loading
    this.modelViewer.addEventListener('load', () => {
      this.updateInjuryVisualization();
    });

    // Handle camera changes
    this.modelViewer.addEventListener('camera-change', () => {
      this.updateInjuryVisualization();
    });
  }

  setInjuries(injuryData) {
    this.injuries.clear();
    injuryData.forEach(injury => {
      const { bodyPart, color, coordinates } = injury;
      this.injuries.set(bodyPart, { color, coordinates });
    });
    this.updateInjuryVisualization();
  }

  updateInjuryVisualization() {
    const material = this.modelViewer.model?.materials[0];
    if (!material) return;

    // Reset all body parts to default color
    this.resetBodyPartColors();

    // Apply injury colors
    this.injuries.forEach((data, bodyPart) => {
      const { color, coordinates } = data;
      this.colorBodyPart(bodyPart, color, coordinates);
    });
  }

  resetBodyPartColors() {
    const material = this.modelViewer.model?.materials[0];
    if (!material) return;

    // Reset to default material color
    material.pbrMetallicRoughness.setBaseColorFactor([0.8, 0.8, 0.8, 1.0]);
  }

  colorBodyPart(bodyPart, color, coordinates) {
    const material = this.modelViewer.model?.materials[0];
    if (!material) return;

    // Convert hex color to RGB
    const rgb = this.hexToRgb(color);
    if (!rgb) return;

    // Create a new material for the body part
    const newMaterial = {
      ...material,
      pbrMetallicRoughness: {
        baseColorFactor: [rgb.r / 255, rgb.g / 255, rgb.b / 255, 1.0],
        metallicFactor: 0.0,
        roughnessFactor: 1.0
      }
    };

    // Apply material to the specific body part
    const mesh = this.findBodyPartMesh(bodyPart);
    if (mesh) {
      mesh.material = newMaterial;
    }
  }

  findBodyPartMesh(bodyPart) {
    const scene = this.modelViewer.model?.scene;
    if (!scene) return null;

    // Search for mesh with matching name
    return scene.traverse(node => {
      if (node.name.toLowerCase().includes(bodyPart.toLowerCase())) {
        return node;
      }
    });
  }

  hexToRgb(hex) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? {
      r: parseInt(result[1], 16),
      g: parseInt(result[2], 16),
      b: parseInt(result[3], 16)
    } : null;
  }
}

// Export the interface
window.ModelViewerInterface = ModelViewerInterface;

// Model Viewer Interface for Injury Visualization
class InjuryMarkerManager {
  constructor(modelViewer) {
    this.modelViewer = modelViewer;
    this.markers = new Map();
    this.selectedMarker = null;
  }

  addMarker(injury) {
    const marker = document.createElement('div');
    marker.className = 'injury-marker';
    marker.style.backgroundColor = injury.colorCode;
    marker.style.position = 'absolute';
    marker.style.width = '20px';
    marker.style.height = '20px';
    marker.style.borderRadius = '50%';
    marker.style.transform = 'translate(-50%, -50%)';
    marker.style.cursor = 'pointer';
    marker.style.transition = 'all 0.3s ease';
    marker.dataset.injuryId = injury.id;

    marker.addEventListener('click', () => {
      this.selectMarker(marker, injury);
    });

    marker.addEventListener('mouseover', () => {
      marker.style.transform = 'translate(-50%, -50%) scale(1.2)';
      marker.style.boxShadow = '0 0 10px rgba(0,0,0,0.3)';
    });

    marker.addEventListener('mouseout', () => {
      if (this.selectedMarker !== marker) {
        marker.style.transform = 'translate(-50%, -50%) scale(1)';
        marker.style.boxShadow = 'none';
      }
    });

    this.modelViewer.appendChild(marker);
    this.markers.set(injury.id, marker);
    this.updateMarkerPosition(injury);
  }

  updateMarkerPosition(injury) {
    const marker = this.markers.get(injury.id);
    if (!marker) return;

    const animate = () => {
      const center = this.modelViewer.getBoundingBoxCenter();
      const rect = this.modelViewer.getBoundingClientRect();
      
      // Convert 3D coordinates to screen space
      const x = rect.left + (0.5 + injury.coordinates.x) * rect.width;
      const y = rect.top + (1 - injury.coordinates.y) * rect.height;
      
      marker.style.left = `${x}px`;
      marker.style.top = `${y}px`;
      
      requestAnimationFrame(animate);
    };

    animate();
  }

  selectMarker(marker, injury) {
    if (this.selectedMarker) {
      this.selectedMarker.style.transform = 'translate(-50%, -50%) scale(1)';
      this.selectedMarker.style.boxShadow = 'none';
    }

    marker.style.transform = 'translate(-50%, -50%) scale(1.2)';
    marker.style.boxShadow = '0 0 10px rgba(0,0,0,0.3)';
    this.selectedMarker = marker;

    // Notify Flutter
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('onInjurySelected', injury);
    }
  }

  removeAllMarkers() {
    this.markers.forEach(marker => marker.remove());
    this.markers.clear();
    this.selectedMarker = null;
  }
}

// Initialize when the model viewer is ready
window.addEventListener('load', () => {
  const modelViewer = document.querySelector('model-viewer');
  if (modelViewer) {
    window.injuryMarkerManager = new InjuryMarkerManager(modelViewer);
  }
}); 
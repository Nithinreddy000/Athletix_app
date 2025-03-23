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
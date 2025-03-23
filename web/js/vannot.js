// Vannot Video Annotation Tool Integration
// Based on https://github.com/xyonix/vannot

// Global variable to store the Vannot instance
let vannotInstance = null;
let videoElement = null;
let isDrawingEnabled = false;

// Initialize Vannot with the given video URL and container element ID
function initVannot(videoUrl, containerId, width, height, fps) {
  console.log('Initializing Vannot with URL:', videoUrl);
  
  // Clean up any existing instance
  if (vannotInstance) {
    vannotInstance.destroy();
    vannotInstance = null;
  }

  // Get the container element
  const container = document.getElementById(containerId);
  if (!container) {
    console.error('Container element not found:', containerId);
    return false;
  }

  // Create the Vannot configuration
  const config = {
    video: {
      source: videoUrl,
      width: width || 1920,
      height: height || 1080,
      fps: fps || 30,
      duration: 0, // Will be determined automatically
    },
    // We'll save annotations locally for now
    saveUrl: null,
    onSave: function(data) {
      // Store annotations in localStorage
      localStorage.setItem('vannot_annotations_' + videoUrl, JSON.stringify(data));
      // Send message to Flutter
      if (window.flutterVannotBridge) {
        window.flutterVannotBridge.postMessage(JSON.stringify({
          type: 'save',
          data: data
        }));
      }
      return Promise.resolve();
    }
  };

  // Try to load existing annotations
  const savedData = localStorage.getItem('vannot_annotations_' + videoUrl);
  if (savedData) {
    try {
      const parsedData = JSON.parse(savedData);
      // Merge saved data with config
      config.frames = parsedData.frames || [];
      config.objects = parsedData.objects || [];
      config.instances = parsedData.instances || [];
    } catch (e) {
      console.error('Error parsing saved annotations:', e);
    }
  }

  // Initialize Vannot
  try {
    // Clear the container first
    container.innerHTML = '';
    
    // Create a wrapper div for Vannot
    const vannotWrapper = document.createElement('div');
    vannotWrapper.id = 'vannot-wrapper';
    vannotWrapper.style.width = '100%';
    vannotWrapper.style.height = '100%';
    vannotWrapper.style.position = 'relative';
    container.appendChild(vannotWrapper);

    // Load Vannot library dynamically
    loadVannotLibrary().then(() => {
      if (window.Vannot) {
        console.log('Vannot library loaded, creating instance');
        
        try {
          vannotInstance = new window.Vannot({
            element: vannotWrapper,
            ...config
          });
          
          console.log('Vannot instance created successfully');
          
          // Store reference to the video element for pause/play control
          setTimeout(() => {
            // Find the video element within the Vannot instance
            const videoElements = vannotWrapper.querySelectorAll('video');
            if (videoElements.length > 0) {
              videoElement = videoElements[0];
              console.log('Video element found and stored for control');
              
              // Pause the video initially
              if (videoElement && !videoElement.paused) {
                videoElement.pause();
              }
            } else {
              console.warn('No video elements found in Vannot wrapper');
            }
            
            // Add custom drawing controls
            addCustomDrawingControls(vannotWrapper);
          }, 1000);
          
          // Notify Flutter that Vannot is ready
          if (window.flutterVannotBridge) {
            window.flutterVannotBridge.postMessage(JSON.stringify({
              type: 'ready',
              success: true
            }));
          }
        } catch (e) {
          console.error('Error creating Vannot instance:', e);
          if (window.flutterVannotBridge) {
            window.flutterVannotBridge.postMessage(JSON.stringify({
              type: 'ready',
              success: false,
              error: 'Error creating Vannot instance: ' + e.toString()
            }));
          }
        }
      } else {
        console.error('Vannot library not loaded properly');
        if (window.flutterVannotBridge) {
          window.flutterVannotBridge.postMessage(JSON.stringify({
            type: 'ready',
            success: false,
            error: 'Vannot library not loaded'
          }));
        }
      }
    }).catch(error => {
      console.error('Failed to load Vannot library:', error);
      if (window.flutterVannotBridge) {
        window.flutterVannotBridge.postMessage(JSON.stringify({
          type: 'ready',
          success: false,
          error: error.toString()
        }));
      }
    });

    return true;
  } catch (e) {
    console.error('Error initializing Vannot:', e);
    if (window.flutterVannotBridge) {
      window.flutterVannotBridge.postMessage(JSON.stringify({
        type: 'ready',
        success: false,
        error: e.toString()
      }));
    }
    return false;
  }
}

// Add custom drawing controls to the Vannot wrapper
function addCustomDrawingControls(wrapper) {
  if (!wrapper) return;
  
  // Create a container for the drawing controls
  const controlsContainer = document.createElement('div');
  controlsContainer.id = 'vannot-drawing-controls';
  controlsContainer.style.position = 'absolute';
  controlsContainer.style.top = '16px';
  controlsContainer.style.left = '16px';
  controlsContainer.style.zIndex = '9999';
  controlsContainer.style.backgroundColor = 'rgba(0, 0, 0, 0.6)';
  controlsContainer.style.borderRadius = '30px';
  controlsContainer.style.padding = '8px';
  controlsContainer.style.display = 'flex';
  controlsContainer.style.gap = '8px';
  
  // Create the draw button
  const drawButton = document.createElement('button');
  drawButton.id = 'vannot-draw-button';
  drawButton.style.background = 'transparent';
  drawButton.style.border = 'none';
  drawButton.style.color = 'white';
  drawButton.style.fontSize = '24px';
  drawButton.style.cursor = 'pointer';
  drawButton.style.padding = '8px';
  drawButton.title = 'Draw Mode';
  drawButton.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24" fill="white"><path d="M0 0h24v24H0z" fill="none"/><path d="M7 14c-1.66 0-3 1.34-3 3 0 1.31-1.16 2-2 2 .92 1.22 2.49 2 4 2 2.21 0 4-1.79 4-4 0-1.66-1.34-3-3-3zm13.71-9.37l-1.34-1.34c-.39-.39-1.02-.39-1.41 0L9 12.25 11.75 15l8.96-8.96c.39-.39.39-1.02 0-1.41z"/></svg>';
  
  // Create the select button
  const selectButton = document.createElement('button');
  selectButton.id = 'vannot-select-button';
  selectButton.style.background = 'transparent';
  selectButton.style.border = 'none';
  selectButton.style.color = 'white';
  selectButton.style.fontSize = '24px';
  selectButton.style.cursor = 'pointer';
  selectButton.style.padding = '8px';
  selectButton.title = 'Select Mode';
  selectButton.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24" fill="white"><path d="M0 0h24v24H0z" fill="none"/><path d="M13 1.07V9h7c0-4.08-3.05-7.44-7-7.93zM4 15c0 4.42 3.58 8 8 8s8-3.58 8-8v-4H4v4zm7-13.93C7.05 1.56 4 4.92 4 9h7V1.07z"/></svg>';
  
  // Add event listeners
  drawButton.addEventListener('click', () => {
    if (vannotInstance) {
      vannotInstance.setTool('draw');
      isDrawingEnabled = true;
      drawButton.style.backgroundColor = 'rgba(0, 123, 255, 0.5)';
      selectButton.style.backgroundColor = 'transparent';
      
      // Pause the video
      if (videoElement && !videoElement.paused) {
        videoElement.pause();
      }
    }
  });
  
  selectButton.addEventListener('click', () => {
    if (vannotInstance) {
      vannotInstance.setTool('select');
      isDrawingEnabled = false;
      selectButton.style.backgroundColor = 'rgba(0, 123, 255, 0.5)';
      drawButton.style.backgroundColor = 'transparent';
    }
  });
  
  // Add buttons to the container
  controlsContainer.appendChild(drawButton);
  controlsContainer.appendChild(selectButton);
  
  // Add the container to the wrapper
  wrapper.appendChild(controlsContainer);
}

// Load the Vannot library dynamically
function loadVannotLibrary() {
  return new Promise((resolve, reject) => {
    // Check if already loaded
    if (window.Vannot) {
      console.log('Vannot library already loaded');
      resolve();
      return;
    }

    console.log('Loading Vannot library...');
    
    // Load the CSS
    const cssLink = document.createElement('link');
    cssLink.rel = 'stylesheet';
    cssLink.href = 'https://cdn.jsdelivr.net/gh/xyonix/vannot@master/dist/styles.css';
    document.head.appendChild(cssLink);

    // Load the JS
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/gh/xyonix/vannot@master/dist/app.js';
    script.onload = () => {
      console.log('Vannot script loaded successfully');
      // Give it a moment to initialize
      setTimeout(() => {
        if (window.Vannot) {
          console.log('Vannot global object is available');
          resolve();
        } else {
          console.error('Vannot global object not available after script load');
          reject(new Error('Vannot global object not available after script load'));
        }
      }, 500);
    };
    script.onerror = (error) => {
      console.error('Failed to load Vannot script:', error);
      reject(new Error('Failed to load Vannot script: ' + error));
    };
    document.head.appendChild(script);
  });
}

// Destroy the Vannot instance
function destroyVannot() {
  if (vannotInstance) {
    vannotInstance.destroy();
    vannotInstance = null;
    videoElement = null;
    isDrawingEnabled = false;
    
    // Notify Flutter
    if (window.flutterVannotBridge) {
      window.flutterVannotBridge.postMessage(JSON.stringify({
        type: 'destroyed'
      }));
    }
    return true;
  }
  return false;
}

// Get current annotations
function getAnnotations() {
  if (vannotInstance) {
    try {
      const data = vannotInstance.save();
      return JSON.stringify(data);
    } catch (e) {
      console.error('Error getting annotations:', e);
      return null;
    }
  }
  return null;
}

// Toggle drawing mode
function toggleDrawMode(enable) {
  if (vannotInstance) {
    isDrawingEnabled = enable;
    
    if (enable) {
      // Pause the video when entering draw mode
      pauseVideo();
      vannotInstance.setTool('draw');
      
      // Find and update the draw button
      const drawButton = document.getElementById('vannot-draw-button');
      const selectButton = document.getElementById('vannot-select-button');
      if (drawButton && selectButton) {
        drawButton.style.backgroundColor = 'rgba(0, 123, 255, 0.5)';
        selectButton.style.backgroundColor = 'transparent';
      }
    } else {
      vannotInstance.setTool('select');
      
      // Find and update the select button
      const drawButton = document.getElementById('vannot-draw-button');
      const selectButton = document.getElementById('vannot-select-button');
      if (drawButton && selectButton) {
        selectButton.style.backgroundColor = 'rgba(0, 123, 255, 0.5)';
        drawButton.style.backgroundColor = 'transparent';
      }
    }
    return true;
  }
  return false;
}

// Pause the video
function pauseVideo() {
  if (videoElement && !videoElement.paused) {
    videoElement.pause();
    
    // Notify Flutter
    if (window.flutterVannotBridge) {
      window.flutterVannotBridge.postMessage(JSON.stringify({
        type: 'paused'
      }));
    }
    return true;
  }
  return false;
}

// Play the video
function playVideo() {
  if (videoElement && videoElement.paused) {
    videoElement.play();
    
    // Notify Flutter
    if (window.flutterVannotBridge) {
      window.flutterVannotBridge.postMessage(JSON.stringify({
        type: 'playing'
      }));
    }
    return true;
  }
  return false;
}

// Set up global access for Flutter
window.vannotBridge = {
  init: initVannot,
  destroy: destroyVannot,
  getAnnotations: getAnnotations,
  toggleDrawMode: toggleDrawMode,
  pauseVideo: pauseVideo,
  playVideo: playVideo
}; 
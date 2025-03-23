# Video Annotation Feature

## Overview
The video annotation feature allows coaches to annotate videos on the Performance Insights page. This feature enables coaches to draw shapes, lines, and markers on videos to highlight important moments, techniques, or areas for improvement, making feedback more visual and effective.

## How to Use

### Accessing the Feature
1. Navigate to the Performance Insights page
2. Select an athlete and match with a video
3. There are two ways to access the annotation feature:
   - Click the pencil icon (✏️) in the top right corner of the video player
   - Enter full screen mode and click the pencil icon that appears in the top right corner

### Drawing Tools
Once in annotation mode, you'll see drawing tools in the top left corner:
- **Draw Tool**: Click the brush icon to start drawing on the video
- **Select Tool**: Click the pointer icon to select and modify existing shapes
- **Save**: Click the save icon to store your annotations in the database
- **Share**: Click the share icon to share annotated videos (coming soon)

### Drawing Techniques
- Click and drag to create shapes
- Use the select tool to modify or delete shapes
- The video will automatically pause when you start drawing
- You can play/pause the video while annotating

### Saving and Sharing Annotations
- Click the save icon (💾) to save your annotations
- Annotations are saved to Firebase and associated with the specific athlete and match
- Saved annotations can be loaded when you return to the same performance

## Technical Implementation

### Components
1. **Vannot Library**: An open-source JavaScript library for video annotation
2. **JavaScript Bridge**: A custom JavaScript file that interfaces between Vannot and Flutter
3. **Flutter Widget**: A custom Flutter widget that embeds the Vannot player
4. **Firebase Integration**: Annotations are saved to Firestore for persistence
5. **Custom UI Controls**: Flutter UI elements for controlling the annotation experience

### Key Features
- **Dual Access Modes**: Access annotation tools directly or through full screen mode
- **Custom Drawing Controls**: Intuitive drawing tools for creating annotations
- **Auto-Pause**: The video automatically pauses when entering drawing mode
- **Persistent Storage**: Annotations are saved to Firebase for future reference

## Troubleshooting

### Common Issues
- **Pencil icon not appearing**: Try refreshing the page or selecting a different video
- **Drawing tools not working**: Make sure you've clicked the draw tool (brush icon) first
- **Video keeps playing while drawing**: Click the pause button before drawing
- **Annotations not saving**: Check your internet connection and try again

### Debug Mode
The annotation feature includes a debug mode that can be enabled by developers to help troubleshoot issues. When debug mode is active, additional information is logged to the console.

## Future Enhancements
- Loading existing annotations when returning to a previously annotated video
- Sharing annotated videos with athletes
- Adding text annotations and comments
- Exporting annotations as a separate file
- Collaborative annotation with multiple coaches 
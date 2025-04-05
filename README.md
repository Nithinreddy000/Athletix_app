####Ignore any Other Readme files this file is the main readme file####

# Performance Analysis Platform - Comprehensive Documentation

## Overview

The Performance Analysis Platform is a comprehensive Flutter application designed to provide performance analysis and management capabilities for athletes, coaches, medical staff, administrators, and organizations. The application offers a multi-role system with specialized dashboards for each user type, providing tailored functionalities and insights.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Technology Stack](#technology-stack)
3. [User Roles](#user-roles)
4. [Dashboards](#dashboards)
   - [Admin Dashboard](#admin-dashboard)
   - [Athlete Dashboard](#athlete-dashboard) 
   - [Coach Dashboard](#coach-dashboard)
   - [Medical Dashboard](#medical-dashboard)
   - [Organisation Dashboard](#organisation-dashboard)
5. [Core Features](#core-features)
6. [Authentication and Authorization](#authentication-and-authorization)
7. [Data Models](#data-models)
8. [Services](#services)
9. [Firebase Integration](#firebase-integration)
10. [Installation and Setup](#installation-and-setup)
11. [Development Guidelines](#development-guidelines)

## System Architecture

The application follows a client-server architecture:

- **Frontend**: Flutter-based mobile/web application with responsive design
- **Backend**: Firebase services (Authentication, Firestore, Storage)
- **Database**: Cloud Firestore (NoSQL database)
- **Storage**: Firebase Storage for media files
- **Video Processing**: Cloudinary and Python Backend integration for video playback and analysis

The application is structured following industry-standard best practices, with a modular approach that separates concerns between data, business logic, and presentation layers.

## Technology Stack

### Frontend
- **Flutter**: Cross-platform UI framework
- **Provider**: State management
- **fl_chart**: Data visualization
- **Python Backend**: Video processing

### Backend
- **Firebase Authentication**: User authentication
- **Cloud Firestore**: NoSQL database storage
- **Firebase Storage**: Media file storage
- **Firebase Functions**: Serverless backend functions
- **Python Yolo and media pipeline**: ML capabilities for pose detection and analysis

### Additional Tools and Libraries
- **Webview Flutter**: Web content integration
- **Image Picker**: Media selection
- **File Picker**: File selection
- **path_provider**: File system access
- **permission_handler**: Permission management
- **ModelViewer**: 3D model integration

## User Roles

The application supports multiple user roles, each with specific permissions and access:

1. **Admin**: System administrators with full access to all features
2. **Athlete**: Individual athletes who can view their performance metrics
3. **Coach**: Team coaches who can analyze athlete performances and plan training
4. **Medical Staff**: Healthcare professionals monitoring athlete health
5. **Organisation**: Organization representatives managing financial aspects

## Dashboards

### Admin Dashboard

The Admin Dashboard provides comprehensive system management capabilities:

#### Core Components:
- **Stats Grid**: Overview of system statistics including user counts and events
- **User Management**: Add, edit, and manage all user accounts
- **Performance Analysis**: System-wide performance metrics
- **Announcements**: Create and manage system-wide announcements
- **Match Management**: Schedule and manage matches

#### Key Features:
- User role assignment and permission management
- System-wide analytics and reporting

### Athlete Dashboard

The Athlete Dashboard provides athletes with personal performance insights:

#### Core Components:
- **Athlete Profile**: Personal information and stats display
- **Performance Insights**: Individual performance metrics and visualizations
- **Injury Records**: Personal injury history and recovery tracking
- **Announcements**: Team and organization announcements

#### Key Features:
- Personal performance tracking
- Health and injury monitoring
- Communication with coaches and medical staff
- Training progress visualization

### Coach Dashboard

The Coach Dashboard provides coaching staff with team management tools:

#### Core Components:
- **Team Overview**: Comprehensive team performance metrics
- **Performance Insights**: Advanced analysis of team and individual performances processed by python backend using Mediapipe and yolo models
- **Training Planner**: Schedule and manage training sessions
- **Injury Updates**: Team health status with 3d model visualization along with gemini analyzed rehabilation plans
- **Announcements**: Team communication platform

#### Key Features:
- Video analysis for technical performance evaluation
- Training schedule management
- Team performance monitoring
- Individual athlete development tracking
- Injury risk management

### Medical Dashboard

The Medical Dashboard provides healthcare professionals with athlete health management tools:

#### Core Components:
- **Medical Overview**: Summary of team health status
- **Recent Medical Records**: Latest medical updates
- **Injury Reports**: Detailed injury tracking with 3d model visualization
- **Rehabilitation**: Recovery program management with gemini analysis(under development)
- **Athlete Records**: Comprehensive medical history

#### Key Features:
- Injury visualization and tracking
- Rehabilitation program management
- Medical report generation
- Team health statistics
- Risk assessment for injury prevention

### Organisation Dashboard

The Organisation Dashboard provides organizational representatives with financial tools:

#### Core Components:
- **Financial Management**: Budget tracking and expense management
- **Budget Analysis**: Financial data visualization and reporting
- **Announcements**: Organizational communication

#### Key Features:
- Financial reporting
- Budget allocation and tracking
- Expense approval workflow
- Financial performance metrics

## Core Features

### Performance Analysis

The application provides comprehensive performance analysis capabilities:

- **Video Analysis**: Upload and analyze training/match videos
- **Pose Detection**: Automatic detection of athlete movements using ML
- **Metrics Calculation**: Automatic calculation of performance metrics
- **Visualization**: Graphical representation of performance data
- **Insights Generation**: AI-powered performance insights

#### Implementation Details:
- Uses Yolo and mediapipe for pose detection
- Processes video frames to extract movement data
- Calculates sport-specific metrics based on movement data
- Fitbit integration for real time data fetching and analysis(Future Development Right now Hardcoded)
- Generates visualizations using fl_chart library

### Injury Management

The application provides comprehensive injury management capabilities:

- **Injury Recording**: Document new injuries with detailed information
- **3D Visualization**: Interactive 3D model for injury location
- **Recovery Tracking**: Monitor recovery progress over time
- **Rehabilitation Plans**: Create and manage rehabilitation programs
- **Communication**: Streamlined communication between medical staff, coaches, and athletes

#### Implementation Details:
- Uses model_viewer_plus for 3D visualization
- Stores injury data in Firestore with real-time updates
- Recovery progress tracking with percent indicators
- AI-assisted injury risk assessment

### Financial Management

The application provides financial management tools for organizations:

- **Budget Allocation**: Assign budgets to different departments/activities
- **Expense Tracking**: Monitor and approve expenses
- **Financial Reporting**: Generate financial reports
- **Budget Analysis**: Analyze spending patterns and optimize resource allocation

#### Implementation Details:
- Real-time financial data syncing with Firestore
- Visualization of financial data using charts
- Approval workflow for expenses
- Budget vs. actual spending comparison

### Team Management

The application provides comprehensive team management capabilities:

- **Athlete Profiles**: Detailed athlete information
- **Performance Monitoring**: Track team and individual performances
- **Training Management**: Schedule and organize training sessions
- **Announcements**: Team-wide announcements

## Authentication and Authorization

The application implements a secure authentication and authorization system:

- **Authentication Methods**: Email/password
- **Role-Based Access Control**: Different permissions for each user role
- **Session Management**: Secure session handling
- **Profile Management**: User profile creation and editing

#### Implementation Details:
- Uses Firebase Authentication for secure user authentication
- Custom claims for role-based access control
- Secure token handling for API requests
- Real-time user status tracking

## Data Models

The application uses the following core data models:

### User
- User profile information
- Authentication details
- Role and permission data
- Team affiliations

### Performance Data
- Athlete performance metrics
- Analysis results
- Video references

### Medical Records
- Injury details
- Treatment plans
- Recovery progress
- Medical history

### Financial Data
- Budget allocations
- Expense records
- Financial reports
- Payment information

### Team Data
- Team structure
- Member relationships
- Performance aggregates
- Team schedules

## Services

The application implements the following core services:

### User Service
- User authentication and authorization
- Profile management
- Role assignment and verification

### Performance Analysis Service
- Video processing and analysis
- Performance metrics calculation
- Data visualization
- Insights generation

### Medical Service
- Injury record management
- Rehabilitation planning
- Medical report generation
- Health status monitoring

### Financial Service
- Budget management
- Expense tracking
- Financial reporting
- Payment processing

### Team Service
- Team management
- Member association
- Communication facilitation
- Schedule coordination

## Firebase Integration

The application leverages Firebase services for backend functionality:

### Authentication
- User sign-up and login
- Session management
- Security rules

### Firestore
- NoSQL database for application data
- Real-time data synchronization
- Complex queries for data analytics

### Storage
- Cloudinary (videos, images)
- Secure access control
- Content delivery

### Functions
- Serverless backend operations
- Scheduled tasks
- Integration with external services

## Installation and Setup

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher
- Firebase project with enabled services:
  - Authentication
  - Firestore
  - Storage
  - Functions

### Installation Steps
1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure Firebase project and add configuration files
4. Run the application with `flutter run`

### Configuration
- Firebase configuration in `firebase_options.dart`
- Environment-specific settings in `config.dart`
- Platform-specific settings in respective platform folders

## Development Guidelines

### Code Structure
- Feature-based organization
- Separation of concerns (models, views, controllers)
- Consistent naming conventions
- Comprehensive documentation

### State Management
- Provider for application state
- StreamBuilder for reactive UI updates
- Local state for component-specific state

### UI/UX Guidelines
- Consistent theming through `constants.dart`
- Responsive design using `responsive.dart`
- Accessibility considerations
- Cross-platform compatibility

### Testing
- Unit tests for business logic
- Widget tests for UI components
- Integration tests for feature workflows
- Firebase emulator suite for backend testing

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

© 2024 Performance Analysis Platform. All rights reserved.

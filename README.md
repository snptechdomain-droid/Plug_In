# Slug N Plug (SnP) Club App 🐌⚡

Welcome to the official **Slug N Plug** collaborative platform! This application serves as the digital hub for our club, empowering members with real-time collaboration tools, event management, and seamless communication.

## 🌟 Availability

The SnP App is designed to be accessible everywhere:
*   **🌐 Web Service**: Use it directly in your browser without installation.
*   **📱 Android APK**: Experience full native performance on your mobile device.

## 🚀 Key Features

### 🤝 Collaboration Suite
*   **Mindmaps**: Visualize ideas with dynamic, color-coded nodes.
*   **Flowcharts**: Design processes and user flows with ease.
*   **Timelines**: Plan projects and track milestones.
*   **Live Updates**: All changes sync in real-time across the team.

### 🏛️ Club Management
*   **Role-Based Access**: Specialized views for Admins, Moderators, and Members.
*   **Attendance Tracking**: QR-based or manual attendance with detailed stats.
*   **Event Hub**: Browse upcoming workshops, hackathons, and meetups.
*   **Polls & Voting**: Democratize decision-making with integrated polling.

### 🎨 Modern Experience
*   **Glassmorphism UI**: A stunning, premium aesthetic.
*   **Dark/Light Mode**: Fully adaptive theming.
*   **Multi-language Support**: English and Tamil localization.

---

## 🛠️ Tech Stack

**Frontend (Mobile & Web)**
*   **Framework**: Flutter 3.x
*   **State Management**: `setState` & Services (Clean Architecture)
*   **Design**: Custom Glassmorphism System

**Backend (API Server)**
*   **Framework**: Spring Boot 3.x (Java 17)
*   **Database**: MongoDB
*   **Communication**: WebSocket (Stomp) & REST API

---

## 🚀 Deployment Guide

### Vercel (Web Hosting)
This project is configured for one-click deployment on Vercel.

1.  **Prerequisite**: Ensure you have the `vercel_build.sh` script and `vercel.json` config in the root.
2.  **Settings**:
    *   **Framework Preset**: Other
    *   **Build Command**: `bash vercel_build.sh`
    *   **Output Directory**: `build/web`
3.  **Deploy**: Connect your Git repository to Vercel and push.

### Android Build
To generate the APK for distribution:

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## 📦 Local Development

1.  **Clone the Repo**:
    ```bash
    git clone https://github.com/your-org/snp-app.git
    cd snp-app
    ```

2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run**:
    ```bash
    flutter run
    ```

---

## 🤝 Contributing
We welcome contributions from the community! Please read our `CONTRIBUTING.md` (if available) or simply fork the repo and open a Pull Request.

---
© 2025 Slug N Plug Club

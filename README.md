# Slug N Plug (SnP) Club App 🐌⚡

A modern, cross-platform mobile application for the **Slug N Plug** club, built with **Flutter** (Frontend) and **Spring Boot** (Backend) with **MongoDB**.

## 🚀 Features

*   **Role-Based Access Control**: Admins, Moderators, Event Coordinators, and Members.
*   **Attendance Tracking**: Detailed session history, stats, and manual marking.
*   **Event Management**: Create, edit, and view club events.
*   **Collaboration Tools**: Real-time mindmaps, flowcharts, and whiteboards.
*   **modern UI**: Glassmorphism design, dark/light mode, and smooth animations.

## 🛠️ Tech Stack

### Frontend (User App)
*   **Framework**: Flutter (Dart)
*   **State Management**: `setState` (Local) + Services
*   **Design**: Custom Glassmorphism Theme

### Backend (Server)
*   **Framework**: Spring Boot (Java)
*   **Database**: MongoDB
*   **Security**: Spring Security + JWT (Stateless)
*   **Build Tool**: Maven

## 📦 Installation & Setup

### Prerequisites
*   Flutter SDK (3.x+)
*   Java JDK (17+)
*   MongoDB (Local or Atlas)

### 1. Backend Setup
```bash
cd backend
# Configure your MongoDB URI in src/main/resources/application.properties if needed
mvn spring-boot:run
```
The server will start on `http://localhost:8080`.

### 2. Frontend Setup
```bash
# In the root 'app' directory
flutter pub get
flutter run
```

## 📱 Screenshots

*(Add your screenshots here)*

## 🤝 Contribution

1.  Fork the repository
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

---
© 2025 Slug N Plug

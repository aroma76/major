# ADTU Collab: Academic Workspace & Chat Portal

![ADTU Collab](https://major-three-tau.vercel.app/icons/Icon-192.png)

A full-fledged, real-time academic collaboration platform built for Assam down town University (AdtU). This platform serves as a "Jira for Students," providing real-time chat, file sharing, assignments, and an academic calendar — securely organized into subjects and batches.

## 🚀 Live Links

- **Frontend (Web App):** [https://major-three-tau.vercel.app](https://major-three-tau.vercel.app)
- **Backend (API Base URL):** [https://major-gin9.onrender.com](https://major-gin9.onrender.com)
- **API Health Check:** [https://major-gin9.onrender.com/api/health](https://major-gin9.onrender.com/api/health)

## ✨ Core Features

*   **Real-Time Class Chat:** Built with Socket.io. Features threaded replies, typing indicators, and seamless file attachments.
*   **Performance & Offline Support:** Cursor-based pagination handles thousands of messages smoothly, and an aggressive offline caching system loads chats instantly.
*   **Security First:** JWT authentication, Express Rate Limiting (Brute-force protection), Helmet HTTP headers, and strict MIME-type file parsing to block malware uploads.
*   **Academic Workflows:** 
    *   File sharing (PDFs, Images, Docs) backed by Cloudinary.
    *   Assignments and Submission tracking.
    *   Academic Calendar displaying university events, exams, and holidays.
*   **Role-Based Access Control:** Distinct roles and privileges for Students, Faculty (Teachers), and Admins.

## 🛠 Tech Stack

**Frontend (Client)**
- **Framework:** Flutter Web (Dart)
- **State Management:** Riverpod (AsyncNotifier & Family Providers)
- **Storage:** SharedPreferences (Offline Cache)
- **Networking:** Dio & Socket.io-client
- **UI:** Custom modern Google Fonts (Outfit) & Feather Icons

**Backend (Server)**
- **Runtime:** Node.js + Express.js
- **Database:** PostgreSQL (Neon)
- **Real-Time:** Socket.io
- **Storage Engine:** Cloudinary Storage (Multer middleware)
- **Security:** Helmet, express-rate-limit, jsonwebtoken, file-type validation.

## 💻 Local Development

Before you begin, ensure you have Node.js, Flutter SDK, and PostgreSQL installed.

### 1. Backend Setup
```bash
cd backend

# Install dependencies
npm install

# Setup your environment variables
# Create a .env file based on .env.example with your DB & Cloudinary keys

# Run development server
npm run dev
```

### 2. Frontend Setup
```bash
cd frontend

# Get Flutter packages
flutter pub get

# To test locally, open lib/core/config/app_config.dart
# and set `baseUrl` to 'http://localhost:5000' (if running backend locally)

# Run the Flutter App
flutter run -d chrome
```

## 🔐 Default Credentials Setup
*For new students, the default password is their Date of Birth in `YYYY-MM-DD` format.*

---
*Developed for Assam down town University.*
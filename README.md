# ADTU Collab — Academic Workspace & Chat Portal

![ADTU Collab](https://major-three-tau.vercel.app/icons/Icon-192.png)

> A full-stack, real-time academic collaboration platform built for **Assam down town University (AdtU)**. Designed as a "Jira for Students" — providing real-time class chat, file sharing, assignment tracking, Kanban boards, and an academic calendar, all organized by subject and batch with role-based access control.

---

## 🚀 Live Links

| Service | URL |
|---------|-----|
| **Web App (Frontend)** | [https://major-three-tau.vercel.app](https://major-three-tau.vercel.app) |
| **API Server (Backend)** | [https://major-gin9.onrender.com](https://major-gin9.onrender.com) |
| **API Health Check** | [https://major-gin9.onrender.com/api/health](https://major-gin9.onrender.com/api/health) |

> ⚠️ **Note:** The backend is hosted on Render's free tier. If it hasn't been used for 15 minutes it may take **20–30 seconds** to wake up on the first request. Subsequent requests are fast.

---

## ✨ Core Features

### 💬 Real-Time Class Chat
- Built with **Socket.io** — messages appear instantly for all users in the same subject room
- **Threaded replies** — reply to specific messages with quoted context
- **Typing indicators** — live "User is typing..." feedback
- **File attachments** — send PDFs, images, and Word docs directly in chat
- **Pinned messages** — faculty can pin important messages for the class
- **Cursor-based pagination** — loads thousands of messages smoothly without lag

### 📋 Academic Workflows
- **Assignments** — faculty creates with due dates and max marks; students submit files; faculty grades with feedback
- **Notes** — faculty uploads lecture PDFs and documents; students download anytime
- **File Sharing** — shared course materials per subject
- **Announcements** — faculty posts, all enrolled students notified instantly
- **Academic Calendar** — university events, exam schedules, holidays color-coded by type

### 📊 Kanban Project Boards
- Create projects per subject with drag-and-drop task management
- Task statuses: **To Do → In Progress → Done**
- Assign tasks to team members

### 🔔 Notifications
- Real-time notification push via Socket.io
- Unread count badge on notification bell
- Mark individual or all notifications as read

### 🔐 Security
- **JWT authentication** — 7-day signed tokens, secure session restore
- **bcrypt** password hashing
- **Helmet** HTTP headers — XSS, MIME sniffing, clickjacking protection
- **Express Rate Limiting** — brute-force protection on login
- **MIME-type byte validation** — blocks malware disguised as documents

### ⚡ Performance
- **Offline caching** — chat history and session cached in SharedPreferences
- **IndexedStack navigation** — instant tab switching, no refetching
- **Parallel API fetching** — all subjects fetched simultaneously
- **Riverpod keepAlive** — data persists across tab switches

---

## 👥 Role-Based Access Control

| Feature | Student | Faculty | Admin |
|---------|---------|---------|-------|
| View chat, notes, files | ✅ | ✅ | ✅ |
| Submit assignments | ✅ | ❌ | ❌ |
| Create assignments & announcements | ❌ | ✅ | ✅ |
| Pin/unpin chat messages | ❌ | ✅ | ✅ |
| Grade submissions | ❌ | ✅ | ✅ |
| Upload lecture notes | ❌ | ✅ | ✅ |
| Manage academic events | ❌ | ❌ | ✅ |
| Full platform access | ❌ | ❌ | ✅ |

---

## 🛠 Tech Stack

### Frontend
| Technology | Purpose |
|-----------|---------|
| Flutter Web (Dart) | Cross-platform UI framework |
| Riverpod v3 (AsyncNotifier) | Reactive state management |
| Dio | HTTP client with JWT interceptors |
| Socket.io-client | Real-time WebSocket connection |
| SharedPreferences | Offline token & message cache |
| Google Fonts — Outfit | Modern typography |

### Backend
| Technology | Purpose |
|-----------|---------|
| Node.js + Express.js | REST API server |
| Socket.io | WebSocket real-time engine |
| PostgreSQL (Neon) | Cloud relational database |
| Cloudinary + Multer | Cloud file storage & upload handling |
| jsonwebtoken + bcrypt | Auth & password security |
| Helmet + express-rate-limit | HTTP security hardening |
| file-type | MIME-byte validation for uploads |

### Infrastructure
| Service | Hosts |
|---------|-------|
| Vercel | Flutter Web frontend (global CDN) |
| Render | Node.js backend API |
| Neon | Serverless PostgreSQL database |
| Cloudinary | File & media CDN |

---

## 🏗 Architecture

```
Flutter Web (Vercel CDN)
       │
       ├── REST API (Dio) ──────────────► Express.js (Render)
       │                                        │
       └── WebSocket (Socket.io) ───────────────┤
                                                │
                                    ┌───────────┴───────────┐
                               PostgreSQL              Cloudinary
                                (Neon)               (Files CDN)
```

---

## 💻 Local Development

### Prerequisites
- Node.js v18+
- Flutter SDK
- A PostgreSQL database (local or Neon/Supabase cloud)
- Cloudinary account (free tier)

### 1. Backend Setup
```bash
cd backend

# Install dependencies
npm install

# Copy and fill in environment variables
cp .env.example .env

# Seed the database (creates all tables + mock data)
node seed.js

# Start development server
npm run dev
# → http://localhost:5000
```

### 2. Frontend Setup
```bash
cd frontend

# Get Flutter packages
flutter pub get

# To test locally, open lib/core/config/app_config.dart
# and set baseUrl to 'http://localhost:5000'

# Run in Chrome
flutter run -d chrome
# → http://localhost:9090
```

---

## 🔐 Test Accounts

After running `node seed.js`:

| Role | Login Portal | Credential | Password |
|------|-------------|-----------|---------|
| **Admin** | `/faculty-login` | `admin@adtu.in` | `2004-05-15` |
| **Faculty** | `/faculty-login` | `manoj.sarma.FoCT1@adtu.in` | `2004-05-15` |
| **Student** | `/login` | `ADTU/2024/BTECH-CSE/001` | `2004-05-15` |

> 💡 Default password for all students is their **Date of Birth in `YYYY-MM-DD` format.**

---

## 📁 Project Structure

```
major-project/
├── backend/                   # Express.js + Socket.io server
│   ├── config/                # Database config & schema
│   ├── controllers/           # Business logic (11 modules)
│   ├── middleware/            # auth.js, upload.js (Multer + Cloudinary)
│   ├── routes/                # Express API routing (10 modules)
│   ├── socket/                # Socket.io event handlers
│   ├── server.js              # Main entry point
│   └── seed.js                # Database seeder
│
├── frontend/                  # Flutter Web application
│   └── lib/
│       ├── core/
│       │   ├── config/        # App config (API URL)
│       │   ├── services/      # ApiService, AuthService, StorageService
│       │   └── theme/         # Colors, typography
│       └── features/
│           ├── auth/          # Login screen + auth provider
│           └── dashboard/
│               ├── data/
│               │   ├── models/       # Dart model classes
│               │   └── repositories/ # Data access layer
│               └── presentation/
│                   ├── screens/      # Main screens
│                   ├── providers/    # Riverpod state providers
│                   └── widgets/      # Reusable UI components
│
└── docs/                      # Setup, API, and deployment guides
```

---

## 📖 Documentation

| Doc | Description |
|-----|-------------|
| [SETUP.md](docs/SETUP.md) | Full local setup guide |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Cloud deployment guide |
| [API.md](docs/API.md) | REST API & Socket.io reference |

---

*Developed for Assam down town University · April 2026*
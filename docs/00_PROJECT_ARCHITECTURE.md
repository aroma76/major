# 🏗️ EduSync — Project Architecture

## 📌 What Is This Project?

**EduSync** is a **full-stack academic collaboration platform** built for Assam Down Town University (ADTU). Think of it as a **Google Classroom + Discord hybrid** designed specifically for university use. It allows:

- Students to view subjects, submit assignments, chat, and manage projects.
- Faculty to post announcements, create assignments, grade submissions, and monitor student activity.
- Admins to manage channels, enrolments, and academic events.

---

## 🗺️ High-Level Architecture Diagram

```
┌──────────────────────────────────────────────────────┐
│            FRONTEND (Flutter Web / Mobile)           │
│  ┌─────────────┐  ┌────────────┐  ┌───────────────┐  │
│  │  Auth Layer  │  │  Dashboard │  │  Core Services│  │
│  │  (Riverpod)  │  │  (Screens, │  │  (API, Socket,│  │
│  │             │  │  Widgets)  │  │  Storage)     │  │
│  └──────┬──────┘  └─────┬──────┘  └───────┬───────┘  │
│         └───────────────┼─────────────────┘           │
│                         │ HTTP/WebSocket               │
└─────────────────────────┼────────────────────────────┘
                          │
          ┌───────────────▼──────────────────┐
          │     BACKEND (Node.js + Express)  │
          │                                  │
          │  ┌────────┐   ┌───────────────┐  │
          │  │ Routes │──▶│  Controllers  │  │
          │  └────────┘   └──────┬────────┘  │
          │  ┌────────────────────────────┐  │
          │  │  Middleware (JWT, Upload,  │  │
          │  │  Rate Limit, Helmet, CORS) │  │
          │  └────────────────────────────┘  │
          │  ┌──────────────────────────┐    │
          │  │  Socket.IO Server        │    │
          │  │  (Real-time Events)      │    │
          │  └──────────────────────────┘    │
          └──────────┬───────────┬───────────┘
                     │           │
          ┌──────────▼─┐   ┌─────▼──────────┐
          │ PostgreSQL  │   │ Supabase       │
          │ (Neon DB)   │   │ (File Storage) │
          │ All data    │   │ Uploaded files │
          └────────────┘   └────────────────┘
```

---

## 🧱 Technology Stack

### Frontend
| Technology | Purpose |
|---|---|
| **Flutter** | Cross-platform UI framework (Web + Android + iOS) |
| **Dart** | Programming language |
| **Riverpod** | State management library |
| **Dio** | HTTP client (replaces `http` package) |
| **socket_io_client** | WebSocket client for real-time messaging |
| **flutter_secure_storage** | Secure JWT token storage (mobile) |
| **shared_preferences** | JWT token storage (web) |
| **google_fonts** | Outfit font for UI typography |

### Backend
| Technology | Purpose |
|---|---|
| **Node.js** | JavaScript runtime |
| **Express.js** | Web framework / HTTP server |
| **Socket.IO** | WebSocket server for real-time features |
| **PostgreSQL (pg)** | Relational database via connection pool |
| **Supabase** | Cloud Postgres host + file storage service |
| **bcryptjs** | Password hashing |
| **jsonwebtoken (JWT)** | Stateless authentication tokens |
| **multer** | File upload parsing |
| **helmet** | HTTP security headers |
| **cors** | Cross-Origin Resource Sharing |
| **compression** | Gzip compression for responses |
| **express-rate-limit** | IP-based rate limiting |
| **dotenv** | Environment variable loading |

---

## 📁 Folder Structure

```
major project/
├── README.md
├── backend/
│   ├── server.js               ← App entry point
│   ├── package.json            ← Node dependencies
│   ├── .env / .env.example     ← Environment config
│   ├── config/
│   │   ├── db.js               ← PostgreSQL pool config
│   │   ├── supabase.js         ← Supabase client + bucket setup
│   │   ├── schema.sql          ← Full DB schema
│   │   ├── migration.sql       ← Projects + assignments migration
│   │   ├── rls_security_migration.sql ← Row Level Security policies
│   │   └── academic_events_migration.sql
│   ├── middleware/
│   │   ├── auth.js             ← JWT protect() + authorize() guards
│   │   ├── errorHandler.js     ← Global error response formatter
│   │   └── upload.js           ← Multer + Supabase Storage engine
│   ├── controllers/
│   │   ├── authController.js
│   │   ├── channelController.js
│   │   ├── messageController.js
│   │   ├── assignmentController.js
│   │   ├── submissionController.js
│   │   ├── announcementController.js
│   │   ├── notificationController.js
│   │   ├── notesController.js
│   │   ├── enrollmentController.js
│   │   ├── projectController.js
│   │   ├── academicEventController.js
│   │   └── teacherController.js
│   ├── routes/
│   │   ├── authRoutes.js
│   │   ├── subjectRoutes.js (channel routes)
│   │   ├── messageRoutes.js
│   │   ├── assignmentRoutes.js
│   │   ├── announcementRoutes.js
│   │   ├── notificationRoutes.js
│   │   ├── actualNotesRoutes.js
│   │   ├── projectRoutes.js
│   │   ├── academicEventRoutes.js
│   │   ├── enrollmentRoutes.js
│   │   ├── teacherRoutes.js
│   │   └── downloadRoutes.js
│   └── socket/
│       └── socketHandler.js    ← WebSocket event handlers
└── frontend/
    ├── pubspec.yaml            ← Flutter dependencies
    └── lib/
        ├── main.dart           ← Flutter app entry point
        ├── core/
        │   ├── config/app_config.dart    ← API base URL config
        │   ├── services/
        │   │   ├── api_service.dart      ← Dio HTTP client (singleton)
        │   │   ├── auth_service.dart     ← Login/logout session logic
        │   │   ├── socket_service.dart   ← Socket.IO client (singleton)
        │   │   └── storage_service.dart  ← Cross-platform token storage
        │   ├── theme/app_colors.dart     ← Design system + theme providers
        │   └── utils/responsive.dart    ← Mobile/desktop breakpoint logic
        └── features/
            ├── auth/
            │   ├── auth_provider.dart    ← Auth state (Riverpod Notifier)
            │   └── login_screen.dart     ← Login/signup UI
            └── dashboard/
                ├── data/
                │   ├── models/           ← Dart model classes
                │   └── repositories/    ← Data access layer
                └── presentation/
                    ├── providers/        ← Riverpod state providers
                    ├── screens/          ← Full screen widgets
                    └── widgets/          ← Reusable UI components
```

---

## 🔐 Authentication Flow

```
User enters credentials (Roll Number / Email + Password)
         │
         ▼
LoginScreen (Flutter) calls AuthService.login()
         │
         ▼
ApiService sends POST /api/auth/login to backend
         │
         ▼
authController.login() verifies identity:
  1. Look up user by email or roll_number
  2. bcrypt.compare(password, stored_hash)
  3. Generate JWT: { id, role, name, email }
  4. Return: { token, user }
         │
         ▼
AuthService saves token to StorageService
(FlutterSecureStorage on mobile, SharedPreferences on Web)
         │
         ▼
AuthNotifier sets state = authenticated
         │
         ▼
_AuthGate redirects to MainDashboardScreen
SocketService.connect() called — WebSocket connects with JWT
```

---

## 🔄 Request-Response Lifecycle (REST API)

```
Flutter Widget
  │ calls ApiService.dio.get('/channels')
  │
  ▼
Dio Interceptor adds Bearer token header
  │
  ▼
HTTP Request → backend server.js
  │
  ▼
CORS check (allowedOrigins list)
  │
  ▼
Rate Limiter (200 req / 15 min per IP)
  │
  ▼
Router matches: app.use('/api/channels', channelRoutes)
  │
  ▼
Middleware: protect() verifies JWT → sets req.user
  │
  ▼
Middleware: authorize('admin') checks role (if needed)
  │
  ▼
Controller function runs business logic + DB query
  │
  ▼
JSON Response { success: true, data: [...] }
  │
  ▼
Dio returns Response to Flutter
  │
  ▼
Riverpod provider updates state
  │
  ▼
Flutter widget rebuilds with new data
```

---

## ⚡ Real-Time Architecture (Socket.IO)

```
On Login:
  Flutter ──[WebSocket connect]──▶ Socket.IO Server
         auth token in handshake.auth.token

When user opens a channel (Messages view):
  Flutter ──[channel:join event]──▶ socket joins room "channel_42"

When user types a message:
  Option A (Text): Flutter ──[message:send]──▶ socketHandler.js
                   server saves to DB + emits message:new to room
  Option B (File): Flutter ──[REST POST + file]──▶ messageController.js
                   file uploaded to Supabase Storage
                   saved to DB + _io.to(room).emit('message:new', msg)

All users in room "channel_42" receive message:new event
  ──▶ MessagesNotifier.append(msg) updates local state
  ──▶ Flutter ListView rebuilds with new message
```

---

## 🗃️ Database Architecture Summary

The database has **13 tables** organized in a hierarchy:

```
faculties → programmes → batches → channels
                                      │
                          ┌───────────┼────────────┐
                       messages   assignments   notes
                                      │
                          assignment_submissions
                                      │
                               notifications

users (links to programmes)
enrollments (user ↔ channel M2M)

projects → project_members (user ↔ project M2M)
        └─ project_tasks

academic_events (standalone)
announcements (linked to channels)
```

---

## 🛡️ Security Architecture

| Layer | Mechanism |
|---|---|
| **Transport** | HTTPS in production (Render.com) |
| **CORS** | Strict origin whitelist, blocks unknown origins |
| **Rate Limiting** | Global: 200/15min; Login: 10/15min |
| **Authentication** | JWT RS256 signed, role embedded in token |
| **Authorization** | Role-based guards (student, faculty, admin) |
| **Passwords** | bcrypt cost-10 hash, strong policy enforced |
| **File Uploads** | MIME type filtering, 50MB limit, Supabase Storage |
| **HTTP Headers** | Helmet.js (CSP, HSTS, XSS protection, etc.) |
| **DB Access** | RLS on all Supabase tables (blocks direct API bypass) |
| **Input Validation** | Length checks, parameterized queries (no SQL injection) |
| **Token Storage** | Secure enclave on mobile, localStorage on web |

---

## 🚀 Deployment

| Component | Platform |
|---|---|
| **Backend** | Render.com (Node.js web service) |
| **Frontend** | Vercel (Flutter Web build) |
| **Database** | Neon.tech (Serverless PostgreSQL) |
| **File Storage** | Supabase Storage (S3-compatible) |

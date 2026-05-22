# ADTU Collab — Academic Workspace & Collaboration Portal

<div align="center">

![ADTU Collab Banner](https://major-three-tau.vercel.app/icons/Icon-192.png)

**A real-time, Jira-inspired academic collaboration platform built for Assam down town University (AdtU)**

[![Live App](https://img.shields.io/badge/Live_App-Vercel-black?style=for-the-badge&logo=vercel)](https://major-three-tau.vercel.app)
[![API Server](https://img.shields.io/badge/API_Server-Render-46E3B7?style=for-the-badge&logo=render)](https://major-gin9.onrender.com)
[![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-Express-339933?style=for-the-badge&logo=node.js)](https://nodejs.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Neon-4169E1?style=for-the-badge&logo=postgresql)](https://neon.tech)

</div>

---

## 📖 Overview

**ADTU Collab** (internally named *ADTU StudyHub*) is a full-stack, real-time academic collaboration platform that replaces fragmented tools like WhatsApp groups, Google Classroom, and static portals with a single, structured workspace.

It is designed as a **"Jira for Students"** — every subject has a dedicated channel where chat, assignments, notes, files, and announcements live together. Faculty manage their classes, students track their work via Kanban boards, and the `admin` role protects privileged backend routes — all in one place.

> **Note:** There is no frontend admin dashboard. Administrative setup (seeding faculties, programmes, and batches) is done directly via the Supabase SQL editor. The `admin` role is a backend-only RBAC concept.

> ⚠️ **Cold Start Notice:** The backend is hosted on Render's free tier. If idle for 15+ minutes, the first request may take 20–30 seconds to wake up. Subsequent requests are fast.

---

## 🌐 Live Links

| Service | URL |
|---------|-----|
| **Web App (Frontend)** | [https://major-three-tau.vercel.app](https://major-three-tau.vercel.app) |
| **API Server (Backend)** | [https://major-gin9.onrender.com](https://major-gin9.onrender.com) |
| **API Health Check** | [https://major-gin9.onrender.com/api/health](https://major-gin9.onrender.com/api/health) |

---

## ✨ Core Features

### 💬 Real-Time Class Chat
- Built with **Socket.IO** — messages appear instantly across all users in the same subject room
- **Threaded replies** — quote and reply to specific messages with full context
- **Typing indicators** — live `User is typing...` feedback via Socket.IO events
- **File attachments** — send PDFs, images, and Word docs directly in chat
- **Pinned messages** — faculty can pin critical messages; pinned state is persisted in the database
- **Cursor-based pagination** — loads thousands of chat messages smoothly via `before` cursor query param

### 📋 Academic Workflows
- **Assignments** — faculty creates with due dates and max marks; students submit files; faculty grades with marks and feedback
- **Notes** — faculty uploads lecture PDFs/documents; students download anytime
- **File Sharing** — shared course materials per subject channel
- **Announcements** — faculty/admin posts are instantly broadcast to all enrolled students via Socket.IO
- **Academic Calendar** — university events, exam schedules, and holidays, color-coded by event type

### 📊 Kanban Project Boards
- Create projects per subject with drag-and-drop task cards
- Task statuses: **To Do → In Progress → Done**
- Assign tasks to specific team members within a project

### 🔔 Real-Time Notifications
- Push notifications delivered via Socket.IO on every assignment, announcement, and grading event
- Unread count badge on the notification bell icon
- Mark individual notifications or all as read in one action

### 🔐 Security
- **JWT authentication** — stateless 7-day signed tokens; token verified on every protected request
- **bcrypt** password hashing with salt rounds of `10`
- **Helmet** HTTP headers — CSP, XSS, MIME-sniffing, and clickjacking protection
- **Express Rate Limiting** — 200 requests per IP per 15-minute window (global); 10 login attempts per IP per 15-minute window (brute-force protection on login route)
- **MIME-type file filter** — blocks executable uploads (`.exe`, `.bat`, `.msi`) at the Multer layer
- **Parameterized SQL queries** — all database queries use `$1, $2` placeholders; zero SQL injection risk

### ⚡ Performance
- **Gzip compression** — `compression()` middleware shrinks all JSON responses by ~80%
- **Connection pooling** — `pg.Pool` maintains reusable PostgreSQL connections for concurrent requests
- **B-Tree indexes** — on `channel_id`, `user_id`, `assignment_id` for sub-millisecond lookups
- **Riverpod `keepAlive`** — Flutter state persists across tab switches; no redundant refetching
- **Parallel API fetching** — all subject channels are fetched simultaneously using `Future.wait()`

---

## 👥 Role-Based Access Control (RBAC)

| Feature | Student | Class Rep | Faculty | Admin |
|---------|---------|-----------|---------|-------|
| View chat, notes, files | ✅ | ✅ | ✅ | ✅ |
| Submit assignments | ✅ | ✅ | ❌ | ❌ |
| Create assignments & announcements | ❌ | ❌ | ✅ | ✅ |
| Pin/unpin chat messages | ❌ | ❌ | ✅ | ✅ |
| Grade student submissions | ❌ | ❌ | ✅ | ✅ |
| Upload lecture notes | ❌ | ❌ | ✅ | ✅ |
| Manage academic calendar events | ❌ | ❌ | ❌ | ✅ |
| Manage channels, batches, programmes | ❌ | ❌ | ❌ | ✅ |
| Full platform access | ❌ | ❌ | ❌ | ✅ |

> Role is set server-side at registration. Sending `{ "role": "admin" }` in the request body is silently ignored — the backend always defaults to `"student"`.

---

## 🛠 Tech Stack

### Frontend
| Technology | Version | Purpose |
|-----------|---------|---------|
| Flutter (Dart) | `>=3.0.0` | Cross-platform UI — compiles to Web, Android, iOS, Desktop |
| flutter_riverpod | `^3.3.1` | Compile-safe reactive state management (`AsyncNotifier`) |
| go_router | `^14.3.0` | Installed for future deep-link routing; current navigation uses `_AuthGate` + `_LazyIndexedStack` pattern |
| Dio | `^5.4.0` | HTTP client with JWT interceptors and 401 auto-redirect |
| socket_io_client | `^2.0.3+1` | Real-time WebSocket connection to Socket.IO server |
| flutter_secure_storage | `^9.0.0` | Encrypted on-device token storage |
| shared_preferences | `^2.2.3` | Offline message cache and session persistence |
| file_picker | `^8.1.7` | Native file selection for uploads |
| table_calendar | `^3.1.2` | Interactive academic event calendar |
| animations | `^2.1.2` | Material motion transitions |
| glassmorphism | `^3.0.0` | Frosted glass UI effects |
| google_fonts | `^8.0.2` | Outfit typeface for modern typography |

### Backend
| Technology | Version | Purpose |
|-----------|---------|---------|
| Node.js + Express.js | `^4.18.3` | REST API server — stateless, event-driven I/O |
| Socket.IO | `^4.7.5` | Bi-directional real-time WebSocket engine |
| pg (node-postgres) | `^8.11.3` | PostgreSQL client with connection pooling |
| @supabase/supabase-js | `^2.105.4` | Supabase Storage SDK for file streaming |
| jsonwebtoken | `^9.0.2` | JWT signing and verification (HMAC SHA-256) |
| bcryptjs | `^2.4.3` | Password hashing with adaptive cost factor |
| multer | `^1.4.5-lts.1` | Multipart form-data parsing for file uploads |
| helmet | `^8.1.0` | HTTP security headers (CSP, X-Frame, X-Content-Type) |
| express-rate-limit | `^8.3.2` | Per-IP rate limiting (200 req / 15 min) |
| compression | `^1.8.1` | Gzip response compression |
| express-async-errors | `^3.1.1` | Async exception routing to global error handler |
| express-validator | `^7.3.2` | Request body validation |
| file-type | `^16.5.4` | MIME-byte validation to block disguised malware |
| dotenv | `^16.4.5` | Environment variable loading from `.env` |

### Infrastructure
| Service | Purpose |
|---------|---------|
| **Vercel** | Flutter Web frontend — global CDN edge deployment, auto CI/CD from GitHub |
| **Render** | Node.js backend API — free tier with auto-deploy from `main` branch |
| **Neon** | Serverless PostgreSQL — compute scales to zero when idle, storage is always-on |
| **Supabase Storage** | CDN-backed file bucket for assignment submissions, notes, and chat attachments |

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                               │
│                                                                     │
│         Flutter Web (Vercel CDN)  ·  Flutter Android/iOS           │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                  HTTPS / WSS (WebSockets)
                           │
┌──────────────────────────▼──────────────────────────────────────────┐
│                      BACKEND (Render)                               │
│                                                                     │
│  ┌─────────────────────┐   ┌──────────────────────────────────┐    │
│  │  Express REST API   │   │       Socket.IO Server           │    │
│  │  12 Route Groups    │   │  (chat, typing, notifications)   │    │
│  └──────────┬──────────┘   └─────────────────┬────────────────┘    │
│             │                                 │                     │
│  ┌──────────▼─────────────────────────────────▼────────────────┐   │
│  │  Middleware Chain:                                           │   │
│  │  compression → cors → helmet → rate-limit → auth (JWT)      │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
           ┌───────────────┴───────────────┐
           │                               │
┌──────────▼──────────┐         ┌──────────▼──────────┐
│  Neon PostgreSQL    │         │   Supabase Storage  │
│  (Relational DB)    │         │   (CDN File Bucket) │
│  13 tables, ACID    │         │   stream upload     │
└─────────────────────┘         └─────────────────────┘
```

---

## 🗄 Database Schema

The database follows a strict hierarchical structure: **Faculty → Programme → Batch → Channel**

```
faculties (id, name, color_code)
    └── programmes (id, faculty_id, name, code, duration_semesters)
            └── batches (id, programme_id, year)
                    └── channels (id, batch_id, semester_number, subject_name, teacher_id)
                            ├── messages (id, channel_id, sender_id, content, file_url, is_pinned)
                            ├── notes (id, channel_id, created_by, title, content)
                            ├── files (id, channel_id, uploaded_by, file_name, file_url)
                            ├── assignments (id, channel_id, created_by, title, due_date, max_marks)
                            │       └── assignment_submissions (id, assignment_id, student_id, file_url, status, marks, feedback)
                            └── announcements (id, channel_id, user_id, title, content, is_important)

users (id, name, email, roll_number, dob, password, role, programme_id, current_semester)
    ├── enrollments (user_id, channel_id)   -- composite PK prevents double enrollment
    └── notifications (id, user_id, type, title, message, is_read)
```

**Performance Indexes:**
```sql
CREATE INDEX idx_messages_channel      ON messages(channel_id);
CREATE INDEX idx_assignments_channel   ON assignments(channel_id);
CREATE INDEX idx_submissions_assignment ON assignment_submissions(assignment_id);
CREATE INDEX idx_enrollments_user      ON enrollments(user_id);
CREATE INDEX idx_announcements_channel ON announcements(channel_id);
```

---

## 🔌 API Reference

All routes are prefixed with `/api`. Protected routes require `Authorization: Bearer <token>`.

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/auth/register` | Open | Register a new student account |
| `POST` | `/auth/login` | Open | Validate credentials → return JWT |
| `GET`  | `/auth/me` | User | Get current user profile |
| `GET`  | `/channels` | User | List channels for the logged-in user |
| `POST` | `/channels` | Admin | Create a new subject channel |
| `GET`  | `/channels/:id/messages` | User | Fetch paginated chat messages (cursor-based) |
| `POST` | `/channels/:id/messages` | User | Post a new message (with optional file) |
| `GET`  | `/channels/:id/assignments` | User | List assignments for a channel |
| `POST` | `/channels/:id/assignments` | Faculty/Admin | Create a new assignment |
| `POST` | `/channels/:id/assignments/:aid/submissions` | Student | Submit assignment file |
| `PATCH`| `/channels/:id/assignments/:aid/submissions/:sid` | Faculty/Admin | Grade a submission |
| `GET`  | `/channels/:id/announcements` | User | List channel announcements |
| `POST` | `/channels/:id/announcements` | Faculty/Admin | Post an announcement |
| `GET`  | `/channels/:id/notes` | User | List lecture notes |
| `POST` | `/channels/:id/notes` | Faculty/Admin | Upload a note |
| `GET`  | `/notifications` | User | Get all notifications |
| `PATCH`| `/notifications/:id/read` | User | Mark notification as read |
| `GET`  | `/projects` | User | List Kanban projects |
| `POST` | `/projects` | User | Create a Kanban project |
| `PATCH`| `/projects/:id/tasks/:tid` | User | Update task status |
| `GET`  | `/academic-events` | User | Fetch calendar events |
| `POST` | `/academic-events` | Admin | Create a calendar event |
| `GET`  | `/teacher/stats` | Faculty/Admin | Teacher stats and submissions overview |
| `GET`  | `/teacher/recent-activity` | Faculty/Admin | Recent assignment and submission activity |
| `GET`  | `/api/health` | Open | API health check |

---

## 🔐 Authentication Flow

```
Client                          Server                         Database
  │                               │                               │
  ├─ POST /api/auth/login ────────▶│                               │
  │  { identifier, password }     │                               │
  │                               ├─ SELECT user WHERE email=$1 ─▶│
  │                               │◀─ user row (hashed password) ─┤
  │                               │                               │
  │                               │  bcrypt.compare(password, hash)
  │                               │  jwt.sign({ id, role, name })
  │                               │                               │
  │◀─ 200 { token, user } ────────┤                               │
  │                               │                               │
  ├═══ WebSocket handshake ═══════▶│  (JWT in auth header)        │
  │◀══ Socket connected ══════════┤                               │
  │                               │                               │
  ├─ GET /api/channels ───────────▶│                               │
  │  Authorization: Bearer <token> │                               │
  │                               │  protect middleware verifies JWT
  │                               ├─ SELECT channels WHERE... ───▶│
  │◀─ 200 { channels[] } ─────────┤                               │
```

---

## 📁 Project Structure

```
major-project/
├── backend/                          # Node.js + Express + Socket.IO server
│   ├── config/
│   │   ├── db.js                     # pg.Pool connection to Neon PostgreSQL
│   │   ├── cloudinary.js             # Cloudinary SDK config
│   │   ├── supabase.js               # Supabase Storage client + ensureBucket()
│   │   ├── schema.sql                # Full PostgreSQL schema (13 tables)
│   │   └── migration.sql             # Incremental schema migrations
│   ├── controllers/
│   │   ├── authController.js         # register, login, getMe
│   │   ├── channelController.js      # CRUD for subject channels
│   │   ├── messageController.js      # chat messages + Socket.IO broadcast
│   │   ├── assignmentController.js   # assignments + grading
│   │   ├── submissionController.js   # file submissions
│   │   ├── announcementController.js # announcements + notifications
│   │   ├── notesController.js        # lecture notes
│   │   ├── notificationController.js # notifications CRUD
│   │   ├── projectController.js      # Kanban projects + tasks
│   │   ├── academicEventController.js# calendar events
│   │   ├── enrollmentController.js   # student-channel enrollment
│   │   └── teacherController.js      # teacher dashboard stats
│   ├── middleware/
│   │   ├── auth.js                   # protect (JWT verify) + authorize (RBAC)
│   │   ├── upload.js                 # Multer + Supabase stream storage engine
│   │   └── errorHandler.js           # Global async error handler
│   ├── routes/                       # 12 Express router files (one per resource)
│   ├── socket/
│   │   └── socketHandler.js          # Socket.IO event handlers (chat, typing, notifications)
│   └── server.js                     # Entry point: middleware chain, routes, Socket.IO init
│
└── frontend/                         # Flutter Web application
    └── lib/
        ├── main.dart                 # App entry, Riverpod ProviderScope, _AuthGate (auth gate routing)
        ├── core/
        │   ├── config/               # app_config.dart — API base URL (prod/dev switch)
        │   ├── services/
        │   │   ├── api_service.dart  # Dio HTTP client with JWT interceptor
        │   │   ├── socket_service.dart # Socket.IO connection manager
        │   │   └── storage_service.dart # FlutterSecureStorage wrapper
        │   └── theme/                # Colors, typography, glassmorphism styles
        └── features/
            ├── auth/                 # LoginScreen, auth_provider (AsyncNotifier)
            └── dashboard/
                ├── data/
                │   ├── models/       # Dart data classes (Channel, Message, Assignment...)
                │   └── repositories/ # Data access layer (API calls → model conversion)
                └── presentation/
                    ├── screens/      # Dashboard, ChatScreen, AssignmentScreen...
                    ├── providers/    # Riverpod providers (channelsProvider, messagesProvider...)
                    └── widgets/      # KanbanCard, MessageBubble, AnnouncementTile...
```

---

## 💻 Local Development

### Prerequisites
- **Node.js** v18+
- **Flutter SDK** v3.0+
- A PostgreSQL database (local or [Neon](https://neon.tech) cloud)
- A [Supabase](https://supabase.com) project with Storage enabled

### 1. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Create environment file
cp .env.example .env
# Fill in DATABASE_URL, JWT_SECRET, SUPABASE_URL, SUPABASE_SERVICE_KEY

# Run database schema
# Connect to your DB and execute: backend/config/schema.sql

# Start development server (with hot reload)
npm run dev
# → http://localhost:5000
# → GET http://localhost:5000/api/health  ✅
```

**Required `.env` variables:**
```env
PORT=5000
NODE_ENV=development
DATABASE_URL=postgresql://...          # Neon or local PostgreSQL connection string
JWT_SECRET=your_super_secret_key
CLIENT_URL=http://localhost:9090

SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhb...
```

### 2. Frontend Setup

```bash
cd frontend

# Install Flutter packages
flutter pub get

# Set API URL to local backend
# Edit: lib/core/config/app_config.dart
# Change baseUrl to 'http://localhost:5000'

# Run in Chrome
flutter run -d chrome
# → http://localhost:9090
```

---

## 🔑 Test Accounts

| Role | Login Portal | Identifier | Password |
|------|-------------|------------|---------|
| **Admin** | `/faculty-login` | `admin@adtu.in` | `2004-05-15` |
| **Faculty** | `/faculty-login` | `manoj.sarma.FoCT1@adtu.in` | `2004-05-15` |
| **Student** | `/login` | `ADTU/2024/BTECH-CSE/001` | `2004-05-15` |

> 💡 Default password for all student accounts is their **Date of Birth in `YYYY-MM-DD` format.**

---

## 🔁 Request Lifecycle

A complete trace of a student opening their subject channel chat:

```
1. Flutter calls GET /api/channels/:id/messages?limit=30
2. Dio attaches Authorization: Bearer <JWT> header
3. Express global rate limiter checks IP (< 200 req/15 min) ✅
4. Helmet sets security headers on the response
5. protect middleware → jwt.verify(token, JWT_SECRET) → extracts { id, role }
6. messageController → pool.query(
       'SELECT m.*, u.name FROM messages m
        JOIN users u ON m.sender_id = u.id
        WHERE m.channel_id = $1
        ORDER BY m.created_at DESC LIMIT $2',
       [channelId, limit]
   )
7. PostgreSQL uses idx_messages_channel B-Tree index → instant lookup ✅
8. Server returns JSON array of messages
9. Flutter Riverpod provider updates → ChatScreen rebuilds with new messages
10. Socket.IO 'message:new' event listener handles any new messages in real-time
```

---

## 🚀 Deployment

| Layer | Platform | Trigger |
|-------|---------|---------|
| Frontend | Vercel | Auto-deploy on push to `main` → `flutter build web` via `build.sh` |
| Backend | Render | Auto-deploy on push to `main` → `node server.js` |
| Database | Neon | Always-on serverless PostgreSQL; no deployment needed |
| Storage | Supabase | `ensureBucket()` runs at server startup to verify the `files` bucket |

```bash
# Frontend build script (build.sh runs on Vercel)
flutter build web --release --web-renderer canvaskit
# Output → build/web/ (served as static files on Vercel CDN)
```

---

## 🔧 Socket.IO Events

| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `channel:join` | Client → Server | `channelId` | Join a subject Socket.IO room |
| `message:new` | Server → Client | `{ message }` | New chat message broadcast |
| `message:pinned` | Server → Client | `{ messageId, isPinned }` | Pin state update |
| `typing:start` | Client → Server | `{ channelId, userName }` | User started typing |
| `typing:stop` | Client → Server | `{ channelId }` | User stopped typing |
| `notification:new` | Server → Client | `{ notification }` | Real-time notification push |
| `announcement:new` | Server → Client | `{ announcement }` | New announcement broadcast |

---

## 🧪 Security Hardening Summary

| Threat | Mitigation |
|--------|------------|
| SQL Injection | Parameterized queries (`$1, $2` placeholders) throughout all controllers |
| XSS | Helmet CSP headers; no `innerHTML` in Flutter (canvas-based renderer) |
| Brute Force Login | `express-rate-limit` — 200 req/IP/15 min; bcrypt cost factor 10 |
| Privilege Escalation | Role hardcoded to `'student'` on register; role checked server-side per route |
| Malware Uploads | Multer `fileFilter` blocks `application/x-msdownload`, `x-bat`, `x-msdos-program` |
| Token Theft | Short-lived JWT (7 days); `401` response triggers client-side logout and token purge |
| Clickjacking | Helmet sets `X-Frame-Options: DENY` |
| CORS | Strict allowlist of origins; regex match for Vercel preview URLs only |

---

## 📈 Scalability Considerations

The current architecture is optimized for a university-scale (~5,000 users). For 50,000+ active users:

| Bottleneck | Solution |
|-----------|---------|
| PostgreSQL connection exhaustion | **PgBouncer** connection proxy / connection pooling |
| Single Socket.IO server | **Redis Pub/Sub adapter** for multi-instance Socket.IO sync |
| High CPU from bcrypt on login | Offload auth to dedicated microservice or use worker threads |
| Cold start on Render free tier | Upgrade to paid tier or use a UptimeRobot cron ping |
| Static file serving | Files already on Supabase CDN — no server disk bottleneck |

---

*Developed for Assam down town University · Major Project · April 2026*
*Stack: Flutter · Node.js · Express · PostgreSQL · Socket.IO · Supabase · Vercel · Render*
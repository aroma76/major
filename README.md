# ADTU Collab — Cloud-Based Academic Collaboration System
### Assam down town University

A full-stack academic collaboration platform that replaces WhatsApp groups with structured, cloud-based subject workspaces.

---

## Features

| Feature | Description |
|---|---|
| 💬 Real-time Chat | Socket.IO powered messaging with file sharing, typing indicators, and pinned messages |
| 📚 Notes Repository | Cloud-stored notes with search, upload, and download |
| 📋 Assignment System | Create, submit, and grade assignments with deadline tracking |
| 📢 Announcements | Faculty posts, auto-notifies all enrolled students |
| 🔔 Notifications | In-app, real-time notifications for assignments, grades, announcements |
| 🔐 Role-Based Access | Student / Faculty / Admin with controlled permissions |
| ☁️ Cloud Storage | All files stored on Cloudinary — no data loss |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 18 + Vite + Tailwind CSS + React Router |
| Backend | Node.js + Express + Socket.IO |
| Database | PostgreSQL (Supabase / Neon) |
| Storage | Cloudinary |
| Auth | JWT |
| Deployment | Vercel (frontend) + Render (backend) |

---

## Project Structure

```
major project/
├── backend/
│   ├── config/         ← db.js, cloudinary.js, schema.sql
│   ├── controllers/    ← auth, subject, enrollment, message, note, assignment, submission, announcement, notification
│   ├── middleware/     ← auth.js, upload.js, errorHandler.js
│   ├── routes/         ← All route files
│   ├── socket/         ← socketHandler.js (real-time)
│   └── server.js       ← Entry point
├── frontend/
│   └── src/
│       ├── components/ ← Layout, Navbar, Sidebar, SubjectCard, Tabs, ChatBubble, AssignmentCard, FileUpload
│       ├── context/    ← AuthContext
│       ├── hooks/      ← useSocket
│       ├── pages/      ← Login, Signup, Dashboard, Subject, Notifications, Profile
│       └── services/   ← api.js (Axios)
└── docs/
    ├── API.md          ← REST + Socket.IO reference
    ├── SETUP.md        ← Local development guide
    ├── DEPLOYMENT.md   ← Vercel + Render + Supabase guide
    └── SEED.sql        ← Sample test data
```

---

## Quick Start

```bash
# 1. Set up the database (see docs/SETUP.md)
# 2. Configure environment variables
cp backend/.env.example backend/.env   # fill in your values

# 3. Install and run
cd backend && npm install && npm run dev
cd frontend && npm install && npm run dev

# 4. Open http://localhost:5173
```

See **[docs/SETUP.md](docs/SETUP.md)** for full setup instructions.
See **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** for production deployment.
See **[docs/API.md](docs/API.md)** for the full API reference.

---

## User Roles

| Role | Permissions |
|---|---|
| **Student** | View subjects, chat, download notes, submit assignments, view announcements |
| **Faculty** | All student permissions + upload notes, create assignments, grade submissions, post announcements |
| **Admin** | All permissions + manage subjects, users, and enrollments |

---

*Built as a Final Year Major Project — Assam down town University, 2026*
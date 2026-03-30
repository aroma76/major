# Local Setup Instructions

## Prerequisites
- Node.js v18+
- PostgreSQL (local or Supabase/Neon cloud)
- Cloudinary account (free tier)

---

## Step 1: Install Dependencies

```bash
cd backend && npm install
cd ../frontend && npm install
```

## Step 2: Configure Backend `.env`

```bash
cp backend/.env.example backend/.env
```

Fill in `backend/.env`:
```
PORT=5000
NODE_ENV=development
DATABASE_URL=postgresql://user:password@localhost:5432/adtu_collab
JWT_SECRET=your_long_random_secret_here
JWT_EXPIRES_IN=7d
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
CLIENT_URL=http://localhost:5173
```

## Step 3: Set Up Database

**Local PostgreSQL / Supabase:**
Whether you are using a local Postgres database or a cloud database like Supabase, your database schema and mock records are generated entirely via our automated seeder.

Ensure your `backend/.env` file has the correct `DATABASE_URL`, then simply run:
```bash
cd backend
node seed.js
```
*This command will completely build your tables (Channels, Messages, Assignments, Notes, Files) and populate them with students, teachers, and mock content.*

## Step 4: Cloudinary Credentials (Optional but Recommended)

Sign up for a free tier at cloudinary.com → Dashboard → copy Cloud Name, API Key, and API Secret into your `.env`. 
*Without Cloudinary keys, the new Chat File Upload and Course Material Upload functionality will fail.*

## Step 5: Run Servers

```bash
# Terminal 1 - Backend Server
cd backend && npm run dev   # → http://localhost:5000

# Terminal 2 - Frontend UI
cd frontend && npm run dev  # → http://localhost:5173
```

## Step 6: Project Structure

```text
major/
├── backend/                  # Express + Socket.IO Server
│   ├── config/               # Database config (db.js, schema.sql)
│   ├── controllers/          # Business logic for assignments, chat, etc.
│   ├── middleware/           # auth.js, upload.js (Multer + Cloudinary)
│   ├── routes/               # Express API routing 
│   ├── socket/               # Chatroom WebSocket handlers
│   ├── server.js             # Main backend entry point
│   └── seed.js               # Cloud database generator
│
├── frontend/                 # React UI + Vite
│   ├── public/               # Static assets
│   ├── src/
│   │   ├── components/       # Reusable UI (Sidebar.jsx, Layout.jsx)
│   │   ├── context/          # Global Auth state
│   │   ├── pages/            # View Tabs (SubjectPage.jsx, DashboardPage.jsx)
│   │   ├── services/         # Axios interceptors (api.js)
│   │   ├── hooks/            # useSocket.js
│   │   └── App.jsx           # Global Router
│
└── docs/                     # Setup, Deployment, & Architecture Guides
```

## Step 7: Test Accounts 

After `node seed.js` succeeds, you can log in to test the multi-portal architecture using these credentials:

| Role                 | Portal Path      | Email / Roll                       | Password     | Dashboard Features |
|----------------------|------------------|------------------------------------|--------------|--------------------|
| **Admin**            | `/faculty-login` | `admin@adtu.in`                   | `2004-05-15` | Full platform access, all files, all announcements |
| **Faculty (Teacher)**| `/faculty-login` | `manoj.sarma.FoCT1@adtu.in`       | `2004-05-15` | Can create assignments, pin chat messages, upload files |
| **Student**          | `/login`         | `ADTU/2024/BTECH-CSE/001`         | `2004-05-15` | Submits assignments, views notes, downloads syllabus |

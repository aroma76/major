# Deployment Guide

## 1. Database — Supabase
1. Create project at supabase.com
2. SQL Editor → paste and run `backend/config/schema.sql`
3. Settings → Database → Connection string (URI) → copy it

## 2. Cloudinary
Sign up at cloudinary.com, get Cloud Name, API Key, API Secret.

## 3. Backend — Render
1. Push to GitHub; connect at render.com → New Web Service
2. Root directory: `backend` | Build: `npm install` | Start: `node server.js`
3. Environment variables:
   ```
   PORT=5000
   NODE_ENV=production
   DATABASE_URL=<Supabase URI>
   JWT_SECRET=<random string>
   JWT_EXPIRES_IN=7d
   CLOUDINARY_CLOUD_NAME=...
   CLOUDINARY_API_KEY=...
   CLOUDINARY_API_SECRET=...
   CLIENT_URL=https://your-frontend.vercel.app
   ```

## 4. Frontend — Vercel
1. vercel.com → New Project → Import repo
2. Root directory: `frontend` | Build: `npm run build` | Output: `dist`
3. Add env var: `VITE_API_URL=https://adtu-backend.onrender.com`
4. In `frontend/src/services/api.js` update baseURL for production:
   ```js
   baseURL: (import.meta.env.VITE_API_URL || '') + '/api'
   ```

## Architecture
```
Browser → Vercel (React) → Render (Express+Socket.IO) → Supabase (PostgreSQL)
                                                       → Cloudinary (Files)
```

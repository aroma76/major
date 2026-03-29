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

**Local PostgreSQL:**
```bash
psql -U postgres -c "CREATE DATABASE adtu_collab;"
psql -U postgres -d adtu_collab -f backend/config/schema.sql
psql -U postgres -d adtu_collab -f docs/SEED.sql   # optional
```

**Supabase:** Paste `schema.sql` content into SQL Editor and run.

## Step 4: Cloudinary Credentials

Sign up free at cloudinary.com → Dashboard → copy Cloud Name, API Key, API Secret.

## Step 5: Run

```bash
# Terminal 1
cd backend && npm run dev   # → http://localhost:5000

# Terminal 2
cd frontend && npm run dev  # → http://localhost:5173
```

## Test Accounts (after SEED.sql)

| Role    | Email           | Password     |
|---------|-----------------|--------------|
| Admin   | admin@adtu.in   | Admin@1234   |
| Faculty | priya@adtu.in   | Faculty@1234 |
| Student | rahul@adtu.in   | Student@1234 |

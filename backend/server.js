require('dotenv').config();
require('express-async-errors');

const express = require('express');
const cors    = require('cors');
const http    = require('http');
const helmet  = require('helmet');
const rateLimit = require('express-rate-limit');
const { Server } = require('socket.io');

const errorHandler = require('./middleware/errorHandler');
const socketHandler = require('./socket/socketHandler');
const { setIO } = require('./controllers/messageController');

const authRoutes         = require('./routes/authRoutes');
const channelRoutes      = require('./routes/subjectRoutes');
const messageRoutes      = require('./routes/messageRoutes');
const fileRoutes         = require('./routes/noteRoutes');
const assignmentRoutes   = require('./routes/assignmentRoutes');
const announcementRoutes = require('./routes/announcementRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const actualNotesRoutes  = require('./routes/actualNotesRoutes');
const projectRoutes           = require('./routes/projectRoutes');
const academicEventRoutes     = require('./routes/academicEventRoutes');

const app = express();
const server = http.createServer(app);

const allowedOrigins = [
  process.env.CLIENT_URL,
  'http://localhost:5173',
  'http://localhost:3000',
  'http://localhost:9090', // Flutter Web dev server
  'https://major-three-tau.vercel.app',  // Flutter Web on Vercel
  /\.vercel\.app$/,        // allow all Vercel preview/branch URLs
  /^http:\/\/localhost:\d+$/,  // allow ALL localhost ports (Flutter picks random ports)
].filter(Boolean);

const corsOptions = {
  origin: (origin, callback) => {
    if (!origin) return callback(null, true); // allow non-browser requests (Postman, health checks)
    const allowed = allowedOrigins.some(o =>
      o instanceof RegExp ? o.test(origin) : o === origin
    );
    if (allowed) callback(null, true);
    else callback(new Error(`CORS blocked: ${origin}`));
  },
  credentials: true,
};

const io = new Server(server, {
  cors: { origin: allowedOrigins, methods: ['GET', 'POST'], credentials: true },
});
socketHandler(io);
setIO(io); // allow REST controllers to broadcast via socket

app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ── Security ──────────────────────────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false })); // secure HTTP headers

// Brute-force protection on login (max 10 attempts per 15 min per IP)
const loginLimiter = rateLimit({
  windowMs : 15 * 60 * 1000,
  max      : 10,
  message  : { success: false, message: 'Too many login attempts. Try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders  : false,
});

app.get('/api/health', (req, res) => res.json({ success: true, message: 'ADTU Collab API is running 🚀' }));

app.use('/api/auth',                       authRoutes);
app.post('/api/auth/login',                loginLimiter); // rate limit only on login
app.use('/api/channels',                   channelRoutes);
app.use('/api/channels/:id/messages',      messageRoutes);
app.use('/api/channels/:id/files',         fileRoutes);
app.use('/api/channels/:id/assignments',   assignmentRoutes);
app.use('/api/channels/:id/announcements', announcementRoutes);
app.use('/api/channels/:id/notes',         actualNotesRoutes);
app.use('/api/notifications',              notificationRoutes);
app.use('/api/projects',                   projectRoutes);
app.use('/api/academic-events',            academicEventRoutes);

app.use((req, res) => res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found` }));
app.use(errorHandler);

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`🚀 Server running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode`));

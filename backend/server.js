require('dotenv').config();
require('express-async-errors');

const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');

const errorHandler = require('./middleware/errorHandler');
const socketHandler = require('./socket/socketHandler');

const authRoutes         = require('./routes/authRoutes');
const channelRoutes      = require('./routes/subjectRoutes'); // Will rename file later
const messageRoutes      = require('./routes/messageRoutes');
const fileRoutes         = require('./routes/noteRoutes'); // Will rename file later
const assignmentRoutes   = require('./routes/assignmentRoutes');
const announcementRoutes = require('./routes/announcementRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const actualNotesRoutes  = require('./routes/actualNotesRoutes');

const app = express();
const server = http.createServer(app);

const allowedOrigins = [
  process.env.CLIENT_URL,
  'http://localhost:5173',
  'http://localhost:3000',
  /\.vercel\.app$/,        // allow all Vercel preview/branch URLs
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

app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/api/health', (req, res) => res.json({ success: true, message: 'ADTU Collab API is running 🚀' }));

app.use('/api/auth',                       authRoutes);
app.use('/api/channels',                   channelRoutes);
app.use('/api/channels/:id/messages',      messageRoutes);
app.use('/api/channels/:id/files',         fileRoutes);
app.use('/api/channels/:id/assignments',   assignmentRoutes);
app.use('/api/channels/:id/announcements', announcementRoutes);
app.use('/api/channels/:id/notes',         actualNotesRoutes);
app.use('/api/notifications',              notificationRoutes);

app.use((req, res) => res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found` }));
app.use(errorHandler);

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`🚀 Server running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode`));

const express    = require('express');
const rateLimit  = require('express-rate-limit');
const router     = express.Router();
const { register, login, getMe, updateProfile, changePassword } = require('../controllers/authController');
const { protect } = require('../middleware/auth');
const upload     = require('../middleware/upload');

// Brute-force protection: max 10 login attempts per 15 minutes per IP
const loginLimiter = rateLimit({
  windowMs      : 15 * 60 * 1000,
  max           : 10,
  message       : { success: false, message: 'Too many login attempts. Try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders  : false,
});

router.post('/register', register);
router.post('/login', loginLimiter, login);  // limiter applied BEFORE handler ✓
router.get('/me',              protect, getMe);
router.put('/profile',         protect, upload.single('avatar'), updateProfile);
router.post('/change-password', protect, changePassword);  // POST: matches frontend call

module.exports = router;

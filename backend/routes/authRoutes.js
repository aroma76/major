const express    = require('express');
const rateLimit  = require('express-rate-limit');
const router     = express.Router();
const { register, login, getMe, updateProfile, changePassword, searchUsers } = require('../controllers/authController');
const { protect } = require('../middleware/auth');
const upload     = require('../middleware/upload');

// Brute-force protection: max 50 login attempts per 15 minutes per IP
const loginLimiter = rateLimit({
  windowMs      : 15 * 60 * 1000,
  max           : 50,
  message       : { success: false, message: 'Too many login attempts. Please wait 15 minutes and try again.' },
  standardHeaders: true,
  legacyHeaders  : false,
  skipSuccessfulRequests: true,  // successful logins don’t count toward the limit
});

router.post('/register', register);
router.post('/login', loginLimiter, login);  // limiter applied BEFORE handler ✓
router.get('/me',              protect, getMe);
router.put('/profile',         protect, upload.single('avatar'), updateProfile);
router.post('/change-password', protect, changePassword);
router.get('/users/search',    protect, searchUsers);

module.exports = router;

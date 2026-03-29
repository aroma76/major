# API Reference

Base URL (local): `http://localhost:5000/api`
All protected routes require: `Authorization: Bearer <token>`

## Auth
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/register` | ❌ | Register |
| POST | `/auth/login` | ❌ | Login → JWT |
| GET | `/auth/me` | ✅ | Get current user |
| PUT | `/auth/profile` | ✅ | Update profile (multipart) |

## Subjects
| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| GET | `/subjects` | All | Get my subjects |
| GET | `/subjects/:id` | All | Get one |
| POST | `/subjects` | admin/faculty | Create |
| PUT | `/subjects/:id` | admin/faculty | Update |
| DELETE | `/subjects/:id` | admin | Delete |
| GET | `/subjects/:id/members` | All | List members |

## Messages (Chat)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/subjects/:id/messages` | Get history |
| POST | `/subjects/:id/messages` | Send (with optional file) |
| GET | `/subjects/:id/messages/pinned` | Pinned messages |
| PUT | `/subjects/:id/messages/:msgId/pin` | Toggle pin (faculty/admin) |
| DELETE | `/subjects/:id/messages/:msgId` | Delete |

## Notes
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/subjects/:id/notes?search=` | List |
| POST | `/subjects/:id/notes` | Upload (faculty/admin, multipart) |
| DELETE | `/subjects/:id/notes/:noteId` | Delete |

## Assignments
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/subjects/:id/assignments` | List (role-aware) |
| POST | `/subjects/:id/assignments` | Create (faculty/admin) |
| POST | `/subjects/:id/assignments/:aId/submit` | Submit (student, multipart) |
| GET | `/subjects/:id/assignments/:aId/submissions` | All submissions (faculty/admin) |
| PUT | `/subjects/:id/assignments/submissions/:sId/grade` | Grade |

## Announcements
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/subjects/:id/announcements` | List |
| POST | `/subjects/:id/announcements` | Create (faculty/admin) |
| DELETE | `/subjects/:id/announcements/:aId` | Delete |

## Notifications
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/notifications` | Get all |
| GET | `/notifications/unread-count` | Count |
| PUT | `/notifications/read-all` | Mark all read |
| PUT | `/notifications/:id/read` | Mark one read |
| DELETE | `/notifications/:id` | Delete |

## Socket.IO Events
| Emit | Payload | Description |
|------|---------|-------------|
| `user:join` | userId | Register session |
| `subject:join` | subjectId | Join room |
| `message:send` | {subjectId,senderId,content} | Send message |
| `typing:start` | {subjectId,userName} | Start typing |
| `typing:stop` | {subjectId} | Stop typing |

| Listen | Description |
|--------|-------------|
| `message:new` | New chat message |
| `typing:start/stop` | Typing indicators |
| `notification:new` | Real-time notification |

# 📚 ADTU StudyHub — Complete Documentation Index

**Project:** ADTU StudyHub (Academic Collaboration Platform)
**Stack:** Flutter + Riverpod | Node.js + Express | PostgreSQL (Neon) + Supabase Storage
**Documentation Status:** ✅ Complete

---

## 🗂️ Documentation Structure

```
docs/
├── 00_PROJECT_ARCHITECTURE.md           ← Master project overview
│
├── backend/
│   ├── server_explained.md              ← Express server entry point
│   ├── config/
│   │   ├── db_explained.md              ← PostgreSQL connection pool
│   │   ├── supabase_explained.md        ← Supabase storage client
│   │   └── database_schema_explained.md ← All 15 tables + relationships + RLS
│   ├── middleware/
│   │   ├── auth_explained.md            ← JWT protect + role authorize
│   │   ├── upload_explained.md          ← Custom Multer→Supabase storage engine
│   │   └── errorHandler_and_socket_explained.md ← Error handler + Socket.IO
│   ├── controllers/
│   │   ├── authController_explained.md  ← Register, Login, Profile, Password
│   │   ├── messageController_explained.md ← Messages + REST↔Socket bridge
│   │   └── [other controllers]          ← Channel, Assignment, Project, etc.
│   └── routes/
│       └── all_routes_explained.md      ← All 10 route files explained
│
├── frontend/
│   ├── models/
│   │   └── all_models_explained.md      ← ApiMessageModel, AssignmentModel, etc.
│   ├── repositories/
│   │   └── all_repositories_explained.md ← All 6 repository classes
│   ├── services/
│   │   ├── api_service_explained.md     ← Dio HTTP client + all endpoints
│   │   ├── auth_and_storage_service_explained.md ← Session + secure storage
│   │   └── socket_service_explained.md  ← WebSocket client lifecycle
│   ├── providers/
│   │   ├── auth_provider_explained.md   ← AuthNotifier state machine
│   │   ├── api_providers_explained.md   ← All FutureProviders + keepAlive
│   │   └── messages_and_task_providers_explained.md ← Chat state + Kanban
│   ├── screens/
│   │   ├── login_screen_explained.md    ← Animated login UI + NetPainter
│   │   └── main_dashboard_screen_explained.md ← Shell + LazyIndexedStack
│   ├── theme/
│   │   └── app_colors_explained.md      ← Color system + ThemeModeNotifier
│   └── utils/
│       └── utilities_explained.md       ← Responsive, AppConfig, SavedFiles
│
└── system/
    ├── authentication_flow_explained.md  ← Complete auth lifecycle diagrams
    ├── realtime_and_state_management_explained.md ← Socket + Riverpod flows
    └── code_quality_review.md           ← Bugs, security, refactoring guide
```

---

## 🚀 Quick Navigation

### By Learning Goal

| If you want to understand... | Read this document |
|---|---|
| How the whole system fits together | `00_PROJECT_ARCHITECTURE.md` |
| How login works end-to-end | `system/authentication_flow_explained.md` |
| How real-time messages work | `system/realtime_and_state_management_explained.md` |
| All database tables and relationships | `backend/config/database_schema_explained.md` |
| How the Flutter app loads data | `frontend/providers/api_providers_explained.md` |
| How files are uploaded to the cloud | `backend/middleware/upload_explained.md` |
| How the message chat works | `frontend/providers/messages_and_task_providers_explained.md` |
| Known bugs and how to fix them | `system/code_quality_review.md` |
| How navigation works in Flutter | `frontend/screens/main_dashboard_screen_explained.md` |
| How JWT tokens work | `backend/middleware/auth_explained.md` |

### By File Type

| File | Documentation |
|---|---|
| `backend/server.js` | `backend/server_explained.md` |
| `backend/config/db.js` | `backend/config/db_explained.md` |
| `backend/config/supabase.js` | `backend/config/supabase_explained.md` |
| `backend/middleware/auth.js` | `backend/middleware/auth_explained.md` |
| `backend/middleware/upload.js` | `backend/middleware/upload_explained.md` |
| `backend/middleware/errorHandler.js` | `backend/middleware/errorHandler_and_socket_explained.md` |
| `backend/socket/socketHandler.js` | `backend/middleware/errorHandler_and_socket_explained.md` |
| `backend/controllers/authController.js` | `backend/controllers/authController_explained.md` |
| `backend/controllers/messageController.js` | `backend/controllers/messageController_explained.md` |
| `backend/routes/*.js` | `backend/routes/all_routes_explained.md` |
| `frontend/.../api_message_model.dart` | `frontend/models/all_models_explained.md` |
| `frontend/.../assignment_model.dart` | `frontend/models/all_models_explained.md` |
| `frontend/.../repositories/*.dart` | `frontend/repositories/all_repositories_explained.md` |
| `frontend/.../api_service.dart` | `frontend/services/api_service_explained.md` |
| `frontend/.../auth_service.dart` | `frontend/services/auth_and_storage_service_explained.md` |
| `frontend/.../storage_service.dart` | `frontend/services/auth_and_storage_service_explained.md` |
| `frontend/.../socket_service.dart` | `frontend/services/socket_service_explained.md` |
| `frontend/.../auth_provider.dart` | `frontend/providers/auth_provider_explained.md` |
| `frontend/.../api_providers.dart` | `frontend/providers/api_providers_explained.md` |
| `frontend/.../messages_notifier.dart` | `frontend/providers/messages_and_task_providers_explained.md` |
| `frontend/.../task_provider.dart` | `frontend/providers/messages_and_task_providers_explained.md` |
| `frontend/.../login_screen.dart` | `frontend/screens/login_screen_explained.md` |
| `frontend/.../main_dashboard_screen.dart` | `frontend/screens/main_dashboard_screen_explained.md` |
| `frontend/.../app_colors.dart` | `frontend/theme/app_colors_explained.md` |
| `frontend/.../responsive.dart` | `frontend/utils/utilities_explained.md` |
| `frontend/.../saved_files_provider.dart` | `frontend/utils/utilities_explained.md` |

---

## 📊 Documentation Statistics

| Category | Doc Files Created | Source Files Covered |
|---|---|---|
| Backend Core | 5 | server.js, db.js, supabase.js, auth.js, upload.js |
| Backend Controllers | 3 | authController.js, messageController.js (+ cross-ref) |
| Backend Routes | 1 (combined) | 10 route files |
| Backend Socket | 1 | socketHandler.js |
| Frontend Models | 1 (combined) | 5 model files |
| Frontend Repositories | 1 (combined) | 6 repository files |
| Frontend Services | 3 | api_service, auth_service, storage_service, socket_service |
| Frontend Providers | 3 | auth_provider, api_providers, messages_notifier, task_provider |
| Frontend Screens | 2 | login_screen, main_dashboard_screen |
| Frontend Theme/Utils | 3 | app_colors, responsive, app_config, saved_files |
| Database | 1 | schema.sql, rls_security_migration.sql |
| System Architecture | 3 | Auth flow, Real-time flow, Code quality review |
| **Total** | **27 files** | **40+ source files** |

---

## 🎯 Key Concepts Explained

| Concept | Location in Docs |
|---|---|
| JWT Authentication | `auth_explained.md` + `auth_provider_explained.md` |
| bcrypt Password Hashing | `authController_explained.md` |
| Connection Pooling | `db_explained.md` |
| Supabase Storage | `supabase_explained.md` + `upload_explained.md` |
| Row Level Security (RLS) | `database_schema_explained.md` |
| Socket.IO Rooms | `errorHandler_and_socket_explained.md` + `socket_service_explained.md` |
| Cursor Pagination | `messageController_explained.md` + `messages_and_task_providers_explained.md` |
| Riverpod keepAlive | `api_providers_explained.md` |
| Offline-First Pattern | `messages_and_task_providers_explained.md` |
| LazyIndexedStack | `main_dashboard_screen_explained.md` |
| Dio Interceptors | `api_service_explained.md` |
| Future.wait Parallelism | `all_repositories_explained.md` |
| Immutable State (copyWith) | `messages_and_task_providers_explained.md` |
| ThemeMode Toggle | `app_colors_explained.md` |
| RepaintBoundary | `main_dashboard_screen_explained.md` |
| Bézier Curve Background | `login_screen_explained.md` |

---

> 📝 **Note for Developers:** All documentation was generated with a complete line-by-line analysis of every source file. When files are updated, the corresponding `_explained.md` file should also be updated. Consider this documentation as a living reference — treat it like a textbook companion to the codebase.

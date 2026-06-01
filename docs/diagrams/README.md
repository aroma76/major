# EduSync — Diagrams Index

All 15 software engineering diagrams are split across 5 Draw.io files. Open each `.drawio` file in [diagrams.net](https://app.diagrams.net) (File → Open from → Device).

---

## 📁 File Manifest

| File | Diagrams Included | Pages |
|------|-------------------|-------|
| [Part 1](./ADTU_StudyHub_Diagrams_Part1.drawio) | High-Level Architecture, Low-Level Design, System Architecture, Use Case | 4 |
| [Part 2](./ADTU_StudyHub_Diagrams_Part2.drawio) | Activity Diagram, Seq: Login, Seq: Assignment, Seq: Messaging, Seq: Notification | 5 |
| [Part 3](./ADTU_StudyHub_Diagrams_Part3.drawio) | Data Flow Diagram (L0+L1), ERD | 2 |
| [Part 4](./ADTU_StudyHub_Diagrams_Part4.drawio) | Class Diagram, Component Diagram, Deployment Diagram | 3 |
| [Part 5](./ADTU_StudyHub_Diagrams_Part5.drawio) | Auth Flow, REST API Lifecycle, Socket.IO Architecture, Database Schema | 4 |

**Total: 18 pages across 5 files covering all 15 requested diagram types.**

---

## 📊 Diagram Descriptions

### Part 1 — Architecture Overview
| # | Diagram | Description |
|---|---------|-------------|
| 1 | **High-Level Architecture** | Flutter ↔ Express ↔ PostgreSQL ↔ Supabase with Student/Faculty/Admin actors |
| 2 | **Low-Level Design** | Routes → Middleware → Controllers → Socket → DB layers in 3 columns |
| 3 | **System Architecture** | Client Zone, Vercel CDN, Render.com, Neon, Supabase with network protocols |
| 4 | **UML Use Case Diagram** | Full use cases for Student, Faculty, Admin with include/extend relations |

### Part 2 — Behavioral Diagrams
| # | Diagram | Description |
|---|---------|-------------|
| 5 | **Activity Diagram** | 3 swim lanes: Login Flow, Assignment Submission Flow, Project Collaboration |
| 6A | **Sequence: User Login** | 11-step login sequence from UI → AuthService → Dio → Backend → DB → JWT |
| 6B | **Sequence: Assignment Submission** | Multipart POST flow through Multer → Supabase → PostgreSQL |
| 6C | **Sequence: Real-Time Messaging** | WebSocket flow: emit → save DB → broadcast to room → state update |
| 6D | **Sequence: Notification Delivery** | Grading trigger → DB insert → Socket emit → UI badge update |

### Part 3 — Data Flow
| # | Diagram | Description |
|---|---------|-------------|
| 7 | **DFD (Level 0 + Level 1)** | Context diagram + detailed 8-process DFD with datastores |
| 8 | **ERD** | All 16 entities with PKs, FKs, cardinalities (Crow's Foot notation) |

### Part 4 — Structural Diagrams
| # | Diagram | Description |
|---|---------|-------------|
| 9 | **Class Diagram** | Models, Services, Providers (Frontend) + Controllers, SocketHandler (Backend) |
| 10 | **Component Diagram** | Frontend, Backend, Database, Storage subsystems with interfaces |
| 11 | **Deployment Diagram** | User Device → Vercel → Render.com → Neon → Supabase with protocols |

### Part 5 — Flow & Schema Diagrams
| # | Diagram | Description |
|---|---------|-------------|
| 12 | **Authentication Flow** | Complete auth lifecycle: credentials → JWT → StorageService → AuthGate → Dashboard |
| 13 | **REST API Lifecycle** | 14-step pipeline: Widget → Dio → CORS → RateLimit → Router → JWT → RBAC → Controller → DB → Response |
| 14 | **Socket.IO Architecture** | Clients, Server event handlers, Rooms (channel + personal), State updates |
| 15 | **Database Schema** | Full PostgreSQL schema with all columns, constraints, indexes, and FK relationships |

---

## 🖥️ How to Open

1. Go to [https://app.diagrams.net](https://app.diagrams.net)
2. Click **File → Open from → Device**
3. Select any `.drawio` file from this folder
4. Use the **page tabs** at the bottom to switch between diagrams

### Exporting for Report
- **File → Export As → PNG** (300 DPI recommended for print)
- **File → Export As → PDF** (vector quality)
- **File → Export As → SVG** (scalable for digital reports)

---

## ✅ Coverage Checklist

- [x] 1. High-Level Architecture Diagram
- [x] 2. Low-Level Design Diagram
- [x] 3. System Architecture Diagram
- [x] 4. UML Use Case Diagram (Student + Faculty + Admin)
- [x] 5. Activity Diagram (3 workflows)
- [x] 6A. Sequence: User Login
- [x] 6B. Sequence: Assignment Submission
- [x] 6C. Sequence: Real-Time Messaging
- [x] 6D. Sequence: Notification Delivery
- [x] 7. Data Flow Diagram (Level 0 + Level 1)
- [x] 8. Entity Relationship Diagram (16 entities, PKs, FKs, cardinalities)
- [x] 9. Class Diagram (Controllers, Services, Models, Providers)
- [x] 10. Component Diagram (Frontend + Backend + DB + Storage)
- [x] 11. Deployment Diagram (Device → Vercel → Render → Neon → Supabase)
- [x] 12. Authentication Flow Diagram
- [x] 13. REST API Request Lifecycle Diagram
- [x] 14. Real-Time Socket.IO Architecture Diagram
- [x] 15. Database Schema Diagram

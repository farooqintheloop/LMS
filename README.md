# AM LMS

**A full Learning Management System** — four roles, three clients, one API contract, and a lecture pipeline that actually ships video in **50 MB chunks** to object storage.

This is not a login screen with a fake dashboard. It is an education product: students enroll and watch (including offline), teachers run courses and chat, admins operate the institute, and the edge talks to **MongoDB** and **Cloudflare R2**.

```
  Flutter (Android · Windows · Linux · macOS · web)
  React + Vite (auth, dashboards, chunked upload)
                         │  HTTPS · JWT
                         ▼
              Cloudflare Workers  (KV · R2 · CORS)
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
        Express + Mongo        Django 4.2 + DRF
        server.js              courses · lectures · live · stream
              │                     │
              └──────────┬──────────┘
                         ▼
              MongoDB Atlas · Cloudflare R2 · Redis (optional)
```

If you cloned this because you wanted to see “how far one person can push an LMS,” start at [`frontend/frontend/lib/main.dart`](frontend/frontend/lib/main.dart) and work inward.

---

## What was built

| Layer | What it is | What it actually does |
| --- | --- | --- |
| **Flutter app** `frontend/frontend` | `lms_app` — Riverpod, GoRouter, Dio | The **complete** product: auth, student catalog + player + PDFs + downloads + chat, teacher courses + conversations, admin CRUD + analytics + chunked lecture upload, light/dark, emulator block |
| **Web app** `web/` | React 19, TypeScript, Vite 7 | Login, register, forgot/change password, role dashboard, dark mode, **same chunked uploader** as mobile |
| **Django** `backend/` | DRF, SimpleJWT, Djongo/PyMongo, Channels | Canonical domain: users, courses, lectures, live classes, streaming tokens, notifications, analytics |
| **Express** `backend/server.js` | Node, Mongo driver, JWT, Multer, aws-sdk | Adapter used against Mongo + R2-shaped storage (auth, role APIs, catalog, health) |
| **Workers** `backend/workers/` | Wrangler, KV `LMS_SESSIONS`, R2 `LMS_STORAGE` | Global entry: CORS, routing, request logs, edge + origin |

Clients share an `/api/...` contract so Flutter and the browser stay interchangeable.

Production hostnames that appear in the clients (override them):

- Workers: `lms-api-production.muheet228.workers.dev`
- Origin: `api.amlms.com`

```bash
flutter run --dart-define=API_BASE_URL=https://YOUR_WORKER/api
```

---

## Roles (the product, not the slide)

### Student

- Register / login (JWT access + refresh), password strength, role redirect
- Dashboard, **Discover courses** (search, category, difficulty, sort)
- Enroll / unenroll, course detail, lecture **video player**, **PDF viewer**
- Offline **downloaded videos**
- Course chat with the instructor
- Live-class listing / join paths on the API

### Teacher

- Teacher dashboard and own courses
- Course detail, lecture/assignment endpoints
- Student progress and course analytics
- Conversation list + teacher chat

### Admin / super admin

- Institute dashboard: overview, recent activity, **Users**, **Courses**, system health
- Student and teacher management
- Course and lecture management — **multipart chunk upload** (50 MB parts)
- Analytics screen; reports is a coming-soon route
- Bootstrap-admin endpoint (header secret, **no default password in source**)

### Platform hardening (Flutter)

- Role-based `GoRouter` redirects
- `flutter_secure_storage` for tokens
- **Emulator / simulator blocker** on launch
- Secure screen wrapper (screenshot / overlay hardening)
- Device info + connectivity

---

## Flutter map — every real screen

Routed from [`lib/main.dart`](frontend/frontend/lib/main.dart):

| Route | Screen |
| --- | --- |
| `/login` `/register` | Auth |
| `/terms-of-service` `/privacy-policy` | Legal |
| `/student/dashboard` | Student home |
| `/student/courses` | Catalog (tabs, search, filters) |
| `/student/course/:courseId` | Course detail |
| `/student/video-player` | Lecture playback |
| `/student/pdf-viewer` | Materials |
| `/student/downloaded-videos` | Offline library |
| `/student/chat/:courseId` | Student ↔ teacher |
| `/teacher/dashboard` `/teacher/courses` `/teacher/course/:id` | Teaching |
| `/teacher/conversations` `/teacher/chat/:id` | Inbox |
| `/admin/dashboard` | Ops overview + tabs |
| `/admin/students` `/admin/teachers` | People |
| `/admin/courses` `/admin/lectures` | Content + **chunked upload** |
| `/admin/analytics` `/admin/reports` | Numbers / coming soon |

**Core client SDK:** [`lib/src/core/services/api_service.dart`](frontend/frontend/lib/src/core/services/api_service.dart) (~1400 lines of the same API the web app uses).

**Upload:** [`chunked_uploader.dart`](frontend/frontend/lib/src/core/services/chunked_uploader.dart) + [`web/src/utils/ChunkedUploader.ts`](web/src/utils/ChunkedUploader.ts).

---

## Backend map — Django apps

Mounted in [`lms_backend/urls.py`](backend/lms_backend/urls.py):

| Prefix | App | Surface |
| --- | --- | --- |
| `/api/auth/` | `authentication` | register, login, refresh, dashboard, password, email/phone verify, bootstrap admin, health |
| `/api/courses/` | `courses` | student / teacher / admin dashboards, enroll, reviews, announcements, materials, lecture upload |
| `/api/lectures/` | `lectures` | continue watching, progress, bookmarks, notes, likes, comments, stream sessions |
| `/api/live-classes/` | `live_classes` | schedule, join/leave, attendance, recordings, polls, chat, **Zoom webhook** |
| `/api/streaming/` | `streaming` | playback tokens, quality variants, download tokens, analytics |
| `/api/notifications/` | `notifications` | list/read, settings, device tokens, Channels consumer |
| `/api/analytics/` | `analytics` | dashboard, course/lecture, activity track, system |

Mongo-first views (`simple_mongo_views`, `mongo_views`) are the live path. Older `sqlite/` and `original/` trees are kept as migration history — they are not the default.

**Express** (`server.js`) mirrors the same story: auth, student/teacher/admin, courses, lectures, materials, live classes, notifications, streaming, search, `/api/health`.

**Workers** (`workers/simple-lms-api.js`): health, API routing, admin log viewer (KV), R2-aware file path.

---

## Web map

[`web/src/App.tsx`](web/src/App.tsx): `/login` · `/register` · `/forgot-password` · `/change-password` · `/dashboard`.

The React app is **not** a 1:1 clone of every Flutter screen. It is the browser twin for auth, role dashboards, and lecture upload.

---

## Tech stack (what is in the lockfiles)

**Clients**

- Flutter 3 / Dart 3 · `flutter_riverpod` · `go_router` · `dio`
- Hive, SharedPreferences, flutter_secure_storage
- `file_picker` · `video_player` · `webview_flutter` · `fl_chart` · `google_fonts`
- React 19 · TypeScript · Vite 7 · Axios · React Router 7 · Lucide

**Server**

- Django 4.2 · DRF · SimpleJWT · cors-headers · Channels / Daphne · WhiteNoise · Pillow
- PyMongo / Djongo · boto3 · python-decouple
- Express · bcrypt · jsonwebtoken · mongodb · multer · aws-sdk · nodemailer
- Cloudflare Workers + Wrangler · KV · R2

**Data**

- MongoDB (Atlas in production, local `mongodb://127.0.0.1:27017` if `DATABASE_URL` is unset)
- SQLite files are gitignored leftovers from early Django experiments

---

## Repository layout

```
LMS/
├── README.md                 ← you are here
├── .gitignore                ← venv, node_modules, build, .env, keystores
├── backend/
│   ├── manage.py
│   ├── server.js
│   ├── wrangler.toml.example
│   ├── .env.example
│   ├── authentication/  courses/  lectures/
│   ├── live_classes/    streaming/  notifications/  analytics/
│   ├── workers/simple-lms-api.js
│   ├── cloudflare_r2.py
│   ├── scripts/create_super_admin.py
│   └── chunking-examples/    Dart + JS upload samples
├── frontend/frontend/        Flutter app
│   ├── lib/main.dart
│   ├── lib/src/core/         API, theme, providers, security
│   ├── lib/src/features/     auth · student · teacher · admin
│   ├── android/ windows/ linux/ macos/ web/
│   ├── README_APK_BUILD.md
│   └── README_DESKTOP_BUILD.md
└── web/                      React + Vite
    ├── src/pages/
    ├── src/utils/ChunkedUploader.ts
    └── src/services/apiService.ts
```

---

## Quick start

### 1. Django API

```bash
cd backend
python -m venv venv
# Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# DATABASE_URL, SECRET_KEY, JWT_SECRET_KEY
python manage.py migrate
python manage.py runserver
```

Optional:

```bash
celery -A lms_backend worker --loglevel=info
```

### 2. Express adapter

```bash
cd backend
npm install
# .env: MONGO_URI / DATABASE_URL, JWT secret, R2 keys
npm start
```

### 3. Cloudflare Worker

```bash
cd backend
cp wrangler.toml.example wrangler.toml
npx wrangler secret put JWT_SECRET
npx wrangler secret put ADMIN_TOKEN
npx wrangler deploy
```

### 4. Flutter

```bash
cd frontend/frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=https://YOUR_WORKER/api
```

Release APK: [`frontend/frontend/README_APK_BUILD.md`](frontend/frontend/README_APK_BUILD.md)

```bash
python build_apk.py https://YOUR_WORKER/api
```

Windows desktop: [`README_DESKTOP_BUILD.md`](frontend/frontend/README_DESKTOP_BUILD.md)

Copy `android/key.properties.example` → `android/key.properties`. **Never commit** `key.properties` or `*.jks`.

### 5. Web

```bash
cd web
npm install
npm run dev      # http://localhost:5173
npm run build
```

Point `web/src/services/apiService.ts` at your API.

---

## Environment

Templates (safe to commit):

- [`backend/.env.example`](backend/.env.example)
- [`backend/wrangler.toml.example`](backend/wrangler.toml.example)
- [`frontend/frontend/android/key.properties.example`](frontend/frontend/android/key.properties.example)

Gitignored: `.env`, `production.env`, keystores, `venv/`, `node_modules/`, Flutter `build/`, `web/dist/`, SQLite, media, Wrangler cache.

Worker secrets belong in Wrangler (`wrangler secret put`), not in git.

If this repo (or an older zip) ever had a Mongo URI in source, **rotate that Atlas password**. Defaults in code now point at `mongodb://127.0.0.1:27017`.

---

## API sketch

**Auth** — `POST /api/auth/register` · `login` · `refresh-token` · `GET /api/auth/dashboard` · password + verify · `GET /api/auth/health/`

**Student** — `GET /api/courses/student/dashboard` · enrolled · enroll · progress · assignments

**Teacher** — dashboard, courses, create, students, analytics, assignments

**Admin** — dashboard, users, courses, lectures, analytics, `POST /api/admin/upload-chunk`

**Catalog & media** — courses, lectures, materials, live-classes, notifications, streaming, search

Read the trees: [`authentication/urls.py`](backend/authentication/urls.py), [`courses/urls.py`](backend/courses/urls.py), [`lectures/urls.py`](backend/lectures/urls.py), [`live_classes/urls.py`](backend/live_classes/urls.py), [`server.js`](backend/server.js).

---

## Where to look first (reviewers)

1. [`frontend/frontend/lib/main.dart`](frontend/frontend/lib/main.dart) — routing by role  
2. [`api_service.dart`](frontend/frontend/lib/src/core/services/api_service.dart) — the client SDK  
3. [`chunked_uploader.dart`](frontend/frontend/lib/src/core/services/chunked_uploader.dart) — 50 MB lecture pipeline  
4. [`courses/urls.py`](backend/courses/urls.py) — domain surface  
5. [`server.js`](backend/server.js) — Node adapter  
6. [`workers/simple-lms-api.js`](backend/workers/simple-lms-api.js) — edge  
7. [`web/src/App.tsx`](web/src/App.tsx) + [`ChunkedUploader.ts`](web/src/utils/ChunkedUploader.ts)

---

## Honest edges (read before opening issues)

- Flutter is the **complete** UI. React is **auth + dashboard + upload**.
- Firebase Cloud Messaging is commented in `pubspec.yaml`; notification models and a Flutter service exist for later wiring.
- OAuth buttons may appear in UI; Google / Microsoft / LinkedIn are **ready to wire**, not the default login.
- Django still contains backup URL trees (`mongoengine/`, `sqlite/`, `original/`) from the Mongo migration.
- Admin **reports** is an explicit coming-soon screen.
- `content_security.py` has FFmpeg / Fernet helpers for segmented encrypted video — ops still need FFmpeg on the box if you turn that path on.

---

## Design

- Brand: **AM LMS**, Material 3, light and dark
- Flutter: `AppColors`, `AppTheme`, `GradientScaffold`, shared cards (course, stats, live class, progress)
- Web: CSS variables, same auth language as mobile

---

## License

Private unless you add a `LICENSE`. Treat every secret as yours.

---

Built as a serious LMS: **roles, content, video, live, admin, edge, and clients that share one API.**

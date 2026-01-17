# Isan 📝

A clean, Offline-First notes application built with Flutter, Drift (SQLite), and Supabase. Designed for speed, seamless synchronization across devices, and full Web compatibility.

## 🚀 Project Roadmap

- [x] **Phase 1:** Environment Setup (Windows/Android) & Base Project Initialization.
- [x] **Phase 2:** Local Database & Offline Logic.
  - [x] Data Model Definition (`Note`).
  - [x] Database Service Implementation.
  - [x] Basic CRUD Testing UI.
- [x] **Phase 3:** iOS-style UI/UX Design (Minimalist & Clean).
- [x] **Phase 4:** Cloud Sync Engine (Supabase).
  - [x] Supabase Project Setup & Table Definition.
  - [x] Cloud-to-Local & Local-to-Cloud Sync Logic.
  - [x] Conflict Handling & UUID Management.
- [x] **Phase 5:** Authentication & User Management.
  - [x] Supabase Auth (Email/Password).
  - [x] Login & Sign Up Screens.
  - [x] Data Privatization (RLS).
- [x] **Phase 6:** Web Compatibility Attempt (Isar Plus).
  - [x] Migrate from standard `isar` to `isar_plus`.
  - [x] **Outcome:** Successfully migrated, but encountered critical limitations with Browser Security (Web Workers/Isolates) preventing automatic UI updates (Watchers) on the Web.
- [x] **Phase 7:** Final Database Migration (Drift / SQLite).
  - [x] Remove Isar dependencies.
  - [x] Implement Drift (SQLite) using `sqlite3.wasm` and `drift_worker.js` for non-blocking Web Workers.
  - [x] Re-implement Database Service using SQL tables.
  - [x] Verify native Streams (Watchers) on Web, Android, and Windows.
- [x] **Phase 8:** Deployment & Release (APK / EXE / Web).
- [ ] **Phase 9:** iOS Deployment (IPA / TestFlight).

## 🛠️ Tech Stack

- **Framework:** Flutter 3.x (Windows / Android / Web)
- **Language:** Dart
- **Local Database:** Drift (SQLite) - *Chosen for robust Web support (WASM/OPFS)*
- **Backend & Auth:** Supabase
- **Architecture:** Offline-First

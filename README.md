# Isan 📝

A clean, Offline-First notes application built with Flutter, Isar Plus, and Supabase. Designed for speed, seamless synchronization across devices, and full Web compatibility.

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
- [x] **Phase 6:** Web Compatibility & Database Migration.
  - [x] Migrate from standard `isar` to `isar_plus`.
  - [x] **Note:** This phase was introduced to ensure full compatibility with **Flutter Web**. The migration enables persistent offline storage in browsers using **OPFS/IndexedDB**, allowing Isar to function correctly on the web platform.
- [ ] **Phase 7:** Deployment & Release (APK / EXE / Web).

## 🛠️ Tech Stack

- **Framework:** Flutter 3.x (Windows / Android / Web)
- **Language:** Dart
- **Local Database:** Isar Plus (High-performance NoSQL with Web Support)
- **Backend & Auth:** Supabase
- **Architecture:** Offline-First

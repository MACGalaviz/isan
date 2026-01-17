# ISAN – Application Work Plan

This document describes the **technical roadmap**, structured into **modules / sprints**, with clear goals, scope, and checklists.
It is intended to live inside the repository and evolve as the project grows.

---

## Overall Goals

- Reliable offline-first notes application
- Robust sync with Supabase
- Clean separation of concerns (UI / Domain / Data)
- Predictable UX and state handling
- Maintainable and extensible architecture

---

## Sprint 0 – UI & Design System ✅ (COMPLETED)

### Scope
- Centralized Theme (colors, text hierarchy, components)
- Remove hardcoded UI values
- Consistent modal & snackbar behavior
- Auth / Profile / Editor UI cleanup

### Completed
- [x] App-wide `AppTheme`
- [x] Text hierarchy (headline, title, body, label)
- [x] Material 3 setup
- [x] Auth modal UI
- [x] Profile modal UI
- [x] Editor screen UI
- [x] FloatingActionButton + SnackBar interaction refined

**Status:** ✅ Done

---

## Sprint 1 – Sync Engine Hardening (Core Data Layer)

### Goal
Make note syncing **reliable, conflict-safe, and predictable**.

### Scope
- Offline-first behavior
- Local DB as source of truth
- Deterministic sync rules

### Tasks
- [ ] Define sync states (local-only, synced, dirty, conflict)
- [ ] Add `updated_at` + `last_synced_at` logic
- [ ] Resolve conflicts (last-write-wins or merge)
- [ ] Handle deletes safely
- [ ] Retry strategy for failed syncs

**Estimated time:** 2–3 days

---

## Sprint 2 – Authentication & Session Management

### Goal
Make auth flows **safe, predictable, and UI-aware**.

### Scope
- Supabase auth lifecycle
- Session persistence
- Clear UX for auth state

### Tasks
- [ ] Centralize auth state listener
- [ ] Handle token refresh edge cases
- [ ] Protect sync operations behind auth
- [ ] Graceful logout cleanup

**Estimated time:** 1–2 days

---

## Sprint 3 – Domain Layer Cleanup

### Goal
Separate **business logic** from UI & services.

### Scope
- Introduce domain models
- Reduce widget-side logic

### Tasks
- [ ] Create domain entities (`NoteEntity`)
- [ ] Extract use cases (CreateNote, UpdateNote, DeleteNote)
- [ ] Remove DB logic from widgets

**Estimated time:** 1–2 days

---

## Sprint 4 – State Management Strategy

### Goal
Have **predictable, testable state**.

### Scope
- Reduce implicit state
- Avoid side effects in widgets

### Tasks
- [ ] Choose state solution (ValueNotifier / Riverpod / Bloc)
- [ ] Centralize note list state
- [ ] Centralize loading & error states

**Estimated time:** 1 day

---

## Sprint 5 – Error Handling & UX Feedback

### Goal
Never fail silently.

### Scope
- Unified error handling
- User-visible feedback

### Tasks
- [ ] Error mapping (network, auth, sync)
- [ ] Global snackbar/toast strategy
- [ ] Empty / error states

**Estimated time:** 1 day

---

## Sprint 6 – Maintenance & Quality

### Goal
Keep the project **healthy long-term**.

### Scope
- Tests
- Documentation
- Cleanup

### Tasks
- [ ] Add unit tests for sync logic
- [ ] Add integration tests for auth
- [ ] Refactor technical debt
- [ ] Update documentation

**Estimated time:** ongoing

---

# ISAN – Application Work Plan

This document describes the **technical roadmap** of the ISAN application.
It is structured into **sprints and steps**, with explicit completion states.
The goal is to ensure the app **always remains functional** while evolving.

---

## Core Principles

- Offline-first architecture
- Local database is the source of truth
- Sync must never block UX
- App must compile and run at every step
- Security features must be incremental and non-breaking

---

## Sprint 0 – UI & Design System ✅ (COMPLETED)

### Scope
- Centralized theme
- Remove hardcoded UI values
- Consistent UX behavior

### Status
```
[x] App-wide AppTheme
[x] Typography hierarchy
[x] Material 3 setup
[x] Auth modal UI
[x] Profile modal UI
[x] Editor screen UI
[x] SnackBar + FAB behavior
```

---

## Sprint 1 – Data Layer & Sync Foundations

### Goal
Prepare a **stable offline-first data layer** with future-proof sync
and security hooks, without breaking the existing app.

---

### Step 1 – Local Database (Drift) Integration ✅

**Objective:**  
Replace legacy local storage with Drift-based SQLite.

```
[x] Drift database initialized
[x] Notes table defined
[x] UUID-based identity
[x] Local CRUD fully functional
[x] App runs and persists notes locally
```

---

### Step 2 – Supabase Sync (Baseline) ✅

**Objective:**  
Enable basic cloud sync without conflicts or encryption.

```
[x] Supabase notes table connected
[x] Upload local notes to cloud
[x] Download notes from cloud
[x] updated_at handled
[x] App runs with sync enabled
```

---

### Step 3 – Schema Alignment & Stability ✅

**Objective:**  
Ensure local and remote schemas are compatible.

```
[x] created_at added to Supabase
[x] updated_at consistency fixed
[x] Null-safety issues resolved
[x] Sync no longer crashes on missing fields
```

---

### Step 4 – Security Architecture (FOUNDATION ONLY) ⚠️

**Objective:**  
Lay down security building blocks **without activating encryption yet**.

```
[x] encryption_service.dart created
[x] key_derivation_service.dart created
[x] key_storage_service.dart created (placeholder)
[x] password_hash column added to DB
[ ] Encryption wired into persistence layer
[ ] Session key lifecycle defined
```

⚠️ **Important:**  
At this stage, encryption exists as code **but is NOT active**.
Notes are still stored in plaintext.

---

### Step 5 – Crypto Utilities & Compilation Stability ✅

**Objective:**  
Ensure cryptographic helpers compile and are correct.

```
[x] AES-GCM encryption utility compiles
[x] PBKDF2 key derivation compiles
[x] Secure random salt generation
[x] No runtime crypto errors
```

⚠️ Still not used in storage flow.

---

### Step 6 – Encryption Wiring (NOT STARTED)

**Objective:**  
Ensure note content is **always encrypted at rest**.

```
[ ] Encrypt content before saving to Drift
[ ] Store only encrypted payload in local DB
[ ] Sync encrypted payload to Supabase
[ ] Decrypt content only at read-time
```

This step is required before claiming E2EE.

---

### Step 7 – Locked Notes Logic (NOT STARTED)

**Objective:**  
Support password-protected notes.

```
[ ] Define locked note UX
[ ] Use isLocked flag meaningfully
[ ] Validate password before decrypting
[ ] Hide content preview for locked notes
```

---

## Sprint 2 – Authentication & Session Keys

### Goal
Introduce **user-based security context** without breaking offline usage.

```
[ ] Auth-driven session key derivation
[ ] Offline unlock using cached session key
[ ] Multi-device key consistency
[ ] Logout wipes in-memory keys
```

---

## Sprint 3 – True End-to-End Encryption (E2EE)

### Goal
Guarantee **zero-knowledge storage**.

```
[ ] Content encrypted locally
[ ] Titles decision finalized (encrypted or not)
[ ] Supabase stores unreadable data
[ ] Recovery phrase generation
[ ] Clear irreversibility guarantees
```

---

## Sprint 4 – State Management

```
[ ] Central note state
[ ] Loading/error states
[ ] Predictable UI updates
```

---

## Sprint 5 – UX, Errors & Feedback

```
[ ] Global error handling
[ ] Sync failure UX
[ ] Empty states
```

---

## Sprint 6 – Quality & Maintenance

```
[ ] Unit tests
[ ] Integration tests
[ ] Security audit notes
[ ] Documentation updates
```

---

## Current Truth (Important)

```
✔ App is stable and functional
✔ Sync works
❌ Notes are NOT encrypted at rest yet
❌ Supabase can currently read content
```

Encryption becomes real starting at **Sprint 1 – Step 6**.

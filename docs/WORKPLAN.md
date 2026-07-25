# ISAN – Application Work Plan

The technical roadmap, sprint by sprint, with what actually shipped.
Kept as a record of the order things were built in, and why.

**Status: everything planned is done except Sprints 4 and 5, which are
refactors with no user-visible outcome. See [Current truth](#current-truth).**

---

## Core Principles

- Offline-first architecture
- Local database is the source of truth
- Sync must never block UX
- App must compile and run at every step
- Security features must be incremental and non-breaking

---

## Sprint 0 – UI & Design System ✅

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

## Sprint 1 – Data Layer & Sync Foundations ✅

### Step 1 – Local Database (Drift) ✅

```
[x] Drift database initialized
[x] Notes table defined
[x] UUID-based identity
[x] Local CRUD fully functional
[x] App runs and persists notes locally
```

Drift replaced Isar: Isar's watchers never fired on the web because of the
Web Worker / isolate model. Drift runs on `sqlite3.wasm` + OPFS and streams
correctly on all four targets.

### Step 2 – Supabase Sync (Baseline) ✅

```
[x] Supabase notes table connected
[x] Upload local notes to cloud
[x] Download notes from cloud
[x] updated_at handled
```

### Step 3 – Schema Alignment ✅

```
[x] created_at added to Supabase
[x] updated_at consistency fixed
[x] Null-safety issues resolved
[x] Sync no longer crashes on missing fields
```

Schema lives in [`db/`](../db) — idempotent, safe to re-run.

### Step 4 – Security Architecture ✅

```
[x] encryption_service.dart      AES-256-GCM, fresh nonce + MAC per payload
[x] key_derivation_service.dart  PBKDF2-HMAC-SHA256, 150k iterations
[x] key_storage_service.dart     OS secure storage
[x] session_key_service.dart     in-memory key, cleared on lock and logout
[x] password_hash column
```

### Step 5 – Crypto Utilities ✅

```
[x] AES-GCM encryption utility
[x] PBKDF2 key derivation
[x] Secure random salt generation
[x] Covered by tests (see Sprint 6)
```

### Step 6 – Encryption Wiring ✅

```
[x] Encrypt title + content before saving to Drift
[x] Store only ciphertext, locally and in Supabase
[x] Decrypt at read time only
[x] Search moved in memory (SQL LIKE cannot match ciphertext)
```

Titles are encrypted too. That was a decision, not an oversight: local search
made it free, and a title leaks as much as a body.

### Step 7 – Locked Notes ✅

```
[x] Per-note password, salted PBKDF2 hash
[x] Content gate in the editor, title still visible
[x] No preview for locked notes, in the list or in search results
[x] Recovery through the account password
```

The lock is an interface gate over a note already encrypted with the master
key — not a second cipher. A genuinely unbreakable per-note lock is also
unrecoverable, and recoverability was the requirement.

---

## Sprint 2 – Authentication & Session Keys ✅

```
[x] Auth-driven key unwrapping on login
[x] Offline unlock from the cached master key
[x] Multi-device key consistency
[x] Logout wipes in-memory keys and re-initializes local mode
[x] Local notes migrate into an account, on sign-up and on sign-in
[x] Change the account password from the profile, re-wrapping the key slot
```

---

## Sprint 3 – True End-to-End Encryption ✅

```
[x] Content encrypted locally
[x] Titles encrypted (decision closed)
[x] Supabase stores unreadable data
[x] BIP39 12-word recovery phrase
[x] Cross-device password reset by email, re-wrapping the password slot
[x] Irreversibility stated plainly in the README
```

---

## Sprint 4 – State Management ⬜

```
[ ] Central note state
[ ] Loading/error states
[ ] Predictable UI updates
```

Not started, and not blocking: the app runs on plain streams today. Worth
doing only if new features are coming. Do Sprint 6's remaining tests first —
this refactor touches every data path.

---

## Sprint 5 – UX, Errors & Feedback ⬜

```
[ ] Global error handling
[ ] Sync failure UX
[ ] Empty states
```

Failures currently surface as `debugPrint` and the occasional SnackBar.
Pairs with Sprint 4.

---

## Sprint 6 – Quality & Maintenance 🟡

```
[x] Unit tests for the crypto layer (21)
[x] Security audit notes (README security model)
[x] Documentation updates
[ ] Tests for KeyManagerService, migration and sync
[ ] Integration tests
```

The untested paths all reach Supabase and platform storage, so they need
dependency injection before they can be mocked. Those are also the paths where
data can actually be lost — a green suite today is not permission to start
Sprint 4.

---

## Beyond the original plan

Shipped after the sprints above were written:

```
[x] Offline sync queue — failed uploads retry instead of being lost
[x] Delete tombstones — a note deleted offline no longer resurrects
[x] Note types — plain, markdown with a rendered view, copyable fields
[x] Copy a whole note, or one line at a time
[x] macOS as a fourth target
```

Dropped on purpose:

```
[–] iOS / TestFlight — distribution needs a paid Apple Developer account
[–] Encrypting the cached master key — costs the offline open, little gained
    while the OS keystore holds it
```

---

## Current truth

```
✔ Stable and functional on Android, Windows, macOS and web
✔ Sync works, and retries what it could not send
✔ Notes are encrypted at rest, titles included
✔ Supabase cannot read note content
❌ No central state management
❌ Sync layer is untested
```

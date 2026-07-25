<div align="center">

<img src="web/icons/Icon-512.png" alt="Isan" width="140" height="140" />

# Isan

**Notes that are encrypted before they ever leave your device.**

An offline-first notes app for Android, Windows, macOS and the web.
End-to-end encrypted and zero-knowledge: the server stores ciphertext and never holds a key that opens it.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Drift](https://img.shields.io/badge/Drift-SQLite%20%2F%20WASM-1E88E5)](https://drift.simonbinder.eu)
[![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20RLS-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Web-blue)](#download)
[![Encryption](https://img.shields.io/badge/encryption-AES--256--GCM-4c1)](#security-model)

[**🌐 Live demo**](https://macgalaviz.github.io/isan/) · [**⬇️ Download**](#download) · [**📦 Deployment guide**](docs/DEPLOYMENT.md) · [**🗺️ Work plan**](docs/WORKPLAN.md)

</div>

---

## Why

Most notes apps encrypt "in transit and at rest" — which means the provider holds the key. I wanted the other thing:

- The **server can't read my notes**, even if someone dumps the database
- It still **works with no connection**, and syncs when there is one
- The same notes on **phone, desktop and browser**
- A **lock on individual notes**, for the ones you don't want visible over your shoulder

So I built it.

## Features

- **Offline-first** — every note is written to a local SQLite database first; the cloud is a replica, not the source of truth
- **End-to-end encryption** — titles and content are encrypted with AES-256-GCM before they touch the network ([details](#security-model))
- **Multi-device** — sign in anywhere and your key follows you, unwrapped locally with your password
- **Recovery phrase** — a BIP39 12-word phrase opens your notes if you forget your password; without it, nobody can
- **Per-note lock** — hide a note's content behind its own password, recoverable with your account password
- **Three note types** — plain text, markdown with a rendered view, or a list of copyable fields ([details](#note-types))
- **Copy anything** — the whole note in one tap, or a single line at a time
- **Sync that retries** — edits and deletions made offline are queued and replayed instead of being silently lost
- **Local search** — filtering happens in memory over decrypted notes, because the server only has ciphertext to match against
- **Automatic updates** — desktop and mobile builds check a published `version.json` and offer the new release
- **Dark / light** — follows the system theme

## Security model

The threat model is: *the server, a database dump, and anyone holding your device without your password.* Once you sign in on a device you trust, everything is decrypted and the encryption is invisible.

| What | Where it lives | Encrypted? |
|---|---|---|
| Note title | Local SQLite + Supabase | ✅ AES-256-GCM |
| Note content | Local SQLite + Supabase | ✅ AES-256-GCM |
| Master key | Supabase `user_keys` | ✅ Wrapped twice: under your password and under your recovery phrase |
| Master key (cache) | OS secure storage | ⚠️ Plaintext, so the app opens offline — the OS keystore is the barrier |
| Note lock password | Local + Supabase | ✅ Salted PBKDF2 hash, never the password itself |
| Timestamps, sync flags, note type | Local + Supabase | ❌ Metadata, in the clear |

**How the key works.** A random 256-bit master key encrypts your notes. That key is never uploaded raw: it is wrapped with a key derived from your password (PBKDF2-HMAC-SHA256, 150 000 iterations, random salt) and, separately, with one derived from your recovery phrase. Supabase stores only those two ciphertexts. Signing in downloads the wrapped key and unwraps it locally — your password never leaves the device either.

**What this costs you.** Lose both your password and your recovery phrase and the notes are unrecoverable. That is the point.

**What the per-note lock is not.** It is an interface gate over a note that is already encrypted with your master key, not a second layer of cryptography. It stops a glance at an unlocked device; it does not stop someone who has your account password. The trade-off is deliberate: a lock that is genuinely unbreakable is also genuinely unrecoverable.

## Note types

Pick a type from the editor menu. Switching type never re-encrypts the note.

| Type | What it does |
|---|---|
| **Plain text** | What you type is what you see |
| **Markdown** | Write markdown, toggle to a rendered, selectable view |
| **Copyable fields** | Every line becomes a row with its own copy button — for the notes that are really a pile of values you keep pasting somewhere |

## Tech stack

Flutter · Drift (SQLite, WASM + OPFS on the web) · Supabase (Postgres, Auth, Row Level Security) · `cryptography` (AES-GCM, PBKDF2) · `bip39` · `flutter_secure_storage`

## Download

Grab a build from the [Releases](https://github.com/MACGalaviz/isan/releases) page, or use the [web version](https://macgalaviz.github.io/isan/) — nothing to install, same encryption.

- **Android** — `.apk`
- **Windows** — Inno Setup installer
- **macOS** — unsigned, so the first launch needs **right-click → Open**

## Quick start

Requires the Flutter SDK (Dart 3.10+).

```bash
git clone https://github.com/MACGalaviz/isan.git
cd isan
flutter pub get
flutter run
```

That runs against this project's Supabase instance. To point it at your own:

1. Create a Supabase project.
2. Run the SQL files in [`db/`](db), in order, in the Supabase SQL editor:
   - `supabase_setup.sql` — the `notes` table and its RLS policies
   - `supabase_encryption.sql` — the `user_keys` table and the encryption columns
   - `supabase_note_types.sql` — the `note_type` column
3. Replace `url` and `anonKey` in `lib/main.dart` with your project's URL and publishable key.

The publishable key is safe to ship: every table is behind Row Level Security, and the rows it can reach hold ciphertext anyway.

## Building

```bash
flutter build apk --release        # Android
flutter build windows --release    # Windows  (then installers/isan_script.iss)
flutter build macos --release      # macOS    (needs a Mac)
flutter build web --release        # Web
```

Signing, installers and the auto-update flow are documented in [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

After changing `lib/db/database.dart`, regenerate the Drift code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Tests

```bash
flutter test
```

21 tests over the crypto: AES round-trips, tampering and wrong keys, key derivation, the session key, the two-slot master-key scheme, and the per-note lock hash. The sync layer is not covered — it needs Supabase and platform storage.

## Project layout

```
lib/
  db/            Drift schema and generated code
  models/        Note model and note types
  screens/       Home, editor, auth, profile, password reset
  services/
    security/    Key manager, derivation, encryption, session key, note lock
    ...          Database, Supabase, update checker
test/            Crypto and note-lock tests
db/              Supabase schema, idempotent, safe to re-run
docs/            Deployment guide and work plan
installers/      Inno Setup script for the Windows installer
```

## Status

Feature-complete on the platforms above. What is left is internal — central state management and tests for the sync layer — and it is tracked in the [work plan](docs/WORKPLAN.md).

iOS is not planned: distributing it needs a paid Apple Developer account, and this app does not justify one.

## License

[MIT](LICENSE) © Miguel Cabañas

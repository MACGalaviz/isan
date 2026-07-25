-- ===================================================
-- ISAN – Encryption schema (E2E)
-- Adds user_keys + aligns notes table with client code.
-- Idempotent: safe to re-run.
-- ===================================================

-- ---------------------------------------------------
-- 1. Align 'notes' with the client model
-- ---------------------------------------------------
alter table public.notes
  add column if not exists created_at timestamptz not null default now();

alter table public.notes
  add column if not exists is_locked boolean not null default false;

alter table public.notes
  add column if not exists password_hash text;

-- ---------------------------------------------------
-- 2. 'user_keys' – stores the UMK wrapped under
--    password-derived and recovery-derived keys.
--    Server only ever sees encrypted blobs (zero-knowledge).
-- ---------------------------------------------------
create table if not exists public.user_keys (
  user_id uuid primary key references auth.users(id) on delete cascade,
  encrypted_umk_password text not null,
  encrypted_umk_recovery text not null,
  salt_password text not null,
  salt_recovery text not null,
  updated_at timestamptz not null default now()
);

alter table public.user_keys enable row level security;

-- 3. RLS: a user can only read/write their own key row
drop policy if exists "Users manage own keys" on public.user_keys;
create policy "Users manage own keys"
on public.user_keys for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

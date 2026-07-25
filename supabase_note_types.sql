-- ===================================================
-- ISAN – Note types
-- Adds the note_type column used by plain / markdown /
-- copyable-field notes.
-- Idempotent: safe to re-run.
--
-- Run this BEFORE using a client build that sends
-- note_type, otherwise every upload fails on the
-- unknown column and notes stay pending.
-- ===================================================

alter table public.notes
  add column if not exists note_type text not null default 'plain';

-- Presentation only, never content: an unknown value must not break the
-- client, which falls back to 'plain'.
alter table public.notes
  drop constraint if exists notes_note_type_check;

alter table public.notes
  add constraint notes_note_type_check
  check (note_type in ('plain', 'markdown', 'fields'));

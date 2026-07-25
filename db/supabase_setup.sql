-- ===================================================
-- STEP 1: TABLE CREATION AND DEV POLICY (PHASE 4)
-- ===================================================

-- 1. Create the 'notes' table
-- We use UUID as the primary key to match our local UUID generation
create table public.notes (
  id uuid primary key default gen_random_uuid(),
  
  -- user_id: Ideally links to auth.users, but for now we'll store "local_user"
  user_id text not null, 
  
  title text,
  content text,
  
  -- timestamptz: Crucial for synchronization logic
  updated_at timestamp with time zone default now()
);

-- 2. Enable Row Level Security (RLS)
-- Supabase requires this for security best practices
alter table public.notes enable row level security;

-- 3. Create an OPEN Policy (Temporary)
-- This allows reading/writing without logging in (Phase 4.1)
-- We will restrict this to "authenticated users only" in Phase 4.2
create policy "Enable all access for dev" 
on public.notes 
for all 
using (true) 
with check (true);


-- ===================================================
-- STEP 2: ACTUAL SECURITY RULES (PHASE 5)
-- ===================================================

-- 1. Enable RLS security on 'notes' table (Redundant but safe)
alter table notes enable row level security;

-- 2. Policy: View only my own notes (Corrected with ::text)
create policy "Users can view own notes"
on notes for select
using (auth.uid()::text = user_id);

-- 3. Policy: Create notes only with my ID (Corrected with ::text)
create policy "Users can insert own notes"
on notes for insert
with check (auth.uid()::text = user_id);

-- 4. Policy: Edit only my own notes (Corrected with ::text)
create policy "Users can update own notes"
on notes for update
using (auth.uid()::text = user_id);

-- 5. Policy: Delete only my own notes (Corrected with ::text)
create policy "Users can delete own notes"
on notes for delete
using (auth.uid()::text = user_id);


-- ===================================================
-- STEP 3: FINAL CLEANUP (SECURITY)
-- ===================================================

drop policy if exists "Enable all access for dev" on notes;

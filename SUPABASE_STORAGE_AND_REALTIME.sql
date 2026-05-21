-- XmeChat: Storage buckets + Realtime publication helper
-- Run AFTER you run supabase_schema.sql
--
-- NOTE:
-- - Buckets are marked PUBLIC because the app uses getPublicUrl().
-- - This runs in Supabase SQL Editor (service role), so it can manage storage.

-- ------------------------------------------------------------
-- 1) Create required Storage buckets (id == name)
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('chat-media', 'chat-media', true),
  ('status-media', 'status-media', true),
  ('group-icons', 'group-icons', true),
  ('documents', 'documents', true),
  ('voice-notes', 'voice-notes', true)
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 2) Storage policies (simple + safe defaults)
-- ------------------------------------------------------------
-- Public read for ALL objects (because buckets are public URLs)
do $$
begin
  create policy "public read storage" on storage.objects
    for select using (true);
exception when duplicate_object then
  null;
end;
$$;

-- Authenticated users can upload to these buckets
do $$
begin
  create policy "auth upload storage" on storage.objects
    for insert
    with check (
      auth.role() = 'authenticated'
      and bucket_id in ('avatars','chat-media','status-media','group-icons','documents','voice-notes')
    );
exception when duplicate_object then
  null;
end;
$$;

-- Authenticated users can update/delete their own uploaded objects
do $$
begin
  create policy "auth update own storage" on storage.objects
    for update
    using (auth.uid() = owner)
    with check (auth.uid() = owner);
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  create policy "auth delete own storage" on storage.objects
    for delete
    using (auth.uid() = owner);
exception when duplicate_object then
  null;
end;
$$;

-- ------------------------------------------------------------
-- 3) Enable Realtime for tables used by .stream(...)
-- ------------------------------------------------------------
-- Supabase Realtime uses the publication "supabase_realtime".
-- This block adds tables only if they are not already in publication.
do $$
declare
  target_pubname text := 'supabase_realtime';
begin
  if not exists (select 1 from pg_publication where pubname = target_pubname) then
    raise notice 'Publication supabase_realtime not found (this is unusual in Supabase).';
    return;
  end if;

  -- conversations (1:1)
  if not exists (
    select 1
    from pg_publication_rel pr
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where pr.prpubid = (select oid from pg_publication where pubname = target_pubname)
      and n.nspname = 'public' and c.relname = 'conversations'
  ) then
    execute 'alter publication supabase_realtime add table public.conversations';
  end if;

  -- messages
  if not exists (
    select 1
    from pg_publication_rel pr
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where pr.prpubid = (select oid from pg_publication where pubname = target_pubname)
      and n.nspname = 'public' and c.relname = 'messages'
  ) then
    execute 'alter publication supabase_realtime add table public.messages';
  end if;

  -- group_messages
  if not exists (
    select 1
    from pg_publication_rel pr
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where pr.prpubid = (select oid from pg_publication where pubname = target_pubname)
      and n.nspname = 'public' and c.relname = 'group_messages'
  ) then
    execute 'alter publication supabase_realtime add table public.group_messages';
  end if;

  -- calls (incoming call ring + status updates)
  if not exists (
    select 1
    from pg_publication_rel pr
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where pr.prpubid = (select oid from pg_publication where pubname = target_pubname)
      and n.nspname = 'public' and c.relname = 'calls'
  ) then
    execute 'alter publication supabase_realtime add table public.calls';
  end if;
end;
$$;



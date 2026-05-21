-- ------------------------------------------------------------
--  XMECHAT – Supabase All-In-One Schema & Configuration Setup
--  Run this whole script in the Supabase SQL editor.
-- ------------------------------------------------------------

-- Required extensions
create extension if not exists "uuid-ossp";

-- ----------------------------------------------------------------
-- 1. DROP EXISTING TABLES & TRIGGERS TO ENSURE A CLEAN STATE
-- ----------------------------------------------------------------
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user() cascade;
drop function if exists delete_expired_otps() cascade;

drop table if exists poll_votes cascade;
drop table if exists polls cascade;
drop table if exists starred_messages cascade;
drop table if exists blocked_users cascade;
drop table if exists ice_candidates cascade;
drop table if exists calls cascade;
drop table if exists status_views cascade;
drop table if exists statuses cascade;
drop table if exists group_message_reactions cascade;
drop table if exists group_message_reads cascade;
drop table if exists group_messages cascade;
drop table if exists group_members cascade;
drop table if exists groups cascade;
drop table if exists reactions cascade;
drop table if exists messages cascade;
drop table if exists conversations cascade;
drop table if exists saved_contacts cascade;
drop table if exists otp_codes cascade;
drop table if exists users cascade;

-- ----------------------------------------------------------------
-- 2. CREATE TABLES
-- ----------------------------------------------------------------

-- Users Table
create table users (
    id            uuid primary key default uuid_generate_v4(),
    email         varchar not null unique,
    name          varchar not null,
    phone_info    varchar,
    avatar_url    varchar,
    bio           text,
    last_seen     timestamp with time zone default now(),
    is_online     boolean default false,
    push_token    varchar,
    is_private    boolean default false,
    created_at    timestamp with time zone default now()
);

create index idx_users_email on users(email);
create index idx_users_name on users(name);

-- Conversations Table (One-to-One Chat Sessions)
create table conversations (
    id                uuid primary key default uuid_generate_v4(),
    participant_1     uuid references users(id) on delete cascade,
    participant_2     uuid references users(id) on delete cascade,
    last_message      text,
    last_message_at   timestamp with time zone default now(),
    last_message_type varchar default 'text',
    created_at        timestamp with time zone default now()
);

create index idx_conversations_p1 on conversations(participant_1);
create index idx_conversations_p2 on conversations(participant_2);

-- Messages Table (Private Chats)
create table messages (
    id               uuid primary key default uuid_generate_v4(),
    chat_id          uuid references conversations(id) on delete cascade,
    sender_id        uuid references users(id) on delete cascade,
    receiver_id      uuid references users(id) on delete cascade,
    text             text,
    type             varchar default 'text',
    media_url        varchar,
    file_name        varchar,
    file_size        bigint default 0,
    duration         int default 0,
    reply_to         uuid,
    reply_preview    text,
    is_forwarded     boolean default false,
    is_starred       boolean default false,
    is_view_once     boolean default false,
    view_once_opened boolean default false,
    status           varchar default 'sent',
    seen_at          timestamp with time zone,
    delivered_at     timestamp with time zone,
    latitude         double precision,
    longitude        double precision,
    location_name    varchar,
    contact_name     varchar,
    contact_phone    varchar,
    deleted_for_sender    boolean default false,
    deleted_for_receiver  boolean default false,
    deleted_for_everyone  boolean default false,
    created_at       timestamp with time zone default now()
);

create index idx_messages_chat on messages(chat_id);
create index idx_messages_sender on messages(sender_id);
create index idx_messages_receiver on messages(receiver_id);
create index idx_messages_created on messages(created_at);

-- Reactions Table (Private Chat Reactions)
create table reactions (
    id         uuid primary key default uuid_generate_v4(),
    message_id uuid references messages(id) on delete cascade,
    user_id    uuid references users(id) on delete cascade,
    emoji      varchar not null,
    created_at timestamp with time zone default now()
);

create index idx_reactions_message on reactions(message_id);
create index idx_reactions_user on reactions(user_id);

-- Groups Table
create table groups (
    id                uuid primary key default uuid_generate_v4(),
    name              varchar not null,
    description       text,
    icon_url          varchar,
    created_by        uuid references users(id) on delete cascade,
    last_message      text,
    last_message_at   timestamp with time zone default now(),
    last_message_type varchar default 'text',
    created_at        timestamp with time zone default now()
);

create index idx_groups_created_by on groups(created_by);
create index idx_groups_name on groups(name);

-- Group Members Table
create table group_members (
    id        uuid primary key default uuid_generate_v4(),
    group_id  uuid references groups(id) on delete cascade,
    user_id   uuid references users(id) on delete cascade,
    is_admin  boolean default false,
    joined_at timestamp with time zone default now()
);

create index idx_group_members_group on group_members(group_id);
create index idx_group_members_user on group_members(user_id);

-- Group Messages Table
create table group_messages (
    id               uuid primary key default uuid_generate_v4(),
    group_id         uuid references groups(id) on delete cascade,
    sender_id        uuid references users(id) on delete cascade,
    text             text,
    type             varchar default 'text',
    media_url        varchar,
    file_name        varchar,
    file_size        bigint default 0,
    duration         int default 0,
    reply_to         uuid,
    reply_preview    text,
    reply_sender_name varchar,
    is_forwarded     boolean default false,
    is_starred       boolean default false,
    mentions         jsonb default '[]'::jsonb,
    deleted_for_everyone boolean default false,
    created_at       timestamp with time zone default now()
);

create index idx_group_msg_group on group_messages(group_id);
create index idx_group_msg_sender on group_messages(sender_id);
create index idx_group_msg_created on group_messages(created_at);

-- Group Message Reads Table
create table group_message_reads (
    id             uuid primary key default uuid_generate_v4(),
    message_id     uuid references group_messages(id) on delete cascade,
    user_id        uuid references users(id) on delete cascade,
    read_at        timestamp with time zone default now()
);

create index idx_gmr_message on group_message_reads(message_id);
create index idx_gmr_user on group_message_reads(user_id);

-- Group Message Reactions Table
create table group_message_reactions (
    id         uuid primary key default uuid_generate_v4(),
    message_id uuid references group_messages(id) on delete cascade,
    user_id    uuid references users(id) on delete cascade,
    emoji      varchar not null,
    created_at timestamp with time zone default now()
);

create index idx_gmr_react_message on group_message_reactions(message_id);
create index idx_gmr_react_user on group_message_reactions(user_id);

-- Statuses Table (WhatsApp-like Stories)
create table statuses (
    id          uuid primary key default uuid_generate_v4(),
    user_id     uuid references users(id) on delete cascade,
    content_url varchar,
    text        text,
    type        varchar default 'text',
    bg_color    varchar default '#075E54',
    expires_at  timestamp with time zone,
    created_at  timestamp with time zone default now()
);

create index idx_statuses_user on statuses(user_id);
create index idx_statuses_created on statuses(created_at);

-- Status Views Table
create table status_views (
    id          uuid primary key default uuid_generate_v4(),
    status_id   uuid references statuses(id) on delete cascade,
    viewer_id   uuid references users(id) on delete cascade,
    viewed_at   timestamp with time zone default now()
);

create index idx_status_views_status on status_views(status_id);
create index idx_status_views_viewer on status_views(viewer_id);
create unique index uniq_status_views on status_views(status_id, viewer_id);

-- Calls Table (WebRTC Voip Calls)
create table calls (
    id           uuid primary key default uuid_generate_v4(),
    caller_id    uuid references users(id) on delete cascade,
    receiver_id  uuid references users(id) on delete cascade,
    type         varchar default 'voice',
    status       varchar default 'ringing',
    sdp_offer    text,
    sdp_answer   text,
    started_at   timestamp with time zone default now(),
    connected_at timestamp with time zone,
    ended_at     timestamp with time zone,
    duration     int default 0,
    created_at   timestamp with time zone default now()
);

create index idx_calls_caller on calls(caller_id);
create index idx_calls_receiver on calls(receiver_id);
create index idx_calls_created on calls(created_at);

-- ICE Candidates Table (WebRTC Peer Discovery)
create table ice_candidates (
    id        uuid primary key default uuid_generate_v4(),
    call_id   uuid references calls(id) on delete cascade,
    candidate text not null,
    sdp_mid   varchar,
    sdp_mline_index int,
    created_at timestamp with time zone default now()
);

create index idx_ice_call on ice_candidates(call_id);

-- Blocked Users Table
create table blocked_users (
    id              uuid primary key default uuid_generate_v4(),
    user_id         uuid references users(id) on delete cascade,
    blocked_user_id uuid references users(id) on delete cascade,
    created_at      timestamp with time zone default now()
);

create unique index uniq_blocker_blocked on blocked_users(user_id, blocked_user_id);

-- Starred Messages Table
create table starred_messages (
    id          uuid primary key default uuid_generate_v4(),
    user_id     uuid references users(id) on delete cascade,
    message_id  uuid references messages(id) on delete cascade,
    created_at  timestamp with time zone default now()
);

create unique index uniq_starred on starred_messages(user_id, message_id);

-- Saved Contacts Table
create table saved_contacts (
    id          uuid primary key default uuid_generate_v4(),
    user_id     uuid references users(id) on delete cascade,
    contact_id  uuid references users(id) on delete cascade,
    nickname    varchar,
    created_at  timestamp with time zone default now()
);

create unique index uniq_user_contact on saved_contacts(user_id, contact_id);

-- Polls Table (Group Chats)
create table polls (
    id            uuid primary key default uuid_generate_v4(),
    group_id      uuid references groups(id) on delete cascade,
    created_by    uuid references users(id) on delete cascade,
    question      text not null,
    options       jsonb not null,
    allow_multiple boolean default false,
    created_at    timestamp with time zone default now()
);

create index idx_polls_group on polls(group_id);
create index idx_polls_creator on polls(created_by);

-- Poll Votes Table
create table poll_votes (
    id          uuid primary key default uuid_generate_v4(),
    poll_id     uuid references polls(id) on delete cascade,
    user_id     uuid references users(id) on delete cascade,
    option_index int not null,
    created_at  timestamp with time zone default now()
);

create unique index uniq_poll_user_option on poll_votes(poll_id, user_id, option_index);

-- OTP Codes Table (Verify and Resend)
create table otp_codes (
  id UUID default gen_random_uuid() primary key,
  email text not null,
  code text not null,
  expires_at timestamp with time zone not null,
  is_used boolean default false,
  created_at timestamp with time zone default now()
);

-- ----------------------------------------------------------------
-- 3. ENABLE ROW LEVEL SECURITY (RLS)
-- ----------------------------------------------------------------
alter table users enable row level security;
alter table conversations enable row level security;
alter table messages enable row level security;
alter table reactions enable row level security;
alter table groups enable row level security;
alter table group_members enable row level security;
alter table group_messages enable row level security;
alter table group_message_reads enable row level security;
alter table group_message_reactions enable row level security;
alter table statuses enable row level security;
alter table status_views enable row level security;
alter table calls enable row level security;
alter table ice_candidates enable row level security;
alter table blocked_users enable row level security;
alter table starred_messages enable row level security;
alter table saved_contacts enable row level security;
alter table polls enable row level security;
alter table poll_votes enable row level security;
alter table otp_codes enable row level security;

-- ----------------------------------------------------------------
-- 4. POLICIES
-- ----------------------------------------------------------------

-- Users policies
create policy "public read users" on users for select using (true);
create policy "owner update users" on users for update using (auth.uid() = id);
create policy "users can insert themselves" on users for insert with check (auth.uid() = id);

-- Conversations (1:1) policies
create policy "conversation participants can read" on conversations for select
  using (auth.uid() = participant_1 or auth.uid() = participant_2);
create policy "conversation participants can insert" on conversations for insert
  with check (auth.uid() = participant_1 or auth.uid() = participant_2);
create policy "conversation participants can update" on conversations for update
  using (auth.uid() = participant_1 or auth.uid() = participant_2);

-- Messages policies
create policy "message participants read" on messages for select using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "message participants insert" on messages for insert with check (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "message participants update" on messages for update using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Reactions policies
create policy "reaction read" on reactions for select using (true);
create policy "reaction insert" on reactions for insert with check (auth.uid() = user_id);
create policy "reaction delete" on reactions for delete using (auth.uid() = user_id);

-- Groups policies
create policy "group read public" on groups for select using (true);
create policy "group insert" on groups for insert with check (auth.uid() = created_by);
create policy "group update" on groups for update using (auth.uid() = created_by);
create policy "group delete" on groups for delete using (auth.uid() = created_by);

-- Group Members policies
create policy "group members read" on group_members for select using (true);
create policy "group members insert" on group_members for insert with check (true);
create policy "group members delete" on group_members for delete using (true);

-- Group Messages policies
create policy "group message read" on group_messages for select using (true);
create policy "group message insert" on group_messages for insert with check (true);
create policy "group message update" on group_messages for update using (true);

-- Statuses policies
create policy "status read public" on statuses for select using (true);
create policy "status owner write" on statuses for all using (auth.uid() = user_id);

-- Status Views policies
create policy "status view insert" on status_views for insert with check (auth.uid() = viewer_id);
create policy "status view read" on status_views for select using (true);

-- Calls policies
create policy "call participants read" on calls for select using (auth.uid() = caller_id or auth.uid() = receiver_id);
create policy "call participants insert" on calls for insert with check (auth.uid() = caller_id or auth.uid() = receiver_id);
create policy "call participants update" on calls for update using (auth.uid() = caller_id or auth.uid() = receiver_id);

-- ICE Candidates policies
create policy "ice read" on ice_candidates for select using (true);
create policy "ice insert" on ice_candidates for insert with check (true);

-- Group message reads policies
create policy "group reads read" on group_message_reads for select using (true);
create policy "group reads insert" on group_message_reads for insert with check (auth.uid() = user_id);
create policy "group reads upsert" on group_message_reads for update using (auth.uid() = user_id);

-- Group message reactions policies
create policy "group reactions read" on group_message_reactions for select using (true);
create policy "group reactions insert" on group_message_reactions for insert with check (auth.uid() = user_id);
create policy "group reactions delete" on group_message_reactions for delete using (auth.uid() = user_id);

-- Blocked Users policies
create policy "blocked read own" on blocked_users for select using (auth.uid() = user_id);
create policy "blocked insert own" on blocked_users for insert with check (auth.uid() = user_id);
create policy "blocked delete own" on blocked_users for delete using (auth.uid() = user_id);

-- Starred Messages policies
create policy "starred read own" on starred_messages for select using (auth.uid() = user_id);
create policy "starred insert own" on starred_messages for insert with check (auth.uid() = user_id);
create policy "starred delete own" on starred_messages for delete using (auth.uid() = user_id);

-- Saved Contacts policies
create policy "saved contacts read own" on saved_contacts for select using (auth.uid() = user_id);
create policy "saved contacts insert own" on saved_contacts for insert with check (auth.uid() = user_id);
create policy "saved contacts update own" on saved_contacts for update using (auth.uid() = user_id);
create policy "saved contacts delete own" on saved_contacts for delete using (auth.uid() = user_id);

-- Polls policies
create policy "poll read members" on polls for select using (true);
create policy "poll creator write" on polls for all using (auth.uid() = created_by);

-- Poll Votes policies
create policy "poll vote insert" on poll_votes for insert with check (auth.uid() = user_id);
create policy "poll vote read" on poll_votes for select using (true);

-- OTP Codes policies
create policy "Anyone can insert otp" on otp_codes for insert with check (true);
create policy "Anyone can read own otp" on otp_codes for select using (true);
create policy "Anyone can update otp" on otp_codes for update using (true);

-- ----------------------------------------------------------------
-- 5. TRIGGERS & PROCEDURES (Auth Sync & Helpers)
-- ----------------------------------------------------------------

-- Trigger to automatically create a profile in public.users when an account is created in auth.users
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.users (id, email, name, phone_info, bio, avatar_url)
  values (
    new.id, 
    new.email, 
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'phone_info', ''),
    'Friends Forever',
    ''
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Auto delete expired OTP codes helper
create or replace function delete_expired_otps()
returns void as $$
begin
  delete from public.otp_codes 
  where expires_at < now() or is_used = true;
end;
$$ language plpgsql;

-- ----------------------------------------------------------------
-- 6. CREATE STORAGE BUCKETS (avatars, chat-media, etc.)
-- ----------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('chat-media', 'chat-media', true),
  ('status-media', 'status-media', true),
  ('group-icons', 'group-icons', true),
  ('documents', 'documents', true),
  ('voice-notes', 'voice-notes', true)
on conflict (id) do nothing;

-- ----------------------------------------------------------------
-- 7. STORAGE POLICIES
-- ----------------------------------------------------------------
-- Public read for ALL objects (buckets are public)
do $$
begin
  create policy "public read storage" on storage.objects
    for select using (true);
exception when duplicate_object then
  null;
end $$;

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
end $$;

-- Authenticated users can update/delete their own uploaded objects
do $$
begin
  create policy "auth update own storage" on storage.objects
    for update
    using (auth.uid() = owner)
    with check (auth.uid() = owner);
exception when duplicate_object then
  null;
end $$;

do $$
begin
  create policy "auth delete own storage" on storage.objects
    for delete
    using (auth.uid() = owner);
exception when duplicate_object then
  null;
end $$;

-- ----------------------------------------------------------------
-- 8. ENABLE REALTIME ON STREAMED TABLES
-- ----------------------------------------------------------------
do $$
declare
  target_pubname text := 'supabase_realtime';
begin
  if not exists (select 1 from pg_publication where pubname = target_pubname) then
    raise notice 'Publication supabase_realtime not found.';
    return;
  end if;

  -- conversations
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

  -- calls
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
end $$;

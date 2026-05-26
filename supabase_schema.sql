-- ============================================================
-- XmeChat Complete Supabase Schema
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- 0. Extensions
create extension if not exists "pgcrypto";

-- 1. Users table (syncs with Supabase Auth)
create table if not exists public.users (
  id          text primary key,
  email       text not null,
  name        text not null default '',
  phone_info  text not null default '',
  avatar_url  text not null default '',
  bio         text not not null default '',
  last_seen   timestamptz not null default now(),
  is_online   boolean not null default false,
  push_token  text not null default '',
  is_private  boolean not null default false,
  public_key  text,
  created_at  timestamptz not null default now()
);
alter table public.users enable row level security;

create policy "Users can read all profiles"
  on public.users for select
  using (true);

create policy "Users can insert their own profile"
  on public.users for insert
  with check (id = auth.uid()::text);

create policy "Users can update their own profile"
  on public.users for update
  using (id = auth.uid()::text);

-- 2. Conversations (1:1 chats)
create table if not exists public.conversations (
  id                uuid primary key default gen_random_uuid(),
  participant_1     text not null references public.users(id) on delete cascade,
  participant_2     text not null references public.users(id) on delete cascade,
  last_message      text not null default '',
  last_message_at   timestamptz not null default now(),
  last_message_type text not null default 'text',
  disappear_timer   int not null default 0,
  created_at        timestamptz not null default now()
);
alter table public.conversations enable row level security;

create policy "Participants can read conversation"
  on public.conversations for select
  using (participant_1 = auth.uid()::text or participant_2 = auth.uid()::text);

create policy "Participants can insert"
  on public.conversations for insert
  with check (participant_1 = auth.uid()::text or participant_2 = auth.uid()::text);

create policy "Participants can update"
  on public.conversations for update
  using (participant_1 = auth.uid()::text or participant_2 = auth.uid()::text);

-- 3. Messages
create table if not exists public.messages (
  id                  uuid primary key default gen_random_uuid(),
  chat_id             uuid references public.conversations(id) on delete cascade,
  group_id            uuid,
  sender_id           text not null references public.users(id) on delete cascade,
  receiver_id         text references public.users(id) on delete cascade,
  text                text not null default '',
  type                text not null default 'text',
  media_url           text not null default '',
  file_name           text not null default '',
  file_size           int not null default 0,
  duration            int not null default 0,
  reply_to            uuid,
  reply_preview       text not null default '',
  is_forwarded        boolean not null default false,
  is_view_once        boolean not null default false,
  view_once_opened    boolean not null default false,
  status              text not null default 'sent',
  seen_at             timestamptz,
  delivered_at        timestamptz,
  latitude            float,
  longitude           float,
  location_name       text not null default '',
  contact_name        text not null default '',
  contact_phone       text not null default '',
  deleted_for_sender  boolean not null default false,
  deleted_for_receiver boolean not null default false,
  deleted_for_everyone boolean not null default false,
  created_at          timestamptz not null default now()
);
alter table public.messages enable row level security;

create policy "Users can read messages they're involved in"
  on public.messages for select
  using (sender_id = auth.uid()::text or receiver_id = auth.uid()::text);

create policy "Users can insert messages"
  on public.messages for insert
  with check (sender_id = auth.uid()::text);

create policy "Users can update their own messages"
  on public.messages for update
  using (sender_id = auth.uid()::text or receiver_id = auth.uid()::text);

-- 4. Reactions
create table if not exists public.reactions (
  id         uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id    text not null references public.users(id) on delete cascade,
  emoji      text not null,
  created_at timestamptz not null default now(),
  unique (message_id, user_id)
);
alter table public.reactions enable row level security;

create policy "Users can read reactions on their messages"
  on public.reactions for select
  using (true);

create policy "Users can manage their own reactions"
  on public.reactions for insert
  with check (user_id = auth.uid()::text);

create policy "Users can delete their own reactions"
  on public.reactions for delete
  using (user_id = auth.uid()::text);

-- 5. Starred Messages
create table if not exists public.starred_messages (
  id         uuid primary key default gen_random_uuid(),
  user_id    text not null references public.users(id) on delete cascade,
  message_id uuid not null references public.messages(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, message_id)
);
alter table public.starred_messages enable row level security;

create policy "Users can manage their own starred messages"
  on public.starred_messages for all
  using (user_id = auth.uid()::text);

-- 6. Blocked Users
create table if not exists public.blocked_users (
  id             uuid primary key default gen_random_uuid(),
  user_id        text not null references public.users(id) on delete cascade,
  blocked_user_id text not null references public.users(id) on delete cascade,
  created_at     timestamptz not null default now(),
  unique (user_id, blocked_user_id)
);
alter table public.blocked_users enable row level security;

create policy "Users can manage their own block list"
  on public.blocked_users for all
  using (user_id = auth.uid()::text);

-- 7. Groups
create table if not exists public.groups (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  description       text not null default '',
  icon_url          text not null default '',
  created_by        text not null references public.users(id) on delete cascade,
  last_message      text not null default '',
  last_message_at   timestamptz not null default now(),
  last_message_type text not null default 'text',
  created_at        timestamptz not null default now()
);
alter table public.groups enable row level security;

create policy "Members can read groups"
  on public.groups for select
  using (exists (
    select 1 from public.group_members where group_id = id and user_id = auth.uid()::text
  ));

create policy "Creator can manage group"
  on public.groups for insert
  with check (created_by = auth.uid()::text);

create policy "Creator can update group"
  on public.groups for update
  using (created_by = auth.uid()::text);

-- 8. Group Members
create table if not exists public.group_members (
  id        uuid primary key default gen_random_uuid(),
  group_id  uuid not null references public.groups(id) on delete cascade,
  user_id   text not null references public.users(id) on delete cascade,
  is_admin  boolean not null default false,
  joined_at timestamptz not null default now(),
  unique (group_id, user_id)
);
alter table public.group_members enable row level security;

create policy "Members can read group members"
  on public.group_members for select
  using (true);

create policy "Members can insert"
  on public.group_members for insert
  with check (user_id = auth.uid()::text);

-- 9. Group Messages
create table if not exists public.group_messages (
  id                uuid primary key default gen_random_uuid(),
  group_id          uuid not null references public.groups(id) on delete cascade,
  sender_id         text not null references public.users(id) on delete cascade,
  text              text not null default '',
  type              text not null default 'text',
  media_url         text not null default '',
  file_name         text not null default '',
  duration          int,
  file_size         int,
  reply_to          uuid,
  reply_preview     text not null default '',
  reply_sender_name text not null default '',
  is_forwarded      boolean not null default false,
  is_starred        boolean not null default false,
  mentions          text[] not null default '{}',
  deleted_for_everyone boolean not null default false,
  created_at        timestamptz not null default now()
);
alter table public.group_messages enable row level security;

create policy "Members can read group messages"
  on public.group_messages for select
  using (exists (
    select 1 from public.group_members where group_id = group_messages.group_id and user_id = auth.uid()::text
  ));

create policy "Members can send messages"
  on public.group_messages for insert
  with check (exists (
    select 1 from public.group_members where group_id = group_messages.group_id and user_id = auth.uid()::text
  ));

-- 10. Group Message Reads
create table if not exists public.group_message_reads (
  id         uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.group_messages(id) on delete cascade,
  user_id    text not null references public.users(id) on delete cascade,
  read_at    timestamptz not null default now(),
  unique (message_id, user_id)
);
alter table public.group_message_reads enable row level security;

create policy "Members can read/manage reads"
  on public.group_message_reads for all
  using (user_id = auth.uid()::text);

-- 11. Statuses
create table if not exists public.statuses (
  id          uuid primary key default gen_random_uuid(),
  user_id     text not null references public.users(id) on delete cascade,
  content_url text not null default '',
  text        text not null default '',
  type        text not null default 'text',
  bg_color    text not null default '#075E54',
  expires_at  timestamptz not null default now() + interval '24 hours',
  created_at  timestamptz not null default now()
);
alter table public.statuses enable row level security;

create policy "Users can read statuses"
  on public.statuses for select
  using (true);

create policy "Users can post their own statuses"
  on public.statuses for insert
  with check (user_id = auth.uid()::text);

create policy "Users can delete their own statuses"
  on public.statuses for delete
  using (user_id = auth.uid()::text);

-- 12. Status Views
create table if not exists public.status_views (
  id        uuid primary key default gen_random_uuid(),
  status_id uuid not null references public.statuses(id) on delete cascade,
  viewer_id text not null references public.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  unique (status_id, viewer_id)
);
alter table public.status_views enable row level security;

create policy "Status owners can see views"
  on public.status_views for select
  using (exists (
    select 1 from public.statuses where id = status_id and user_id = auth.uid()::text
  ));

create policy "Viewers can insert"
  on public.status_views for insert
  with check (viewer_id = auth.uid()::text);

-- 13. Calls
create table if not exists public.calls (
  id          uuid primary key default gen_random_uuid(),
  caller_id   text not null references public.users(id) on delete cascade,
  receiver_id text not null references public.users(id) on delete cascade,
  type        text not null default 'voice',
  status      text not null default 'ringing',
  sdp_offer   text not null default '',
  sdp_answer  text not null default '',
  started_at  timestamptz not null default now(),
  connected_at timestamptz,
  ended_at    timestamptz,
  duration    int not null default 0,
  created_at  timestamptz not null default now()
);
alter table public.calls enable row level security;

create policy "Call participants can read"
  on public.calls for select
  using (caller_id = auth.uid()::text or receiver_id = auth.uid()::text);

create policy "Call participants can insert"
  on public.calls for insert
  with check (caller_id = auth.uid()::text);

create policy "Call participants can update"
  on public.calls for update
  using (caller_id = auth.uid()::text or receiver_id = auth.uid()::text);

-- 14. ICE Candidates (WebRTC)
create table if not exists public.ice_candidates (
  id        uuid primary key default gen_random_uuid(),
  call_id   uuid not null references public.calls(id) on delete cascade,
  user_id   text not null references public.users(id) on delete cascade,
  candidate text not null,
  created_at timestamptz not null default now()
);
alter table public.ice_candidates enable row level security;

create policy "Call participants can read ICE"
  on public.ice_candidates for select
  using (true);

create policy "Participants can insert ICE"
  on public.ice_candidates for insert
  with check (user_id = auth.uid()::text);

-- 15. Polls
create table if not exists public.polls (
  id             uuid primary key default gen_random_uuid(),
  group_id       uuid not null references public.groups(id) on delete cascade,
  created_by     text not null references public.users(id) on delete cascade,
  question       text not null,
  options        text[] not null default '{}',
  allow_multiple boolean not null default false,
  created_at     timestamptz not null default now()
);
alter table public.polls enable row level security;

create policy "Group members can read polls"
  on public.polls for select
  using (exists (
    select 1 from public.group_members where group_id = polls.group_id and user_id = auth.uid()::text
  ));

-- 16. Poll Votes
create table if not exists public.poll_votes (
  id         uuid primary key default gen_random_uuid(),
  poll_id    uuid not null references public.polls(id) on delete cascade,
  user_id    text not null references public.users(id) on delete cascade,
  option_idx int not null,
  created_at timestamptz not null default now(),
  unique (poll_id, user_id)
);
alter table public.poll_votes enable row level security;

create policy "Group members can vote"
  on public.poll_votes for all
  using (user_id = auth.uid()::text);

-- 17. Broadcast Lists
create table if not exists public.broadcast_lists (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_by text not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.broadcast_lists enable row level security;

create policy "Creator can manage broadcast lists"
  on public.broadcast_lists for all
  using (created_by = auth.uid()::text);

-- 18. Broadcast List Members
create table if not exists public.broadcast_list_members (
  id        uuid primary key default gen_random_uuid(),
  list_id   uuid not null references public.broadcast_lists(id) on delete cascade,
  user_id   text not null references public.users(id) on delete cascade,
  unique (list_id, user_id)
);
alter table public.broadcast_list_members enable row level security;

create policy "List creator can manage members"
  on public.broadcast_list_members for all
  using (exists (
    select 1 from public.broadcast_lists where id = list_id and created_by = auth.uid()::text
  ));

-- 19. Broadcast Messages
create table if not exists public.broadcast_messages (
  id        uuid primary key default gen_random_uuid(),
  list_id   uuid not null references public.broadcast_lists(id) on delete cascade,
  sender_id text not null references public.users(id) on delete cascade,
  text      text not null default '',
  type      text not null default 'text',
  media_url text not null default '',
  file_name text not null default '',
  created_at timestamptz not null default now()
);
alter table public.broadcast_messages enable row level security;

create policy "List creator can manage messages"
  on public.broadcast_messages for all
  using (exists (
    select 1 from public.broadcast_lists where id = list_id and created_by = auth.uid()::text
  ));

-- 20. Saved Contacts (nicknames)
create table if not exists public.saved_contacts (
  id         uuid primary key default gen_random_uuid(),
  user_id    text not null references public.users(id) on delete cascade,
  contact_id text not null references public.users(id) on delete cascade,
  nickname   text not null default '',
  unique (user_id, contact_id)
);
alter table public.saved_contacts enable row level security;

create policy "Users can manage their own contacts"
  on public.saved_contacts for all
  using (user_id = auth.uid()::text);

-- 21. Chat Settings (mute, archive, pin)
create table if not exists public.chat_settings (
  id       uuid primary key default gen_random_uuid(),
  user_id  text not null references public.users(id) on delete cascade,
  chat_id  uuid not null references public.conversations(id) on delete cascade,
  muted    boolean not null default false,
  archived boolean not null default false,
  pinned   boolean not null default false,
  unique (user_id, chat_id)
);
alter table public.chat_settings enable row level security;

create policy "Users can manage their own chat settings"
  on public.chat_settings for all
  using (user_id = auth.uid()::text);

-- 22. Favourite Chats
create table if not exists public.favourite_chats (
  id       uuid primary key default gen_random_uuid(),
  user_id  text not null references public.users(id) on delete cascade,
  chat_id  uuid not null references public.conversations(id) on delete cascade,
  unique (user_id, chat_id)
);
alter table public.favourite_chats enable row level security;

create policy "Users can manage their favourites"
  on public.favourite_chats for all
  using (user_id = auth.uid()::text);

-- 23. Status Privacy
create table if not exists public.status_privacy (
  id              uuid primary key default gen_random_uuid(),
  user_id         text not null references public.users(id) on delete cascade,
  allowed_user_id text not null references public.users(id) on delete cascade,
  unique (user_id, allowed_user_id)
);
alter table public.status_privacy enable row level security;

create policy "Users can manage their status privacy"
  on public.status_privacy for all
  using (user_id = auth.uid()::text);

-- 24. Reported Users
create table if not exists public.reported_users (
  id              uuid primary key default gen_random_uuid(),
  reporter_id     text not null references public.users(id) on delete cascade,
  reported_user_id text not null references public.users(id) on delete cascade,
  reason          text not null,
  created_at      timestamptz not null default now()
);
alter table public.reported_users enable row level security;

create policy "Users can report"
  on public.reported_users for insert
  with check (reporter_id = auth.uid()::text);

-- 25. Scheduled Calls
create table if not exists public.scheduled_calls (
  id           uuid primary key default gen_random_uuid(),
  caller_id    text not null references public.users(id) on delete cascade,
  receiver_id  text not null references public.users(id) on delete cascade,
  type         text not null default 'voice',
  scheduled_at timestamptz not null,
  created_at   timestamptz not null default now()
);
alter table public.scheduled_calls enable row level security;

create policy "Users can manage their scheduled calls"
  on public.scheduled_calls for all
  using (caller_id = auth.uid()::text or receiver_id = auth.uid()::text);

-- 26. Unread Markers (manual mark-as-unread)
create table if not exists public.unread_markers (
  id        uuid primary key default gen_random_uuid(),
  user_id   text not null references public.users(id) on delete cascade,
  chat_id   uuid not null references public.conversations(id) on delete cascade,
  marked_at timestamptz not null default now(),
  unique (user_id, chat_id)
);
alter table public.unread_markers enable row level security;

create policy "Users can manage their own unread markers"
  on public.unread_markers for all
  using (user_id = auth.uid()::text);

-- 27. User Settings
create table if not exists public.user_settings (
  id                    uuid primary key default gen_random_uuid(),
  user_id               text not null unique references public.users(id) on delete cascade,
  theme                 text not null default 'system',
  language              text not null default 'en',
  notification_enabled  boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
alter table public.user_settings enable row level security;

create policy "Users can manage their own settings"
  on public.user_settings for all
  using (user_id = auth.uid()::text);

-- ============================================================
-- Storage Buckets (create via Supabase Dashboard > Storage)
-- Or uncomment and run below:
-- ============================================================
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES
--   ('avatars', 'avatars', true),
--   ('chat-media', 'chat-media', true),
--   ('status-media', 'status-media', true),
--   ('group-icons', 'group-icons', true),
--   ('documents', 'documents', true),
--   ('voice-notes', 'voice-notes', true)
-- ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Helpful Indexes
-- ============================================================
create index if not exists idx_messages_chat_id on public.messages(chat_id);
create index if not exists idx_messages_sender_id on public.messages(sender_id);
create index if not exists idx_messages_created_at on public.messages(created_at);
create index if not exists idx_conversations_participant_1 on public.conversations(participant_1);
create index if not exists idx_conversations_participant_2 on public.conversations(participant_2);
create index if not exists idx_group_members_group_id on public.group_members(group_id);
create index if not exists idx_group_members_user_id on public.group_members(user_id);
create index if not exists idx_statuses_user_id on public.statuses(user_id);
create index if not exists idx_calls_caller_id on public.calls(caller_id);
create index if not exists idx_calls_receiver_id on public.calls(receiver_id);

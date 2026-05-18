-- ------------------------------------------------------------
--  XMECHAT – Supabase schema (Clean Setup)
--  Run this whole script in the Supabase SQL editor.
-- ------------------------------------------------------------

-- 1. DROP EXISTING TABLES TO ENSURE A CLEAN STATE
-- (This prevents errors if a table already existed with different columns)
DROP TABLE IF EXISTS poll_votes CASCADE;
DROP TABLE IF EXISTS polls CASCADE;
DROP TABLE IF EXISTS starred_messages CASCADE;
DROP TABLE IF EXISTS blocked_users CASCADE;
DROP TABLE IF EXISTS ice_candidates CASCADE;
DROP TABLE IF EXISTS calls CASCADE;
DROP TABLE IF EXISTS status_views CASCADE;
DROP TABLE IF EXISTS statuses CASCADE;
DROP TABLE IF EXISTS group_message_reactions CASCADE;
DROP TABLE IF EXISTS group_message_reads CASCADE;
DROP TABLE IF EXISTS group_messages CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
DROP TABLE IF EXISTS reactions CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS chats CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ----------------------------------------------------------------
-- 2. CREATE TABLES
-- ----------------------------------------------------------------

-- Users
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
    created_at    timestamp with time zone default now()
);

create index idx_users_email on users(email);
create index idx_users_name on users(name);

-- Chats (one‑to‑one)
create table chats (
    id                uuid primary key default uuid_generate_v4(),
    user1_id          uuid references users(id) on delete cascade,
    user2_id          uuid references users(id) on delete cascade,
    last_message      text,
    last_message_at   timestamp with time zone default now(),
    last_message_type varchar default 'text',
    created_at        timestamp with time zone default now()
);

create index idx_chats_user1 on chats(user1_id);
create index idx_chats_user2 on chats(user2_id);

-- Messages (private chats)
create table messages (
    id               uuid primary key default uuid_generate_v4(),
    chat_id          uuid references chats(id) on delete cascade,
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

-- Reactions
create table reactions (
    id         uuid primary key default uuid_generate_v4(),
    message_id uuid references messages(id) on delete cascade,
    user_id    uuid references users(id) on delete cascade,
    emoji      varchar not null,
    created_at timestamp with time zone default now()
);

create index idx_reactions_message on reactions(message_id);
create index idx_reactions_user on reactions(user_id);

-- Groups
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

-- Group members
create table group_members (
    id        uuid primary key default uuid_generate_v4(),
    group_id  uuid references groups(id) on delete cascade,
    user_id   uuid references users(id) on delete cascade,
    is_admin  boolean default false,
    joined_at timestamp with time zone default now()
);

create index idx_group_members_group on group_members(group_id);
create index idx_group_members_user on group_members(user_id);

-- Group messages
create table group_messages (
    id               uuid primary key default uuid_generate_v4(),
    group_id         uuid references groups(id) on delete cascade,
    sender_id        uuid references users(id) on delete cascade,
    text             text,
    type             varchar default 'text',
    media_url        varchar,
    file_name        varchar,
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

-- Group message reads
create table group_message_reads (
    id             uuid primary key default uuid_generate_v4(),
    message_id     uuid references group_messages(id) on delete cascade,
    user_id        uuid references users(id) on delete cascade,
    read_at        timestamp with time zone default now()
);

create index idx_gmr_message on group_message_reads(message_id);
create index idx_gmr_user on group_message_reads(user_id);

-- Group message reactions
create table group_message_reactions (
    id         uuid primary key default uuid_generate_v4(),
    message_id uuid references group_messages(id) on delete cascade,
    user_id    uuid references users(id) on delete cascade,
    emoji      varchar not null,
    created_at timestamp with time zone default now()
);

create index idx_gmr_react_message on group_message_reactions(message_id);
create index idx_gmr_react_user on group_message_reactions(user_id);

-- Statuses
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

-- Status views
create table status_views (
    id          uuid primary key default uuid_generate_v4(),
    status_id   uuid references statuses(id) on delete cascade,
    viewer_id   uuid references users(id) on delete cascade,
    viewed_at   timestamp with time zone default now()
);

create index idx_status_views_status on status_views(status_id);
create index idx_status_views_viewer on status_views(viewer_id);

-- Calls
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

-- ICE candidates
create table ice_candidates (
    id        uuid primary key default uuid_generate_v4(),
    call_id   uuid references calls(id) on delete cascade,
    candidate text not null,
    sdp_mid   varchar,
    sdp_mline_index int,
    created_at timestamp with time zone default now()
);

create index idx_ice_call on ice_candidates(call_id);

-- Blocked users
create table blocked_users (
    id          uuid primary key default uuid_generate_v4(),
    blocker_id  uuid references users(id) on delete cascade,
    blocked_id  uuid references users(id) on delete cascade,
    created_at  timestamp with time zone default now()
);

create unique index uniq_blocker_blocked on blocked_users(blocker_id, blocked_id);

-- Starred messages
create table starred_messages (
    id          uuid primary key default uuid_generate_v4(),
    user_id     uuid references users(id) on delete cascade,
    message_id  uuid references messages(id) on delete cascade,
    created_at  timestamp with time zone default now()
);

create unique index uniq_starred on starred_messages(user_id, message_id);

-- Polls
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

-- Poll votes
create table poll_votes (
    id          uuid primary key default uuid_generate_v4(),
    poll_id     uuid references polls(id) on delete cascade,
    user_id     uuid references users(id) on delete cascade,
    option_index int not null,
    created_at  timestamp with time zone default now()
);

create unique index uniq_poll_user_option on poll_votes(poll_id, user_id, option_index);

-- ----------------------------------------------------------------
-- 3. ENABLE ROW LEVEL SECURITY
-- ----------------------------------------------------------------
alter table users enable row level security;
alter table chats enable row level security;
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
alter table polls enable row level security;
alter table poll_votes enable row level security;

-- ----------------------------------------------------------------
-- 4. POLICIES
-- ----------------------------------------------------------------

-- Users
create policy "public read users" on users for select using (true);
create policy "owner update users" on users for update using (auth.uid() = id);
create policy "users can insert themselves" on users for insert with check (auth.uid() = id);

-- Chats
create policy "chat participants can read" on chats for select using (auth.uid() = user1_id or auth.uid() = user2_id);
create policy "chat participants can insert" on chats for insert with check (auth.uid() = user1_id or auth.uid() = user2_id);
create policy "chat participants can update" on chats for update using (auth.uid() = user1_id or auth.uid() = user2_id);

-- Messages
create policy "message participants read" on messages for select using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "message participants insert" on messages for insert with check (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "message participants update" on messages for update using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Reactions
create policy "reaction read" on reactions for select using (true);
create policy "reaction insert" on reactions for insert with check (auth.uid() = user_id);
create policy "reaction delete" on reactions for delete using (auth.uid() = user_id);

-- Groups
create policy "group read public" on groups for select using (true);
create policy "group insert" on groups for insert with check (auth.uid() = created_by);
create policy "group update" on groups for update using (auth.uid() = created_by);
create policy "group delete" on groups for delete using (auth.uid() = created_by);

-- Group members
create policy "group members read" on group_members for select using (true);
create policy "group members insert" on group_members for insert with check (true);
create policy "group members delete" on group_members for delete using (true);

-- Group messages
create policy "group message read" on group_messages for select using (true);
create policy "group message insert" on group_messages for insert with check (true);
create policy "group message update" on group_messages for update using (true);

-- Statuses
create policy "status read public" on statuses for select using (true);
create policy "status owner write" on statuses for all using (auth.uid() = user_id);

-- Status views
create policy "status view insert" on status_views for insert with check (auth.uid() = viewer_id);

-- Calls
create policy "call participants read" on calls for select using (auth.uid() = caller_id or auth.uid() = receiver_id);
create policy "call participants insert" on calls for insert with check (auth.uid() = caller_id or auth.uid() = receiver_id);
create policy "call participants update" on calls for update using (auth.uid() = caller_id or auth.uid() = receiver_id);

-- ICE candidates
create policy "ice read" on ice_candidates for select using (true);
create policy "ice insert" on ice_candidates for insert with check (true);

-- Blocked users
create policy "blocked read own" on blocked_users for select using (auth.uid() = blocker_id);
create policy "blocked insert own" on blocked_users for insert with check (auth.uid() = blocker_id);
create policy "blocked delete own" on blocked_users for delete using (auth.uid() = blocker_id);

-- Starred messages
create policy "starred read own" on starred_messages for select using (auth.uid() = user_id);
create policy "starred insert own" on starred_messages for insert with check (auth.uid() = user_id);
create policy "starred delete own" on starred_messages for delete using (auth.uid() = user_id);

-- Polls
create policy "poll read members" on polls for select using (true);
create policy "poll creator write" on polls for all using (auth.uid() = created_by);

-- Poll votes
create policy "poll vote insert" on poll_votes for insert with check (auth.uid() = user_id);
create policy "poll vote read" on poll_votes for select using (true);

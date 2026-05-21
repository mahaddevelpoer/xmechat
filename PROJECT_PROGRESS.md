# XmeChat — Progress Log (auto-generated)

Ye file is liye banayi gayi hai taake agar aap account switch karein ya baad mein wapas aayein, to **exactly** pata ho ke ab tak kya complete hua hai aur next kya kaam pending hai.

> Project: **XmeChat (WhatsApp clone)**
> Backend: **Supabase**

---

## ✅ Completed (Phase 1 → Phase 3)

### Phase 1 — Add Contact / New Chat (MOST IMPORTANT)
- Left sidebar header ke **pencil/compose (New chat)** button se **New Chat** dialog open hota hai.
- Tabs: **By Email** | **By Phone**
- Search flow / UI states implemented:
  - Initial: empty
  - Loading: CircularProgressIndicator
  - Found: user card + **Open Chat**
  - Not found: “This person is not on XmeChat” (no invite button)
  - Own account: “This is your own account”
  - Error: “Something went wrong, try again”
- **Database alignment** (as per your instruction):
  - 1:1 chat container table: `conversations`
  - Columns: `participant_1`, `participant_2`
  - `.maybeSingle()` used for single-record queries
  - Existing convo ho to open, warna create karke open

**Files touched (high level):**
- `lib/widgets/add_contact_sheet.dart`
- `lib/services/chat_service.dart`
- `lib/models/models.dart`
- `lib/core/constants/supabase_constants.dart`
- `supabase_schema.sql`

---

### Phase 2 — Real-time Messaging (Supabase Realtime) + Key Features
- Realtime messages stream + auto **delivered** + auto **read** (chat open ho to `seen_at` update).
- Status ticks:
  - sent ✓
  - delivered ✓✓
  - read ✓✓ (blue)
  - sending indicator (clock icon)
- Typing indicator + online/last seen header (existing logic maintained).
- Attachments:
  - Images (gallery/camera)
  - View-once image
  - Documents upload
  - Voice note record → upload → playback with speed control
  - Videos upload + view-once video + in-app video viewer
- Reply:
  - Swipe right → reply set + reply preview
  - Reply preview text now supports all types (photo/video/voice/doc etc.)
- Long press actions:
  - Reply
  - React (quick emoji picker)
  - Forward (working)
  - Star / Unstar
  - Copy
  - Delete for me
  - Delete for everyone
  - Info (sent/delivered/seen times)

**Files touched:**
- `lib/screens/chat/private_chat_screen.dart`
- `lib/widgets/chat/message_bubble.dart`
- `lib/services/chat_service.dart`

---

### Phase 3 — Voice & Video Calls (WebRTC + FREE signaling)
- WebRTC `flutter_webrtc` integrated with:
  - Offer/Answer + ICE via **Supabase Broadcast** channel: `call:<callId>`
  - Call row updates fallback via `calls` table updates
- Incoming call UI:
  - Incoming call screen shown over app
  - Ringtone (system sound loop)
  - Auto-decline after **30 seconds** (missed)
  - Accept / Decline works
- Caller UI:
  - Video: remote full-screen + draggable local preview
  - Voice: centered avatar + timer
  - Buttons: Mute, Camera on/off, Speaker, Switch camera, End call
  - Calling screen + Cancel button
- In-call text chat:
  - WebRTC DataChannel + broadcast fallback

**Files touched/added:**
- `lib/services/webrtc_service.dart`
- `lib/screens/calls/incoming_call_screen.dart`
- `lib/screens/calls/voice_call_screen.dart`
- `lib/screens/calls/video_call_screen.dart`

---

### Phase 4A — Group Chat
- Create group: name + icon + add members (by email/phone + list selection)
- Group members table (`group_members`) + admin flag (`is_admin`)
- Group chat screen:
  - Real-time group messages stream (Supabase `.stream(...)`)
  - Sender name shown above each message (for non-self messages)
  - Reply support (swipe right → reply preview)
  - Mention suggestions: `@name` typing ke time members list se suggestions
  - Poll feature (basic): create poll → message type `poll` + voting
- Group info screen:
  - Participants list
  - Admin controls: add members, make/remove admin, remove member
  - Leave group
- Home UI integration:
  - Mobile chats list + Desktop sidebar list dono mein **private + group chats combined** (sorted by last message time)
  - Desktop "Groups" filter ab group items show karta hai

**Files touched/added (high level):**
- `lib/services/group_service.dart`
- `lib/screens/chat/group_chat_screen.dart`
- `lib/screens/groups/create_group_screen.dart`
- `lib/screens/groups/group_info_screen.dart`
- `lib/widgets/add_group_member_sheet.dart`
- `lib/screens/home/home_tabs/chats_tab.dart`
- `lib/screens/home/home_screen.dart`
- `supabase_schema.sql`

---

### Phase 4B — Status / Stories
- Create status (Text + Photo)
  - Text status with background color picker
  - Photo status from gallery upload (Supabase storage)
- Auto-expire after **24 hours** (query filter via `expires_at`)
- Status list rings:
  - **Green** = new/unseen
  - **Grey** = all viewed
- Status viewer (WhatsApp style):
  - Tap left/right to prev/next
  - Auto progress bars
  - Viewed tracking (`status_views`)
- Seen-by list (My status):
  - “Seen by” bottom sheet with viewers list + time
  - Delete status option
- Reply to status:
  - Reply send hota hai as private message (“↩️ Status …”)
  - Send ke baad **private chat open** ho jata hai

**DB/Schema note:**
- `status_views` mein duplicate avoid karne ke liye unique index add: `(status_id, viewer_id)` (UPSERT ke liye required)

**Files touched (high level):**
- `lib/services/status_service.dart`
- `lib/screens/status/create_status_screen.dart`
- `lib/screens/status/status_viewer_screen.dart`
- `lib/screens/home/home_tabs/status_tab.dart`
- `supabase_schema.sql`

---

### Phase 4C — Background Service (Windows)
File: `lib/services/xmechat_root.dart`
- Background monitoring (Supabase realtime):
  - Private messages INSERT listener (receiver_id = current user)
  - Calls INSERT/UPDATE listener (incoming = `status == ringing`)
  - (Optional) group messages listener per joined group
- Windows toast notifications (desktop):
  - New message toast: sender + preview, click → open chat
  - Incoming call toast: click → open incoming call screen
- Incoming call popup over everything (best-effort):
  - Auto bring app window to front + show incoming call screen
- Auto-start on Windows boot:
  - Registry entry (HKCU Run)
  - Settings toggle: “Start on Windows startup”

**Files touched/added (high level):**
- `lib/services/xmechat_root.dart`
- `lib/services/windows_notifier.dart`
- `lib/core/navigation/app_navigator.dart`
- `lib/config/router.dart`
- `lib/app.dart`
- `lib/screens/settings/settings_screen.dart`

---

## 🔜 Next (Phase 4) — Planned Order (Strict)

### Step 4D — Mandatory Profile on First Login
- After email verification → forced profile setup
- Name required (min 2 chars)
- Photo required
- Phone optional (text only)
- Save to `users` table then home

### Step 4E — Email Verification with 6-digit OTP
- Signup ke baad code screen (6 boxes)
- Verify with `supabase.auth.verifyOTP(... OtpType.signup)`
- Resend with 60 sec cooldown
- Expire 10 min

### Step 4F — Working Settings
- Profile settings (name/photo/phone update)
- Notification settings toggles (shared_preferences)
- Chat settings (wallpaper/font size/enter key)
- Account (change password/delete/logout)

### Step 4G — Media Visibility
- Contact info: media grid, documents list, links list, starred
- photo_view viewer + video player + download

### Step 4H — Responsive Layout + Animations
- Desktop/tablet/mobile layouts
- Required transitions/animations list

---

## Notes / Rules Reminder
- `.maybeSingle()` for all single-record queries
- Navigation: `Navigator.pop(context)` (no `context.pop()`)
- `Uint8List` use ho to `dart:typed_data` import add karna
- Loading / error / empty states mandatory
- Free tier services only

# Fix Plan for XMeChat Issues

## Issue 1: Three dot menu button in status list panel not working
**Location**: `lib/screens/home/home_screen.dart` lines 981-987
**Problem**: The `onMenuTap` callback might not be properly wired or the status list panel might not be passing the callback correctly
**Fix**: 
- Verify that `_StatusListPanel` constructor receives `onMenuTap` parameter
- Verify that the `IconButton` with `Icons.more_vert` calls `onMenuTap` when pressed
- Check that `_showStatusMenu` method in `_HomeScreenState` is properly implemented

## Issue 2: Message input bar size adjustment
**Location**: `lib/widgets/chat/chat_input_bar.dart`
**Problem**: The input bar has fixed height constraints that don't adjust to content
**Fix**:
- Modify `_NormalBar` and `_RecordingBar` to use intrinsic height instead of fixed `AppSizes.inputBarHeight`
- Remove `BoxConstraints(minHeight: AppSizes.inputBarHeight)` and let content determine height
- Ensure text field can grow/shrink based on content while maintaining reasonable limits

## Issue 3: Crash when clicking add image in status section
**Location**: `lib/screens/status/create_status_screen.dart` lines 33-40
**Problem**: `_pickImage()` method lacks error handling for image picker operations
**Fix**:
- Add try/catch block around `ImagePicker.pickImage()` and `file.readAsBytes()`
- Show error snackbar if image picking fails
- Ensure method doesn't crash when picker returns null or encounters exceptions

## Issue 4: Add video posting capability to status section
**Location**: `lib/screens/status/create_status_screen.dart` and `lib/services/status_service.dart`
**Problem**: Status service only supports text and image posts, not video
**Fix**:
1. **StatusService** (`lib/services/status_service.dart`):
   - Add `postVideoStatus(Uint8List bytes, String ext)` method similar to `postImageStatus`
   - Handle video MIME types (mp4, etc.)
   - Upload to storage with correct content type
   - Create status record with type: 'video'

2. **CreateStatusScreen** (`lib/screens/status/create_status_screen.dart`):
   - Add video picking capability using `ImagePicker` with `source: ImageSource.gallery` and `mediaType: ImageMediaType.video`
   - Add state variable for `_videoBytes` and `_videoExt`
   - Add UI button for video selection
   - Modify `_postStatus()` to handle video posts
   - Show video preview when selected

## Implementation Order:
1. Fix status section crash (high priority - prevents usage)
2. Fix three dot menu button (high priority - affects UX)
3. Add video posting capability (medium priority - feature enhancement)
4. Adjust message input bar size (medium priority - polish)

## Testing Notes:
- Test image picker with various scenarios (cancelled, error, success)
- Test video picker with different formats
- Verify three dot menu shows status privacy dialog
- Verify input bar adjusts height based on text content (single line to multi-line)
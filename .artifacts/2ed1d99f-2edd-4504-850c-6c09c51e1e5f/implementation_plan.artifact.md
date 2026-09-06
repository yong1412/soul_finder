# Add Pet Lover Interest Channel and Media Support

The goal is to initialize a "Pet Lovers" interest channel in Firestore and update the existing channel system to support text, image, and video messages.

## User Review Required

> [!IMPORTANT]
> Since `firebase_storage` is not currently in the project dependencies, large media files (videos/images) cannot be efficiently stored in Firebase yet. I will update the models to support `mediaUrl`, but for this "test", we might need to add `firebase_storage` later or use external URLs/Base64 (not recommended for production).

## Proposed Changes

### [Models]

#### [MODIFY] [channel.dart](file:///D:/Github/soul_finder/lib/models/channel.dart)
- Update `ChannelMessage` to include `type` (text, image, video).
- Add `mediaUrl` and `thumbnailUrl` fields.

### [Services]

#### [MODIFY] [channel_service.dart](file:///D:/Github/soul_finder/lib/services/channel_service.dart)
- Add `initializeInterestChannels()` to seed the "Pet Lovers" channel.
- Update `sendMessage()` to support `type` and `mediaUrl`.

### [Views]

#### [MODIFY] [channel_conversation_view.dart](file:///D:/Github/soul_finder/lib/views/channel_conversation_view.dart)
- Update UI to render images and video placeholders.
- Add "plus" button to pick media (requires `image_picker`).

## Verification Plan

### Manual Verification
1. Run the app and check if "Pet Lovers" appears in the Interest Channels tab (assuming the user has "Pet Lovers" in their interests).
2. Send a text message to verify existing functionality.
3. Verify the database structure in Firestore console.

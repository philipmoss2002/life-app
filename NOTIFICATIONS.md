# Notification System

## Overview

The Life App now includes automatic reminder notifications for documents with renewal/payment due dates.

## How It Works

### Automatic Reminders

- **When:** Notifications are sent **7 days before** the renewal/payment due date
- **What:** You'll receive a notification reminding you about the upcoming renewal
- **Where:** Notifications appear in your device's notification tray

### Notification Triggers

1. **Creating a Document:**
   - When you add a new document with a renewal/payment due date
   - A notification is automatically scheduled for 7 days before that date

2. **Editing a Document:**
   - When you update a document's renewal date
   - The old notification is cancelled and a new one is scheduled

3. **Deleting a Document:**
   - When you delete a document
   - Any scheduled notifications for that document are cancelled

### Notification Content

**Title:** "Renewal Reminder"

**Message:** "[Document Title] renewal is due in 7 days"

**Example:** "Home Insurance renewal is due in 7 days"

## Permissions

### Android

- On Android 13 (API 33) and above, the app will request notification permission on first launch
- You can manage notification permissions in:
  - Settings → Apps → Life App → Notifications

### iOS

- The app will request notification permission on first launch
- You can manage notification permissions in:
  - Settings → Life App → Notifications

## Testing Notifications

### Test with a Near Date

1. Create a test document
2. Set the renewal date to 8 days from today
3. Wait 24 hours (or change device date for testing)
4. You should receive a notification

### Check Scheduled Notifications

**Android:**
- Long press the app icon → App Info → Notifications
- You can see if notifications are enabled

**iOS:**
- Settings → Life App → Notifications
- Check if "Allow Notifications" is enabled

## Notification Timing

- Notifications are scheduled using the device's local timezone
- They will appear at the same time of day as when the document was created/updated
- If the renewal date is less than 7 days away, no notification will be scheduled

## Troubleshooting

### Not Receiving Notifications?

1. **Check Permissions:**
   - Ensure notifications are enabled for Life App in device settings

2. **Check Date:**
   - Notifications only trigger 7 days before the renewal date
   - If the renewal date is less than 7 days away, no notification is scheduled

3. **Check Battery Optimization:**
   - Some devices may restrict background notifications
   - Android: Settings → Battery → Battery Optimization → Life App → Don't optimize

4. **Reinstall:**
   - If you installed the app before notifications were implemented
   - Uninstall and reinstall to ensure proper initialization

### Notification Not Appearing?

- Check if "Do Not Disturb" mode is enabled
- Check notification settings for the app
- Ensure the app has notification permission

## Technical Details

### Implementation

- **Library:** flutter_local_notifications
- **Scheduling:** Uses timezone-aware scheduling
- **Channel:** "renewal_channel" (Android)
- **Importance:** High priority
- **Sound:** Default notification sound

### Notification IDs

- Each document uses its database ID as the notification ID
- This ensures each document has a unique notification
- Allows for easy cancellation when documents are updated/deleted

## Future Enhancements

Potential improvements for future versions:

- [ ] Customizable reminder timing (3 days, 7 days, 14 days, 30 days)
- [ ] Multiple reminders per document
- [ ] Notification for overdue renewals
- [ ] Snooze functionality
- [ ] Direct action buttons (e.g., "Mark as Renewed")
- [ ] Notification history
- [ ] Custom notification sounds

## Privacy

- All notifications are generated locally on your device
- No data is sent to external servers
- Notifications are only visible to you

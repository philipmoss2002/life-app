# App Icon Setup Instructions

## Important Note About Circular Icons

Android launchers often display app icons in circles. To ensure your logo displays correctly:

**Option 1: Add padding to your logo (Recommended)**
- Create a version of your logo with transparent padding around it
- This ensures the logo isn't cropped when displayed in a circle
- Recommended: Logo should occupy ~70% of the canvas, with 15% padding on all sides

**Option 2: Design for circular display**
- Ensure important elements of your logo are within the "safe zone" (center 66% of the image)
- Corners may be cropped on some devices

## Steps to Replace the App Icon

1. **Save the logo image**
   - Save your Life App logo as `life_app_logo.png`
   - Place it in: `assets/images/life_app_logo.png`
   - Recommended size: 1024x1024 pixels (PNG format)
   - **Important**: Add padding if you want to avoid circular cropping

2. **Install the icon generator package**
   ```bash
   flutter pub get
   ```

3. **Generate the app icons**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

4. **Verify the icons**
   - Android icons will be in: `android/app/src/main/res/mipmap-*/`
   - iOS icons will be in: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## Current Configuration

The `pubspec.yaml` is already configured with:
- Android adaptive icons with blue background (#003D7A)
- iOS icons
- Automatic generation for all required sizes

## Manual Alternative

If you prefer to manually replace icons:

### Android
Replace these files in `android/app/src/main/res/`:
- `mipmap-mdpi/ic_launcher.png` (48x48)
- `mipmap-hdpi/ic_launcher.png` (72x72)
- `mipmap-xhdpi/ic_launcher.png` (96x96)
- `mipmap-xxhdpi/ic_launcher.png` (144x144)
- `mipmap-xxxhdpi/ic_launcher.png` (192x192)

### iOS
Replace icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Various sizes from 20x20 to 1024x1024

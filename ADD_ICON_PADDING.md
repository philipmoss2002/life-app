# Adding Padding to App Icon

## Why Add Padding?

Android devices display app icons in different shapes (circle, square, rounded square) depending on the manufacturer. To prevent your logo from being cropped, you need to add transparent padding around it.

## Recommended Padding

- **15-20% padding** on all sides ensures the logo displays well in all shapes
- The logo should occupy about 70% of the canvas
- Corners should have extra space to avoid cropping in circular displays

## Method 1: Using Python Script (Automated)

### Prerequisites:
```bash
pip install Pillow
```

### Run the script:
```bash
cd household_docs_app
python add_icon_padding.py
```

This will create `assets/images/life_app_logo_padded.png` with 15% padding.

## Method 2: Using Image Editor (Manual)

### Using any image editor (Photoshop, GIMP, Paint.NET, etc.):

1. **Open** `assets/images/life_app_logo.png`

2. **Check current size** (e.g., 1024x1024)

3. **Increase canvas size:**
   - New size: Add 30% to dimensions
   - Example: 1024 → 1331 pixels (1024 × 1.3)
   - Center the original image
   - Fill background with transparent

4. **Save as** `assets/images/life_app_logo_padded.png`

### Using Online Tools:

**Option A: Canva**
1. Go to canva.com
2. Create custom size: 1331x1331 (or 30% larger than your logo)
3. Upload your logo
4. Center it and resize to fit with padding
5. Download as PNG with transparent background

**Option B: Photopea (Free Photoshop alternative)**
1. Go to photopea.com
2. Open your logo
3. Image → Canvas Size
4. Increase by 30%, anchor center
5. File → Export As → PNG

## Method 3: Quick Manual Resize

If you have a square logo with no padding:

1. Open in any image editor
2. Add a transparent border/padding of 15-20% on all sides
3. Ensure the logo is centered
4. Save as `life_app_logo_padded.png`

## After Adding Padding

1. **Update pubspec.yaml:**
   ```yaml
   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/images/life_app_logo_padded.png"
     adaptive_icon_background: "#003D7A"
     adaptive_icon_foreground: "assets/images/life_app_logo_padded.png"
   ```

2. **Regenerate icons:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

3. **Test on device:**
   - Build and install the app
   - Check how the icon looks on your home screen
   - Adjust padding if needed

## Visual Guide

```
Original (cropped in circle):
┌─────────────┐
│ ┌─────────┐ │
│ │  LOGO   │ │  ← Logo touches edges
│ └─────────┘ │
└─────────────┘

With Padding (displays well):
┌─────────────┐
│             │
│   ┌─────┐   │
│   │LOGO │   │  ← Logo has space around it
│   └─────┘   │
│             │
└─────────────┘
```

## Testing Different Shapes

Your icon will be displayed in different shapes:
- **Circle** (most common on modern Android)
- **Rounded Square** (some manufacturers)
- **Square** (older devices)
- **Squircle** (iOS-style rounded)

With proper padding, your logo will look good in all shapes!

## Current Configuration

The app is currently configured to use:
- Image: `assets/images/life_app_logo.png`
- Background: Blue (#003D7A)
- Adaptive icon: Yes

After adding padding, update to use the padded version.

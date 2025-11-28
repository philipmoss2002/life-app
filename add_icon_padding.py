#!/usr/bin/env python3
"""
Script to add padding to app icon to prevent cropping in circular/rounded displays.
Requires: pip install Pillow
"""

from PIL import Image
import os

def add_padding_to_icon(input_path, output_path, padding_percent=15):
    """
    Add transparent padding around an icon.
    
    Args:
        input_path: Path to the original icon
        output_path: Path to save the padded icon
        padding_percent: Percentage of padding to add (default 15%)
    """
    # Open the original image
    img = Image.open(input_path)
    
    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Calculate new size with padding
    original_size = img.size[0]  # Assuming square image
    padding = int(original_size * (padding_percent / 100))
    new_size = original_size + (2 * padding)
    
    # Create new image with transparent background
    new_img = Image.new('RGBA', (new_size, new_size), (0, 0, 0, 0))
    
    # Paste original image in center
    new_img.paste(img, (padding, padding), img)
    
    # Save the result
    new_img.save(output_path, 'PNG')
    print(f"✓ Created padded icon: {output_path}")
    print(f"  Original size: {original_size}x{original_size}")
    print(f"  New size: {new_size}x{new_size}")
    print(f"  Padding: {padding}px ({padding_percent}%)")

if __name__ == "__main__":
    input_file = "assets/images/life_app_logo.png"
    output_file = "assets/images/life_app_logo_padded.png"
    
    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found!")
        print("Please ensure the logo file exists in assets/images/")
        exit(1)
    
    print("Adding padding to app icon...")
    add_padding_to_icon(input_file, output_file, padding_percent=15)
    print("\nDone! Now update pubspec.yaml to use 'life_app_logo_padded.png'")
    print("Then run: flutter pub run flutter_launcher_icons")

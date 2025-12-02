#!/usr/bin/env python3
"""
Remove white border from an image by cropping to the non-white content.
"""

from PIL import Image
import sys

def remove_white_border(input_path, output_path, threshold=250):
    """
    Remove white border from an image.
    
    Args:
        input_path: Path to input image
        output_path: Path to save output image
        threshold: RGB value threshold for considering a pixel as "white" (default 250)
    """
    # Open the image
    img = Image.open(input_path)
    
    # Convert to RGB if necessary
    if img.mode != 'RGB':
        img = img.convert('RGB')
    
    # Get image dimensions
    width, height = img.size
    
    # Find the bounding box of non-white content
    pixels = img.load()
    
    # Find top boundary
    top = 0
    for y in range(height):
        found_non_white = False
        for x in range(width):
            r, g, b = pixels[x, y]
            if r < threshold or g < threshold or b < threshold:
                found_non_white = True
                break
        if found_non_white:
            top = y
            break
    
    # Find bottom boundary
    bottom = height - 1
    for y in range(height - 1, -1, -1):
        found_non_white = False
        for x in range(width):
            r, g, b = pixels[x, y]
            if r < threshold or g < threshold or b < threshold:
                found_non_white = True
                break
        if found_non_white:
            bottom = y
            break
    
    # Find left boundary
    left = 0
    for x in range(width):
        found_non_white = False
        for y in range(height):
            r, g, b = pixels[x, y]
            if r < threshold or g < threshold or b < threshold:
                found_non_white = True
                break
        if found_non_white:
            left = x
            break
    
    # Find right boundary
    right = width - 1
    for x in range(width - 1, -1, -1):
        found_non_white = False
        for y in range(height):
            r, g, b = pixels[x, y]
            if r < threshold or g < threshold or b < threshold:
                found_non_white = True
                break
        if found_non_white:
            right = x
            break
    
    # Crop the image
    cropped = img.crop((left, top, right + 1, bottom + 1))
    
    # Save the result
    cropped.save(output_path)
    
    print(f"Original size: {width}x{height}")
    print(f"Cropped size: {cropped.size[0]}x{cropped.size[1]}")
    print(f"Removed border: top={top}, bottom={height-bottom-1}, left={left}, right={width-right-1}")
    print(f"Saved to: {output_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python remove_white_border.py <input_image> [output_image] [threshold]")
        print("Example: python remove_white_border.py assets/images/life_app_logo_padded.png")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else input_path.replace('.png', '_no_border.png')
    threshold = int(sys.argv[3]) if len(sys.argv) > 3 else 250
    
    remove_white_border(input_path, output_path, threshold)

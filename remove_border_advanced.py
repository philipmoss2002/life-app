#!/usr/bin/env python3
"""
Remove border from an image by detecting the background color and cropping.
"""

from PIL import Image
import sys

def get_background_color(img):
    """Detect the background color from the corners of the image."""
    pixels = img.load()
    width, height = img.size
    
    # Sample corners
    corners = [
        pixels[0, 0],
        pixels[width-1, 0],
        pixels[0, height-1],
        pixels[width-1, height-1]
    ]
    
    # Return the most common corner color
    return corners[0]

def remove_border(input_path, output_path, tolerance=30):
    """
    Remove border from an image by detecting and cropping the background.
    
    Args:
        input_path: Path to input image
        output_path: Path to save output image
        tolerance: Color difference tolerance (default 30)
    """
    # Open the image
    img = Image.open(input_path)
    
    # Convert to RGBA to handle transparency
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Get image dimensions
    width, height = img.size
    pixels = img.load()
    
    # Detect background color
    bg_color = get_background_color(img)
    print(f"Detected background color: {bg_color}")
    
    def is_background(pixel):
        """Check if a pixel matches the background color within tolerance."""
        if len(pixel) == 4:  # RGBA
            r, g, b, a = pixel
            bg_r, bg_g, bg_b, bg_a = bg_color
            # If pixel is transparent, consider it background
            if a < 10:
                return True
            return (abs(r - bg_r) <= tolerance and 
                    abs(g - bg_g) <= tolerance and 
                    abs(b - bg_b) <= tolerance)
        else:  # RGB
            r, g, b = pixel
            bg_r, bg_g, bg_b = bg_color[:3]
            return (abs(r - bg_r) <= tolerance and 
                    abs(g - bg_g) <= tolerance and 
                    abs(b - bg_b) <= tolerance)
    
    # Find top boundary
    top = 0
    for y in range(height):
        found_content = False
        for x in range(width):
            if not is_background(pixels[x, y]):
                found_content = True
                break
        if found_content:
            top = y
            break
    
    # Find bottom boundary
    bottom = height - 1
    for y in range(height - 1, -1, -1):
        found_content = False
        for x in range(width):
            if not is_background(pixels[x, y]):
                found_content = True
                break
        if found_content:
            bottom = y
            break
    
    # Find left boundary
    left = 0
    for x in range(width):
        found_content = False
        for y in range(height):
            if not is_background(pixels[x, y]):
                found_content = True
                break
        if found_content:
            left = x
            break
    
    # Find right boundary
    right = width - 1
    for x in range(width - 1, -1, -1):
        found_content = False
        for y in range(height):
            if not is_background(pixels[x, y]):
                found_content = True
                break
        if found_content:
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
        print("Usage: python remove_border_advanced.py <input_image> [output_image] [tolerance]")
        print("Example: python remove_border_advanced.py assets/images/life_app_logo_padded.png")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else input_path
    tolerance = int(sys.argv[3]) if len(sys.argv) > 3 else 30
    
    remove_border(input_path, output_path, tolerance)

#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import math, os

def generate_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    s = size
    cx, cy = s / 2, s / 2
    
    # Background: rounded rect with deep navy gradient feel
    margin = int(s * 0.05)
    radius = int(s * 0.22)
    
    # Draw rounded rectangle background
    bg_color_top = (15, 23, 42)      # #0F172A
    bg_color_bottom = (30, 41, 59)   # #1E293B
    
    for y in range(margin, s - margin):
        t = (y - margin) / max(s - 2 * margin, 1)
        r = int(bg_color_top[0] + (bg_color_bottom[0] - bg_color_top[0]) * t)
        g = int(bg_color_top[1] + (bg_color_bottom[1] - bg_color_top[1]) * t)
        b = int(bg_color_top[2] + (bg_color_bottom[2] - bg_color_top[2]) * t)
        draw.line([(margin, y), (s - margin, y)], fill=(r, g, b, 255))
    
    # Mask to rounded rect
    mask = Image.new('L', (s, s), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([margin, margin, s - margin, s - margin], radius=radius, fill=255)
    img.putalpha(mask)
    
    draw = ImageDraw.Draw(img)
    
    # Stars (small dots)
    import random
    random.seed(42)
    for _ in range(20):
        sx = random.randint(int(s*0.1), int(s*0.9))
        sy = random.randint(int(s*0.1), int(s*0.5))
        sr = max(1, int(s * 0.005))
        alpha = random.randint(80, 200)
        draw.ellipse([sx-sr, sy-sr, sx+sr, sy+sr], fill=(255, 255, 255, alpha))
    
    # Crescent moon
    moon_cx = cx + s * 0.05
    moon_cy = cy - s * 0.08
    moon_r = s * 0.22
    
    # Main moon circle (indigo/purple)
    moon_color = (99, 102, 241)  # #6366F1 indigo
    moon_glow = (129, 140, 248)  # #818CF8 lighter
    
    # Outer glow
    for gr in range(int(moon_r * 1.3), int(moon_r), -1):
        alpha = int(30 * (1 - (gr - moon_r) / (moon_r * 0.3)))
        draw.ellipse([
            moon_cx - gr, moon_cy - gr,
            moon_cx + gr, moon_cy + gr
        ], fill=(moon_glow[0], moon_glow[1], moon_glow[2], max(0, alpha)))
    
    # Moon body
    draw.ellipse([
        moon_cx - moon_r, moon_cy - moon_r,
        moon_cx + moon_r, moon_cy + moon_r
    ], fill=moon_color)
    
    # Crescent cutout (darker circle offset)
    cut_offset = s * 0.12
    cut_r = moon_r * 0.85
    cut_cx = moon_cx + cut_offset
    cut_cy = moon_cy - cut_offset * 0.5
    
    # Need to read bg color at each pixel for proper cutout
    for y in range(int(moon_cy - moon_r - 5), int(moon_cy + moon_r + 5)):
        for x in range(int(moon_cx - moon_r - 5), int(moon_cx + moon_r + 5)):
            if 0 <= x < s and 0 <= y < s:
                dx = x - cut_cx
                dy = y - cut_cy
                if dx*dx + dy*dy < cut_r*cut_r:
                    # Inside cutout — restore background
                    t = (y - margin) / max(s - 2 * margin, 1)
                    t = max(0, min(1, t))
                    r = int(bg_color_top[0] + (bg_color_bottom[0] - bg_color_top[0]) * t)
                    g = int(bg_color_top[1] + (bg_color_bottom[1] - bg_color_top[1]) * t)
                    b = int(bg_color_top[2] + (bg_color_bottom[2] - bg_color_top[2]) * t)
                    # Check if within rounded rect
                    mx = x - margin
                    my = y - margin
                    inner = s - 2 * margin
                    if 0 <= mx <= inner and 0 <= my <= inner:
                        img.putpixel((x, y), (r, g, b, 255))
    
    draw = ImageDraw.Draw(img)
    
    # "zzz" sleep indicators
    zzz_color = (168, 85, 247)  # purple
    zzz_x = moon_cx + moon_r * 0.6
    zzz_y = moon_cy - moon_r * 0.3
    
    for i, (dx, dy, font_size_mult) in enumerate([(0, 0, 0.08), (s*0.06, -s*0.07, 0.065), (s*0.1, -s*0.15, 0.05)]):
        fs = max(8, int(s * font_size_mult))
        try:
            font = ImageFont.truetype("/System/Library/Fonts/SFCompact.ttf", fs)
        except:
            try:
                font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", fs)
            except:
                font = ImageFont.load_default()
        
        alpha = 255 - i * 50
        draw.text((zzz_x + dx, zzz_y + dy), "z", fill=(zzz_color[0], zzz_color[1], zzz_color[2], alpha), font=font)
    
    # Waveform at bottom (breathing wave)
    wave_y = cy + s * 0.28
    wave_amp = s * 0.04
    wave_color = (34, 197, 94)  # green #22C55E
    
    points = []
    for i in range(int(s * 0.2), int(s * 0.8)):
        t = (i - s * 0.2) / (s * 0.6)
        y = wave_y + wave_amp * math.sin(t * math.pi * 4) * math.sin(t * math.pi)
        points.append((i, y))
    
    if len(points) > 1:
        lw = max(1, int(s * 0.015))
        for j in range(len(points) - 1):
            x1, y1 = points[j]
            x2, y2 = points[j + 1]
            t = j / len(points)
            alpha = int(255 * math.sin(t * math.pi))
            draw.line([(x1, y1), (x2, y2)], fill=(wave_color[0], wave_color[1], wave_color[2], max(50, alpha)), width=lw)
    
    # Re-apply rounded rect mask
    final_mask = Image.new('L', (s, s), 0)
    final_draw = ImageDraw.Draw(final_mask)
    final_draw.rounded_rectangle([margin, margin, s - margin, s - margin], radius=radius, fill=255)
    
    old_alpha = img.split()[3]
    new_alpha = Image.new('L', (s, s), 0)
    for y in range(s):
        for x in range(s):
            new_alpha.putpixel((x, y), min(old_alpha.getpixel((x, y)), final_mask.getpixel((x, y))))
    img.putalpha(new_alpha)
    
    return img

output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 
    "SleepAnalyser", "Resources", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(output_dir, exist_ok=True)

sizes = [16, 32, 64, 128, 256, 512, 1024]

for sz in sizes:
    icon = generate_icon(sz)
    icon.save(os.path.join(output_dir, f"icon_{sz}x{sz}.png"))
    print(f"  Generated icon_{sz}x{sz}.png")

print("All icons generated!")

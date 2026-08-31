import os
from PIL import Image, ImageDraw, ImageFilter

def create_rentilly_icon(size):
    # Create 4x supersampled image for ultra-smooth anti-aliasing
    scale = 4
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Outer Squircle (Continuous smooth rounded rect)
    margin = int(canvas_size * 0.04)
    radius = int(canvas_size * 0.22)
    
    # Background gradient simulation (top-left to bottom-right)
    # Emerald green to Deep obsidian forest green
    base_bg = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(base_bg)
    
    # Gradient bands
    steps = 100
    for i in range(steps):
        ratio = i / steps
        # Color from #10B981 (16, 185, 129) to #061E16 (6, 30, 22)
        r = int(16 * (1 - ratio) + 6 * ratio)
        g = int(185 * (1 - ratio) + 30 * ratio)
        b = int(129 * (1 - ratio) + 22 * ratio)
        y = int(canvas_size * ratio)
        bg_draw.rectangle([0, y, canvas_size, y + int(canvas_size / steps) + 1], fill=(r, g, b, 255))

    # Mask for squircle
    mask = Image.new("L", (canvas_size, canvas_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [margin, margin, canvas_size - margin, canvas_size - margin],
        radius=radius,
        fill=255
    )
    
    # Composite squircle
    icon_base = Image.composite(base_bg, Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0)), mask)
    draw = ImageDraw.Draw(icon_base)

    # 2. Subtle Inner Glowing Border
    draw.rounded_rectangle(
        [margin + scale * 2, margin + scale * 2, canvas_size - margin - scale * 2, canvas_size - margin - scale * 2],
        radius=radius - scale * 2,
        outline=(255, 255, 255, 60),
        width=int(scale * 3)
    )

    # Center coordinates
    cx = canvas_size / 2
    cy = canvas_size / 2

    # 3. Draw Modern Geometric Shield
    shield_w = canvas_size * 0.52
    shield_h = canvas_size * 0.60
    shield_top = cy - shield_h * 0.48
    shield_bot = shield_top + shield_h

    # Shield polygon points
    points = [
        (cx - shield_w / 2, shield_top),
        (cx + shield_w / 2, shield_top),
        (cx + shield_w / 2, shield_top + shield_h * 0.55),
        (cx, shield_bot),
        (cx - shield_w / 2, shield_top + shield_h * 0.55),
    ]

    # Shield glow / outline
    draw.polygon(points, fill=(15, 56, 42, 220), outline=(245, 158, 11, 240)) # Amber/Gold outline
    # Redraw thicker outline
    for off in range(int(scale * 4)):
        p_off = [
            (points[0][0] - off*0.3, points[0][1] - off*0.3),
            (points[1][0] + off*0.3, points[1][1] - off*0.3),
            (points[2][0] + off*0.3, points[2][1]),
            (points[3][0], points[3][1] + off*0.4),
            (points[4][0] - off*0.3, points[4][1]),
        ]
        draw.polygon(p_off, outline=(245, 158, 11, max(30, 240 - off * 30)))

    # 4. Inside the shield: Stylized Modern House Roof & Keyhole
    # House Roof (Apex triangle)
    roof_w = shield_w * 0.68
    roof_h = shield_h * 0.28
    roof_top = shield_top + shield_h * 0.16
    roof_points = [
        (cx, roof_top),
        (cx + roof_w / 2, roof_top + roof_h),
        (cx + roof_w / 2 - scale * 6, roof_top + roof_h),
        (cx, roof_top + scale * 8),
        (cx - roof_w / 2 + scale * 6, roof_top + roof_h),
        (cx - roof_w / 2, roof_top + roof_h),
    ]
    draw.polygon(roof_points, fill=(255, 255, 255, 255))

    # Keyhole / Vault Emblem below roof
    keyhole_top = roof_top + roof_h + scale * 4
    # Circle for key head
    kh_radius = int(scale * 16)
    draw.ellipse(
        [cx - kh_radius, keyhole_top, cx + kh_radius, keyhole_top + kh_radius * 2],
        fill=(255, 255, 255, 255)
    )
    # Keyhole stem/slot (trapezoid)
    stem_top = keyhole_top + kh_radius * 1.3
    stem_bot = stem_top + scale * 26
    stem_points = [
        (cx - scale * 6, stem_top),
        (cx + scale * 6, stem_top),
        (cx + scale * 10, stem_bot),
        (cx - scale * 10, stem_bot),
    ]
    draw.polygon(stem_points, fill=(255, 255, 255, 255))

    # Inner cutout in keyhole
    inner_radius = int(scale * 7)
    draw.ellipse(
        [cx - inner_radius, keyhole_top + kh_radius - inner_radius, cx + inner_radius, keyhole_top + kh_radius + inner_radius],
        fill=(15, 56, 42, 255)
    )

    # 5. Downsample using Lanczos for crisp, anti-aliased output
    final_icon = icon_base.resize((size, size), Image.Resampling.LANCZOS)
    return final_icon

def generate_all_icons():
    res_base = os.path.abspath("mobile/android/app/src/main/res")
    
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, size in densities.items():
        out_dir = os.path.join(res_base, folder)
        os.makedirs(out_dir, exist_ok=True)
        icon = create_rentilly_icon(size)
        out_path = os.path.join(out_dir, "ic_launcher.png")
        icon.save(out_path, "PNG")
        print(f"Generated {out_path} ({size}x{size})")

    # Generate master web / store icon (512x512)
    web_dir = os.path.abspath("mobile/web/icons")
    os.makedirs(web_dir, exist_ok=True)
    master_icon = create_rentilly_icon(512)
    master_icon.save(os.path.join(web_dir, "Icon-512.png"), "PNG")
    master_icon.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_dir, "Icon-192.png"), "PNG")
    print("Generated web/store master icons (512x512 & 192x192)")

if __name__ == "__main__":
    generate_all_icons()


def relative_luminance(r, g, b):
    def adjust(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * adjust(r) + 0.7152 * adjust(g) + 0.0722 * adjust(b)

def contrast_ratio(c1, c2):
    l1 = relative_luminance(*c1)
    l2 = relative_luminance(*c2)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)

def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip('#')
    return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))

colors = {
    "Cream Light": {
        "bg": "#FDFCF8",
        "surface": "#F2F0EB",
        "textPrimary": "#4A453E",
        "textSecondary": "#8C867B",
        "primary": "#8E9775"
    },
    "Sumi Dark": {
        "bg": "#1C1B1A",
        "surface": "#262422",
        "textPrimary": "#E6E2D8",
        "textSecondary": "#A8A29A",
        "primary": "#B5BEA0"
    }
}

print("--- Contrast Verification ---")
for theme, p in colors.items():
    print(f"\nTheme: {theme}")
    bg_rgb = hex_to_rgb(p["bg"])
    
    # Check Primary Text
    tp_rgb = hex_to_rgb(p["textPrimary"])
    ratio_tp = contrast_ratio(bg_rgb, tp_rgb)
    pass_tp = "PASS" if ratio_tp >= 7 else "FAIL"
    print(f"  Text Primary on BG: {ratio_tp:.2f} : 1  [{pass_tp}] (Req >= 7)")

    # Check Secondary Text
    ts_rgb = hex_to_rgb(p["textSecondary"])
    ratio_ts = contrast_ratio(bg_rgb, ts_rgb)
    pass_ts = "PASS" if ratio_ts >= 4.5 else "FAIL"
    print(f"  Text Secondary on BG: {ratio_ts:.2f} : 1  [{pass_ts}] (Req >= 4.5)")
    
    # Check Primary Color (Buttons/Icons) - often white text on primary or primary text on bg
    # Assuming primary color text on background for icons
    prim_rgb = hex_to_rgb(p["primary"])
    ratio_prim = contrast_ratio(bg_rgb, prim_rgb)
    pass_prim = "PASS" if ratio_prim >= 3 else "WARN" # Icons needs 3:1 usually, text 4.5
    print(f"  Primary on BG: {ratio_prim:.2f} : 1  [{pass_prim}] (Req >= 3 for graphical objects)")

#!/usr/bin/env python3
from __future__ import annotations

import math
import shutil
import zipfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW_ROOT = ROOT / "build/appstore_screenshots/raw"
FINAL_ROOT = ROOT / "build/appstore_screenshots/final"
UPLOAD_ROOT = ROOT / "build/appstore_screenshots/upload"
BACKGROUND = ROOT / "assets/screenshots/generated/appstore_background_v2.png"
FONT_REGULAR = ROOT / "assets/fonts/NotoSansSC-Regular.ttf"
FONT_BOLD = ROOT / "assets/fonts/NotoSansSC-Bold.ttf"


INK = (23, 35, 33)
MUTED = (95, 109, 103)
EMERALD = (11, 51, 47)
MIST = (232, 240, 236)
BRASS = (194, 137, 48)
PAPER = (255, 252, 247)
FRAME = (248, 245, 238)
FRAME_LINE = (228, 222, 211)


@dataclass(frozen=True)
class ShotCopy:
    title: str
    subtitle: str


COPY: dict[str, dict[str, ShotCopy]] = {
    "zh": {
        "01_empty_home": ShotCopy("从第一个房屋档案开始", "本地保存，不上传照片，入住前建立证据链"),
        "02_dashboard": ShotCopy("房源、检查、报告一屏掌握", "快速继续检查，清楚知道下一步该做什么"),
        "03_inspection_evidence": ShotCopy("按房间采集照片和备注", "时间、位置、哈希自动进入证据记录"),
        "04_final_report_step": ShotCopy("签名后生成正式证据包", "导出 PDF 报告和 JSON manifest"),
        "05_report_archive": ShotCopy("报告档案随时预览分享", "按检查类型区分，不再找错文件"),
        "06_more": ShotCopy("隐私、支持和 Pro 集中管理", "本地优先，无账号，适合租客和房东"),
        "07_pdf_report_preview": ShotCopy("PDF 报告直接预览房间照片", "照片、备注、时间、签名和哈希一页留证"),
    },
    "en": {
        "01_empty_home": ShotCopy("Start with your first property file", "Keep photos local and build evidence before move-in"),
        "02_dashboard": ShotCopy("Properties, inspections, reports", "Resume work fast and always know the next step"),
        "03_inspection_evidence": ShotCopy("Capture evidence room by room", "Timestamp, location, and hash stay with each record"),
        "04_final_report_step": ShotCopy("Generate a formal evidence package", "Export PDF reports and JSON manifests"),
        "05_report_archive": ShotCopy("Preview and share report archives", "Keep each inspection type clearly separated"),
        "06_more": ShotCopy("Privacy, support, and Pro in one place", "Local-first, account-free, built for tenants and landlords"),
        "07_pdf_report_preview": ShotCopy("PDF reports include room photos", "Photos, notes, timestamps, signatures, and hashes in one packet"),
    },
}


DEVICE_SIZE = {
    "iphone": (1320, 2868),
    "ipad": (2064, 2752),
}

UPLOAD_SIZE = {
    "iphone": (1284, 2778),
    "ipad": (2048, 2732),
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_BOLD if bold else FONT_REGULAR), size)


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    src_w, src_h = image.size
    dst_w, dst_h = size
    scale = max(dst_w / src_w, dst_h / src_h)
    resized = image.resize((math.ceil(src_w * scale), math.ceil(src_h * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - dst_w) // 2
    top = (resized.height - dst_h) // 2
    return resized.crop((left, top, left + dst_w, top + dst_h))


def contain_resize(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    image = image.convert("RGBA")
    image.thumbnail(max_size, Image.Resampling.LANCZOS)
    return image


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def paste_shadow(base: Image.Image, box: tuple[int, int, int, int], radius: int, alpha: int, blur: int, offset: tuple[int, int]) -> None:
    x0, y0, x1, y1 = box
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    ox, oy = offset
    draw.rounded_rectangle((x0 + ox, y0 + oy, x1 + ox, y1 + oy), radius=radius, fill=(23, 35, 33, alpha))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(shadow)


def draw_centered_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    center_x: int,
    y: int,
    font_obj: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
    max_width: int,
    line_gap: int = 8,
) -> int:
    words = list(text) if any("\u4e00" <= c <= "\u9fff" for c in text) else text.split(" ")
    lines: list[str] = []
    current = ""
    joiner = "" if len(words) > 0 and len(words[0]) == 1 and any("\u4e00" <= c <= "\u9fff" for c in text) else " "
    for word in words:
        candidate = word if not current else f"{current}{joiner}{word}"
        if draw.textbbox((0, 0), candidate, font=font_obj)[2] <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font_obj)
        draw.text((center_x - (bbox[2] - bbox[0]) / 2, y), line, font=font_obj, fill=fill)
        y += bbox[3] - bbox[1] + line_gap
    return y


def draw_brand_pill(draw: ImageDraw.ImageDraw, canvas_w: int, y: int, lang: str) -> int:
    label = "UNITTRACE" if lang == "en" else "房况留证"
    f = font(24 if lang == "en" else 26, bold=True)
    bbox = draw.textbbox((0, 0), label, font=f)
    pill_w = bbox[2] - bbox[0] + 76
    pill_h = 52
    x = (canvas_w - pill_w) // 2
    draw.rounded_rectangle((x, y, x + pill_w, y + pill_h), radius=26, fill=(232, 240, 236, 224), outline=(196, 216, 207), width=2)
    draw.text((canvas_w / 2 - (bbox[2] - bbox[0]) / 2, y + 10), label, font=f, fill=EMERALD)
    return y + pill_h


def make_background(size: tuple[int, int]) -> Image.Image:
    bg = cover_resize(Image.open(BACKGROUND).convert("RGB"), size).convert("RGBA")
    paper = Image.new("RGBA", size, (*PAPER, 238))
    bg = Image.blend(paper, bg, 0.22)
    veil = Image.new("RGBA", size, (255, 252, 247, 70))
    bg.alpha_composite(veil)
    return bg


def device_box(platform: str, canvas: tuple[int, int], screen: Image.Image) -> tuple[int, int, int, int, int]:
    canvas_w, canvas_h = canvas
    if platform == "iphone":
        inner_w = 930
        inner_h = round(inner_w * screen.height / screen.width)
        x = (canvas_w - inner_w) // 2
        y = 455
        pad = 34
        radius = 92
    else:
        inner_w = 1668
        inner_h = round(inner_w * screen.height / screen.width)
        x = (canvas_w - inner_w) // 2
        y = 455
        pad = 42
        radius = 64
        if y + inner_h + pad * 2 > canvas_h - 54:
            inner_h = canvas_h - y - pad * 2 - 54
            inner_w = round(inner_h * screen.width / screen.height)
            x = (canvas_w - inner_w) // 2
    return x, y, inner_w, inner_h, pad, radius


def compose(platform: str, lang: str, shot_id: str) -> Image.Image:
    canvas_size = DEVICE_SIZE[platform]
    raw_path = RAW_ROOT / platform / lang / f"{shot_id}.png"
    screen = Image.open(raw_path).convert("RGBA")
    screen = normalize_empty_home(screen, platform, lang, shot_id)
    copy = COPY[lang][shot_id]
    out = make_background(canvas_size)
    draw = ImageDraw.Draw(out, "RGBA")

    brand_bottom = draw_brand_pill(draw, canvas_size[0], 78 if platform == "iphone" else 62, lang)
    title_size = 62 if platform == "iphone" else 66
    subtitle_size = 28 if platform == "iphone" else 30
    title_y = brand_bottom + (54 if platform == "iphone" else 34)
    title_bottom = draw_centered_text(draw, copy.title, canvas_size[0] // 2, title_y, font(title_size, True), INK, int(canvas_size[0] * 0.86), 10)
    draw_centered_text(draw, copy.subtitle, canvas_size[0] // 2, title_bottom + 16, font(subtitle_size), MUTED, int(canvas_size[0] * 0.78), 8)

    x, y, inner_w, inner_h, pad, radius = device_box(platform, canvas_size, screen)
    outer = (x - pad, y - pad, x + inner_w + pad, y + inner_h + pad)
    paste_shadow(out, outer, radius + pad, 34, 42, (0, 26))
    paste_shadow(out, outer, radius + pad, 16, 18, (0, 6))

    frame_layer = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame_layer, "RGBA")
    frame_draw.rounded_rectangle(outer, radius=radius + pad, fill=FRAME, outline=FRAME_LINE, width=3)
    frame_draw.rounded_rectangle((outer[0] + 8, outer[1] + 8, outer[2] - 8, outer[3] - 8), radius=radius + pad - 8, outline=(255, 255, 255, 178), width=3)
    out.alpha_composite(frame_layer)

    resized = screen.resize((inner_w, inner_h), Image.Resampling.LANCZOS)
    mask = rounded_mask((inner_w, inner_h), radius)
    out.paste(resized, (x, y), mask)

    # A thin titanium lip makes the device feel framed without turning it into a heavy black mockup.
    lip = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    lip_draw = ImageDraw.Draw(lip, "RGBA")
    lip_draw.rounded_rectangle((x - 2, y - 2, x + inner_w + 2, y + inner_h + 2), radius=radius + 2, outline=(205, 196, 181, 210), width=3)
    lip_draw.rounded_rectangle((x + 5, y + 5, x + inner_w - 5, y + inner_h - 5), radius=radius - 5, outline=(255, 255, 255, 190), width=2)
    out.alpha_composite(lip)

    return out.convert("RGB")


def normalize_empty_home(
    screen: Image.Image,
    platform: str,
    lang: str,
    shot_id: str,
) -> Image.Image:
    if shot_id != "01_empty_home" or lang != "en":
        return screen

    screen = screen.copy()
    draw = ImageDraw.Draw(screen, "RGBA")
    if platform == "iphone":
        draw_report_metric_card(draw, (860, 912, 1218, 1266), "iphone")
    else:
        draw_report_metric_card(draw, (1168, 510, 1478, 690), "ipad")
    return screen


def draw_report_metric_card(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    platform: str,
) -> None:
    x0, y0, x1, y1 = box
    radius = 30 if platform == "iphone" else 24
    draw.rounded_rectangle(box, radius=radius, fill=(255, 253, 249, 255), outline=(228, 222, 211, 255), width=2)
    icon_x = x0 + (42 if platform == "iphone" else 28)
    icon_y = y0 + (44 if platform == "iphone" else 24)
    icon_w = 42 if platform == "iphone" else 28
    draw.rounded_rectangle((icon_x, icon_y, icon_x + icon_w, icon_y + icon_w), radius=3, outline=EMERALD, width=5 if platform == "iphone" else 3)
    draw.rectangle((icon_x + icon_w - 12, icon_y, icon_x + icon_w, icon_y + 12), fill=(255, 253, 249), outline=EMERALD, width=3 if platform == "iphone" else 2)
    pdf_font = font(13 if platform == "iphone" else 8, True)
    draw.text((icon_x + 8, icon_y + 13), "PDF", font=pdf_font, fill=EMERALD)
    if platform == "iphone":
        draw.text((x0 + 42, y0 + 150), "0", font=font(52, True), fill=INK)
        draw.text((x0 + 42, y0 + 230), "Reports", font=font(38), fill=MUTED)
        draw.text((x0 + 42, y0 + 283), "generated", font=font(38), fill=MUTED)
    else:
        draw.text((x0 + 28, y0 + 84), "0", font=font(32, True), fill=INK)
        draw.text((x0 + 28, y0 + 132), "Reports generated", font=font(27), fill=MUTED)


def write_outputs() -> None:
    if not BACKGROUND.exists():
        raise FileNotFoundError(BACKGROUND)
    for root in (FINAL_ROOT, UPLOAD_ROOT):
        for platform in DEVICE_SIZE:
            for lang in COPY:
                (root / platform / lang).mkdir(parents=True, exist_ok=True)

    for platform in DEVICE_SIZE:
        for lang in ("zh", "en"):
            for shot_id in COPY[lang]:
                print(f"Composing {platform}/{lang}/{shot_id}")
                image = compose(platform, lang, shot_id)
                final_path = FINAL_ROOT / platform / lang / f"{shot_id}.png"
                upload_path = UPLOAD_ROOT / platform / lang / f"{shot_id}.png"
                image.save(final_path, optimize=True)
                upload = image.resize(UPLOAD_SIZE[platform], Image.Resampling.LANCZOS)
                upload.save(upload_path, optimize=True)

    zip_path = ROOT / "build/appstore_screenshots/unittrace_appstore_screenshots.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(UPLOAD_ROOT.rglob("*.png")):
            archive.write(path, path.relative_to(UPLOAD_ROOT))


if __name__ == "__main__":
    write_outputs()

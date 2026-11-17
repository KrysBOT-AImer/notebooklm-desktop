#!/usr/bin/env python3
"""Render assets/icon.svg into RGBA PNGs for app window and Linux system tray."""

from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
ICONS_DIR = ASSETS / "icons"
SVG_PATH = ASSETS / "icon.svg"
ICON_PNG = ASSETS / "icon.png"
TRAY_PNG = ASSETS / "tray-icon.png"
SIZES = [16, 24, 32, 48, 64, 128, 256, 512]


def render_with_rsvg(svg: Path, out_png: Path, size: int) -> None:
    subprocess.run(
        [
            "rsvg-convert",
            "-w",
            str(size),
            "-h",
            str(size),
            "-f",
            "png",
            "-o",
            str(out_png),
            str(svg),
        ],
        check=True,
    )


def render_with_chromium(svg: Path, out_png: Path, size: int) -> None:
    html = (
        "<!DOCTYPE html><html><body style='margin:0;padding:0;background:transparent;"
        f"width:{size}px;height:{size}px;overflow:hidden;'>"
        f"<img src='{svg.as_uri()}' width='{size}' height='{size}' style='display:block;'/>"
        "</body></html>"
    )
    tmp_html = ASSETS / f".tmp_{size}.html"
    tmp_html.write_text(html, encoding="utf-8")
    try:
        subprocess.run(
            [
                "chromium",
                "--headless",
                "--disable-gpu",
                "--no-sandbox",
                "--default-background-color=00000000",
                f"--window-size={size},{size}",
                f"--screenshot={out_png}",
                tmp_html.as_uri(),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    finally:
        if tmp_html.exists():
            tmp_html.unlink()


def ensure_rgba_size(png_path: Path, size: int) -> None:
    try:
        from PIL import Image

        with Image.open(png_path) as img:
            rgba = img.convert("RGBA")
            if rgba.size != (size, size):
                rgba = rgba.resize((size, size), Image.Resampling.LANCZOS)
            rgba.save(png_path, format="PNG")
    except ImportError:
        pass


def main() -> int:
    if not SVG_PATH.exists():
        print(f"Missing SVG icon at {SVG_PATH}", file=sys.stderr)
        return 1

    ICONS_DIR.mkdir(parents=True, exist_ok=True)
    targets = [(ICON_PNG, 256), (TRAY_PNG, 64)]
    for size in SIZES:
        targets.append((ICONS_DIR / f"icon-{size}.png", size))

    if shutil.which("rsvg-convert"):
        for path, size in targets:
            render_with_rsvg(SVG_PATH, path, size)
            ensure_rgba_size(path, size)
    elif shutil.which("chromium"):
        for path, size in targets:
            render_with_chromium(SVG_PATH, path, size)
            ensure_rgba_size(path, size)
    else:
        print("Neither rsvg-convert nor chromium found to rasterize icon.svg", file=sys.stderr)
        return 1

    print(f"Generated {ICON_PNG} (256x256), {TRAY_PNG} (64x64), and multi-size icons in {ICONS_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

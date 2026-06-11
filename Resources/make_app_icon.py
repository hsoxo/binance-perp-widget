#!/usr/bin/env python3
import argparse
import subprocess
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


ICONSET_NAMES = {
    16: "icon_16x16.png",
    32: "icon_16x16@2x.png",
    32.1: "icon_32x32.png",
    64: "icon_32x32@2x.png",
    128: "icon_128x128.png",
    256: "icon_128x128@2x.png",
    256.1: "icon_256x256.png",
    512: "icon_256x256@2x.png",
    512.1: "icon_512x512.png",
    1024: "icon_512x512@2x.png",
}


def background_mask(image: Image.Image, tolerance: int) -> Image.Image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    visited = bytearray(width * height)
    mask = Image.new("L", (width, height), 255)
    mask_pixels = mask.load()
    queue: deque[tuple[int, int]] = deque()

    def is_background(x: int, y: int) -> bool:
        r, g, b = pixels[x, y]
        return r <= tolerance and g <= tolerance and b <= tolerance

    def add_if_background(x: int, y: int) -> None:
        idx = y * width + x
        if visited[idx] or not is_background(x, y):
            return
        visited[idx] = 1
        mask_pixels[x, y] = 0
        queue.append((x, y))

    for x in range(width):
        add_if_background(x, 0)
        add_if_background(x, height - 1)
    for y in range(height):
        add_if_background(0, y)
        add_if_background(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            add_if_background(x - 1, y)
        if x + 1 < width:
            add_if_background(x + 1, y)
        if y > 0:
            add_if_background(x, y - 1)
        if y + 1 < height:
            add_if_background(x, y + 1)

    return mask.filter(ImageFilter.GaussianBlur(radius=0.7))


def flatten_on_background(image: Image.Image, size: int, background: tuple[int, int, int]) -> Image.Image:
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    base = Image.new("RGBA", (size, size), (*background, 255))
    base.alpha_composite(resized)
    return base.convert("RGB")


def main() -> int:
    parser = argparse.ArgumentParser(description="Create macOS app icon assets.")
    parser.add_argument("source", type=Path, help="Source icon PNG")
    parser.add_argument("--out-dir", type=Path, default=Path("Resources"))
    parser.add_argument("--name", default="AppIcon")
    parser.add_argument("--tolerance", type=int, default=28)
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGBA")
    mask = background_mask(source, args.tolerance)
    source.putalpha(mask)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    master_path = args.out_dir / f"{args.name}.png"
    source.resize((1024, 1024), Image.Resampling.LANCZOS).save(master_path)

    preview_path = args.out_dir / f"{args.name}-preview.png"
    flatten_on_background(source, 1024, (245, 247, 250)).save(preview_path)

    iconset = args.out_dir / f"{args.name}.iconset"
    iconset.mkdir(parents=True, exist_ok=True)
    for key, filename in ICONSET_NAMES.items():
        size = int(key)
        source.resize((size, size), Image.Resampling.LANCZOS).save(iconset / filename)

    icns_path = args.out_dir / f"{args.name}.icns"
    subprocess.run(
        ["iconutil", "--convert", "icns", "--output", str(icns_path), str(iconset)],
        check=True,
    )

    print(master_path)
    print(preview_path)
    print(icns_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

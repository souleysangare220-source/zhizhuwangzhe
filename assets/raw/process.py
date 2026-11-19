#!/usr/bin/env python
# 预处理：把 raw/ 里的 AI 大图缩到游戏内尺寸并量化，输出到 assets/ 根目录
import os
from PIL import Image

RAW = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(RAW)  # assets/

# 名字映射：raw 名 -> (输出名, 宽, 高)
JOBS = {
    "template":  ("card_face",        120, 168),   # 牌面底模，严格匹配 40x56 牌面的 3 倍
    "spider":    ("court_spider",     128, 128),
    "moth":      ("court_moth",       128, 128),
    "beetle":    ("court_beetle",     128, 128),
    "centipede": ("court_centipede",  128, 128),
}

for raw_name, (out_name, w, h) in JOBS.items():
    src = os.path.join(RAW, raw_name + ".png")
    dst = os.path.join(OUT, out_name + ".png")
    if not os.path.exists(src):
        print("MISS", src)
        continue
    im = Image.open(src).convert("RGB")
    im = im.resize((w, h), Image.LANCZOS)
    # 量化到 96 色，压体积同时保住像素风的色块感（不抖动，避免脏边）
    im = im.quantize(colors=96, method=Image.MEDIANCUT, dither=Image.NONE)
    im = im.convert("RGB")
    im.save(dst, optimize=True)
    print("OK", out_name + ".png", im.size, os.path.getsize(dst), "bytes")
print("DONE")

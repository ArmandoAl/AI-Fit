"""Create explicitly synthetic, aligned inputs without any personal photographs."""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent


def make(folder):
    folder.mkdir(parents=True, exist_ok=True)
    size = (768, 1024)
    body = Image.new('RGBA', size, '#ebe6df')
    draw = ImageDraw.Draw(body)
    draw.text((24, 24), 'AI FIT LAB - SYNTHETIC FIXTURE', fill='#282828', font_size=25)
    draw.text((24, 60), 'No person scan. No trained model.', fill='#555555', font_size=20)
    draw.ellipse((323, 126, 445, 284), fill='#c79e82')
    draw.rounded_rectangle((354, 260, 414, 330), radius=15, fill='#c79e82')
    draw.polygon([(289, 311), (479, 311), (460, 598), (307, 598)], fill='#c79e82')
    draw.line([(295, 326), (244, 557), (260, 658)], fill='#c79e82', width=42)
    draw.line([(473, 326), (525, 557), (510, 658)], fill='#c79e82', width=42)
    draw.line([(342, 583), (330, 904)], fill='#c79e82', width=62)
    draw.line([(427, 583), (439, 904)], fill='#c79e82', width=62)
    draw.ellipse((281, 890, 350, 935), fill='#3b3738')
    draw.ellipse((419, 890, 488, 935), fill='#3b3738')
    body.save(folder / 'body.png')
    top = Image.new('RGBA', size)
    draw = ImageDraw.Draw(top)
    draw.polygon([(290, 307), (344, 294), (384, 323), (424, 294), (478, 307), (507, 407), (464, 422), (455, 549), (312, 549), (302, 422), (260, 407)], fill='#c25177')
    draw.line([(314, 536), (454, 536)], fill='#78364d', width=4)
    draw.text((346, 395), 'TOP', fill='white', font_size=28)
    top.save(folder / 'top.png')
    bottom = Image.new('RGBA', size)
    draw = ImageDraw.Draw(bottom)
    draw.polygon([(310, 533), (458, 533), (472, 897), (410, 897), (384, 649), (359, 897), (297, 897)], fill='#394e71')
    draw.line([(313, 552), (456, 552)], fill='#d4be92', width=6)
    bottom.save(folder / 'bottom.png')
    spec = {'synthetic': True, 'canvas': list(size), 'layers': [
        {'image': 'body.png'}, {'image': 'bottom.png'},
        {'image': 'top.png', 'source_anchors': [[290, 307], [478, 307]], 'target_anchors': [[290, 307], [478, 307]]}]}
    (folder / 'manifest.json').write_text(json.dumps(spec, indent=2) + '\n')
    return folder / 'manifest.json'


if __name__ == '__main__':
    print(make(ROOT / 'private' / 'synthetic'))

"""Offline RGBA layer compositor with two-point alignment and content caching.

This aligns prepared assets; it does not infer garments or generate unseen skin.
"""
import argparse
import hashlib
import io
import json
import math
import statistics
import time
from pathlib import Path

from PIL import Image, ImageChops, __version__ as PILLOW_VERSION

ENGINE = 'aifit-layers-v1-pillow-' + PILLOW_VERSION
MAX_SIDE = 4096


def asset_path(folder, relative):
    if not isinstance(relative, str) or Path(relative).is_absolute():
        raise ValueError('Assets must be paths relative to the manifest directory.')
    target = (folder / relative).resolve()
    if not target.is_relative_to(folder.resolve()):
        raise ValueError('Asset escapes manifest directory.')
    return target


def alignment(source, target):
    """Inverse affine coefficients for a similarity transform between two anchors."""
    if len(source) != 2 or len(target) != 2 or any(len(p) != 2 for p in source + target):
        raise ValueError('Alignment requires two source and two target points.')
    values = [float(v) for p in source + target for v in p]
    if not all(math.isfinite(v) for v in values):
        raise ValueError('Anchor coordinates must be finite.')
    (sx, sy), (ex, ey) = source
    (tx, ty), (ux, uy) = target
    dx, dy = ex - sx, ey - sy
    denominator = dx * dx + dy * dy
    if denominator < 1e-8:
        raise ValueError('Source anchors must be distinct.')
    a = ((ux - tx) * dx + (uy - ty) * dy) / denominator
    b = ((uy - ty) * dx - (ux - tx) * dy) / denominator
    norm = a * a + b * b
    if norm < 1e-8:
        raise ValueError('Target anchors must be distinct.')
    cx, cy = tx - a * sx + b * sy, ty - b * sx - a * sy
    return (a / norm, b / norm, (-a * cx - b * cy) / norm,
            -b / norm, a / norm, (b * cx - a * cy) / norm)


def load(manifest):
    folder = manifest.resolve().parent
    spec = json.loads(manifest.read_text())
    size = spec['canvas']
    if len(size) != 2 or any(type(v) is not int or not 1 <= v <= MAX_SIDE for v in size):
        raise ValueError('Canvas must have two integer dimensions between 1 and 4096.')
    layers = spec['layers']
    if not isinstance(layers, list) or not 1 <= len(layers) <= 32:
        raise ValueError('Use between 1 and 32 layers, in back-to-front order.')
    fingerprint = hashlib.sha256(ENGINE.encode() + json.dumps(spec, sort_keys=True).encode())
    assets = {}
    for layer in layers:
        for field in ('image', 'mask'):
            if field not in layer:
                if field == 'image':
                    raise ValueError('Each layer requires an image.')
                continue
            name = layer[field]
            if name not in assets:
                path = asset_path(folder, name)
                if path.stat().st_size > 32 * 2**20:
                    raise ValueError('Asset exceeds 32 MiB.')
                data = path.read_bytes()
                fingerprint.update(name.encode() + hashlib.sha256(data).digest())
                with Image.open(io.BytesIO(data)) as original:
                    if max(original.size) > MAX_SIDE:
                        raise ValueError('Asset exceeds 4096 pixels; resize before composing.')
                    # Capture preparation must normalize orientation before adding anchors.
                    if original.getexif().get(274, 1) != 1:
                        raise ValueError('Normalize EXIF orientation before assigning anchors.')
                    assets[name] = original.convert('RGBA' if field == 'image' else 'L')
    return spec, assets, fingerprint.hexdigest()


def render(spec, assets):
    size = tuple(spec['canvas'])
    canvas = Image.new('RGBA', size, spec.get('background', '#ffffff'))
    for layer in spec['layers']:
        picture = assets[layer['image']].convert('RGBA').copy()
        if 'mask' in layer:
            mask = assets[layer['mask']].convert('L')
            if mask.size != picture.size:
                raise ValueError('Mask must match its source image dimensions.')
            picture.putalpha(ImageChops.multiply(picture.getchannel('A'), mask))
        if 'source_anchors' in layer or 'target_anchors' in layer:
            transform = alignment(layer['source_anchors'], layer['target_anchors'])
            picture = picture.transform(size, Image.Transform.AFFINE, transform, Image.Resampling.BICUBIC)
        elif picture.size != size:
            raise ValueError('Unaligned layers must match canvas dimensions.')
        canvas = Image.alpha_composite(canvas, picture)
    return canvas


def compose(manifest, output, repeat=1):
    if not 1 <= repeat <= 100:
        raise ValueError('Benchmark repeats must be between 1 and 100.')
    started = time.perf_counter()
    spec, assets, fingerprint = load(manifest)
    sidecar = output.with_suffix('.json')
    if repeat == 1 and output.exists() and sidecar.exists():
        try:
            previous = json.loads(sidecar.read_text())
            if (previous.get('fingerprint') == fingerprint and
                previous.get('image_sha256') == hashlib.sha256(output.read_bytes()).hexdigest()):
                return {'cache_hit': True, 'elapsed_ms': round((time.perf_counter() - started) * 1000, 2), 'fingerprint': fingerprint}
        except (ValueError, OSError):
            pass
    samples = []
    for _ in range(repeat):
        start = time.perf_counter()
        picture = render(spec, assets)
        samples.append((time.perf_counter() - start) * 1000)
    output.parent.mkdir(parents=True, exist_ok=True)
    picture.save(output, format='PNG')
    result = {'engine': ENGINE, 'cache_hit': False, 'fingerprint': fingerprint,
              'canvas': spec['canvas'], 'layers': len(spec['layers']), 'repeat': repeat,
              'render_median_ms': round(statistics.median(samples), 2),
              'render_max_ms': round(max(samples), 2),
              'total_ms': round((time.perf_counter() - started) * 1000, 2),
              'image_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
              'synthetic': spec.get('synthetic', False)}
    sidecar.write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--repeat', type=int, default=1)
    args = parser.parse_args()
    print(json.dumps(compose(args.manifest, args.output, args.repeat), indent=2))

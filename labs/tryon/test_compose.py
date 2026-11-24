import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from compose import alignment, asset_path, compose, load, render


class ComposerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = self.root / 'manifest.json'
        Image.new('RGBA', (16, 16), 'red').save(self.root / 'base.png')
        Image.new('RGBA', (16, 16), (0, 0, 255, 128)).save(self.root / 'top.png')
        self.spec = {'canvas': [16, 16], 'layers': [{'image': 'base.png'}, {'image': 'top.png'}]}
        self.write()

    def write(self):
        self.manifest.write_text(json.dumps(self.spec))

    def test_transparent_layers_preserve_underlying_color(self):
        spec, assets, _ = load(self.manifest)
        pixel = render(spec, assets).getpixel((5, 5))
        self.assertEqual(pixel, (127, 0, 128, 255))

    def test_mask_preserves_foreground(self):
        Image.new('L', (16, 16), 0).save(self.root / 'mask.png')
        self.spec['layers'][1]['mask'] = 'mask.png'
        self.write()
        spec, assets, _ = load(self.manifest)
        self.assertEqual(render(spec, assets).getpixel((5, 5)), (255, 0, 0, 255))

    def test_alignment_translation_and_rotation(self):
        coeff = alignment([[0, 0], [10, 0]], [[4, 5], [4, 25]])
        a, b, c, d, e, f = coeff
        for source, target in [((0, 0), (4, 5)), ((10, 0), (4, 25)), ((0, 10), (-16, 5))]:
            self.assertAlmostEqual(a * target[0] + b * target[1] + c, source[0])
            self.assertAlmostEqual(d * target[0] + e * target[1] + f, source[1])

    def test_degenerate_anchors_rejected(self):
        with self.assertRaises(ValueError):
            alignment([[0, 0], [0, 0]], [[0, 0], [1, 0]])

    def test_cache_invalidates_when_asset_changes(self):
        output = self.root / 'result.png'
        first = compose(self.manifest, output)
        self.assertFalse(first['cache_hit'])
        self.assertTrue(compose(self.manifest, output)['cache_hit'])
        Image.new('RGBA', (16, 16), 'green').save(self.root / 'top.png')
        third = compose(self.manifest, output)
        self.assertFalse(third['cache_hit'])
        self.assertNotEqual(first['fingerprint'], third['fingerprint'])

    def test_cache_rejects_corrupt_result(self):
        output = self.root / 'result.png'
        compose(self.manifest, output)
        output.write_bytes(b'corrupt')
        self.assertFalse(compose(self.manifest, output)['cache_hit'])
        with Image.open(output) as result:
            self.assertEqual(result.size, (16, 16))

    def test_paths_and_size_rejected(self):
        with self.assertRaises(ValueError):
            asset_path(self.root, '../outside.png')
        self.spec['canvas'] = [100000, 16]
        self.write()
        with self.assertRaises(ValueError):
            load(self.manifest)


if __name__ == '__main__':
    unittest.main()

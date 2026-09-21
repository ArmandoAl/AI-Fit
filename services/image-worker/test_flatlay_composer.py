import unittest
from PIL import Image
from flatlay_composer import (
    CANVAS_SIZE,
    compose_flatlay,
    export_flatlay_jpeg,
    fit_and_center_in_slot,
    normalize_category_key,
)


class TestFlatlayComposer(unittest.TestCase):
    def setUp(self):
        # Create dummy RGBA cutout images
        self.dress = Image.new("RGBA", (400, 700), (255, 0, 128, 255))
        self.top = Image.new("RGBA", (500, 400), (0, 200, 255, 255))
        self.bottom = Image.new("RGBA", (400, 600), (50, 50, 50, 255))
        self.shoes = Image.new("RGBA", (350, 250), (20, 20, 20, 255))
        self.coat = Image.new("RGBA", (500, 600), (120, 60, 200, 255))
        self.scarf = Image.new("RGBA", (150, 400), (220, 20, 60, 255))
        self.bag = Image.new("RGBA", (250, 250), (200, 160, 40, 255))

    def test_normalize_category_key(self):
        self.assertEqual(normalize_category_key("one_piece"), "one_piece")
        self.assertEqual(normalize_category_key("one-piece"), "one_piece")
        self.assertEqual(normalize_category_key("dress"), "one_piece")
        self.assertEqual(normalize_category_key("vestido"), "one_piece")
        self.assertEqual(normalize_category_key("jumpsuit"), "one_piece")
        self.assertEqual(normalize_category_key("enterizo"), "one_piece")
        self.assertEqual(normalize_category_key("accessories"), "accessories")
        self.assertEqual(normalize_category_key("accessory"), "accessories")
        self.assertEqual(normalize_category_key("scarf"), "accessories")
        self.assertEqual(normalize_category_key("bag"), "accessories")
        self.assertEqual(normalize_category_key("bolso"), "accessories")
        self.assertEqual(normalize_category_key("top"), "top")
        self.assertEqual(normalize_category_key("bottom"), "bottom")
        self.assertEqual(normalize_category_key("shoes"), "shoes")

    def test_fit_and_center_in_slot_aspect_ratio(self):
        slot = (50, 50, 400, 400)
        # Image 400x700 aspect ratio should be preserved
        fitted, (ox, oy) = fit_and_center_in_slot(self.dress, slot)
        w, h = fitted.size
        # height should be scaled to fit slot height (400)
        self.assertLessEqual(w, 400)
        self.assertLessEqual(h, 400)
        # Check aspect ratio 400/700 approx 0.5714
        ratio = w / h
        expected_ratio = 400 / 700
        self.assertAlmostEqual(ratio, expected_ratio, places=2)
        # Verify it is centered horizontally inside slot
        self.assertGreaterEqual(ox, 50)
        self.assertLessEqual(ox + w, 450)

    def test_one_piece_mode_without_outerwear(self):
        items = {
            "one_piece": self.dress,
            "shoes": self.shoes,
        }
        canvas = compose_flatlay(items, extra_accessories=[self.scarf, self.bag])
        self.assertEqual(canvas.size, CANVAS_SIZE)
        self.assertEqual(canvas.mode, "RGB")

        # Verify export to JPEG
        jpeg_bytes = export_flatlay_jpeg(canvas, quality=85)
        self.assertGreater(len(jpeg_bytes), 0)
        self.assertLessEqual(len(jpeg_bytes), 900 * 1024)

    def test_one_piece_mode_with_outerwear(self):
        items = {
            "one_piece": self.dress,
            "shoes": self.shoes,
            "outerwear": self.coat,
            "accessories": [self.bag],
        }
        canvas = compose_flatlay(items)
        self.assertEqual(canvas.size, CANVAS_SIZE)
        jpeg_bytes = export_flatlay_jpeg(canvas)
        self.assertGreater(len(jpeg_bytes), 0)

    def test_two_piece_mode_with_accessories(self):
        items = {
            "top": self.top,
            "bottom": self.bottom,
            "shoes": self.shoes,
            "accessories": [self.scarf, self.bag],
        }
        canvas = compose_flatlay(items)
        self.assertEqual(canvas.size, CANVAS_SIZE)
        jpeg_bytes = export_flatlay_jpeg(canvas)
        self.assertGreater(len(jpeg_bytes), 0)
        self.assertLessEqual(len(jpeg_bytes), 900 * 1024)

    def test_two_piece_mode_with_outerwear_and_accessories(self):
        items = {
            "outerwear": self.coat,
            "top": self.top,
            "bottom": self.bottom,
            "shoes": self.shoes,
            "accessories": [self.scarf, self.bag],
        }
        canvas = compose_flatlay(items)
        self.assertEqual(canvas.size, CANVAS_SIZE)
        jpeg_bytes = export_flatlay_jpeg(canvas)
        self.assertGreater(len(jpeg_bytes), 0)


if __name__ == "__main__":
    unittest.main()

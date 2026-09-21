import unittest
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
from pydantic import ValidationError

from main import is_valid_uuid, process_wardrobe_item, ProcessItemRequest


class TestUuidValidationAndDefensiveHandling(unittest.IsolatedAsyncioTestCase):
    def test_is_valid_uuid(self):
        # Valid UUIDs
        self.assertTrue(is_valid_uuid("73046e91-384f-4161-b870-34676ffbe97b"))
        self.assertTrue(is_valid_uuid("123e4567-e89b-12d3-a456-426614174000"))
        self.assertTrue(is_valid_uuid("00000000-0000-1000-8000-000000000000"))

        # Invalid UUIDs
        self.assertFalse(is_valid_uuid("test-item-curl"))
        self.assertFalse(is_valid_uuid("12345"))
        self.assertFalse(is_valid_uuid(""))
        self.assertFalse(is_valid_uuid(None))
        self.assertFalse(is_valid_uuid("not-a-valid-uuid-format"))

    async def test_invalid_item_id_raises_http_400(self):
        payload = ProcessItemRequest(
            itemId="test-item-curl",
            userId="73046e91-384f-4161-b870-34676ffbe97b",
            imageUrl="https://example.com/item.jpg",
        )
        with self.assertRaises(HTTPException) as ctx:
            await process_wardrobe_item(payload)
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("Invalid itemId format", ctx.exception.detail)

    async def test_invalid_user_id_raises_http_400(self):
        payload = ProcessItemRequest(
            itemId="73046e91-384f-4161-b870-34676ffbe97b",
            userId="not-a-valid-uuid",
            imageUrl="https://example.com/item.jpg",
        )
        with self.assertRaises(HTTPException) as ctx:
            await process_wardrobe_item(payload)
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("Invalid userId format", ctx.exception.detail)

    @patch("main.get_supabase")
    async def test_item_not_found_raises_http_404(self, mock_get_supabase):
        mock_supabase = MagicMock()
        mock_table = MagicMock()
        mock_select = MagicMock()
        mock_eq1 = MagicMock()
        mock_eq2 = MagicMock()
        mock_single = MagicMock()
        mock_exec = MagicMock()

        mock_exec.execute.return_value = MagicMock(data=None)
        mock_single.maybe_single.return_value = mock_exec
        mock_eq2.eq.return_value = mock_single
        mock_eq1.eq.return_value = mock_eq2
        mock_select.select.return_value = mock_eq1
        mock_table.table.return_value = mock_select
        mock_get_supabase.return_value = mock_table

        payload = ProcessItemRequest(
            itemId="73046e91-384f-4161-b870-34676ffbe97b",
            userId="a0000000-0000-0000-0000-000000000001",
            imageUrl="https://example.com/item.jpg",
        )

        with self.assertRaises(HTTPException) as ctx:
            await process_wardrobe_item(payload)
        self.assertEqual(ctx.exception.status_code, 404)
        self.assertIn("not found in database", ctx.exception.detail)


if __name__ == "__main__":
    unittest.main()

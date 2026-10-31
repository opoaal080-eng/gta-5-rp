import tempfile
import unittest
from pathlib import Path
from audit_assets import audit

class AuditTest(unittest.TestCase):
    def test_detects_exact_duplicates_but_not_same_size_different_data(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "data").mkdir()
            (root / "data" / "one.rpf").write_bytes(b"hello")
            (root / "data" / "two.rpf").write_bytes(b"hello")
            (root / "data" / "three.rpf").write_bytes(b"world")
            report = audit(root, hash_duplicates=True)
            self.assertEqual(report["bytes"], 15)
            self.assertEqual(report["exact_duplicate_savings"], 5)
            self.assertEqual(report["files"], 3)
            self.assertEqual(len(report["exact_duplicates"]), 1)

    def test_not_modify_data(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            path = root / "data.bin"
            path.write_bytes(b"unchanged")
            audit(root)
            self.assertEqual(path.read_bytes(), b"unchanged")

if __name__ == "__main__":
    unittest.main()

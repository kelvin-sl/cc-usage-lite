"""Checks that benchmark results cannot silently measure empty or failed work."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


class BenchmarkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("benchmark", Path(__file__).with_name("benchmark.py"))
        cls.bench = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.bench)

    def test_fixture_has_unique_billable_messages_and_requested_size(self):
        with tempfile.TemporaryDirectory() as tmp:
            data = self.bench.make_history(Path(tmp), 1, 2)
            files = list(Path(tmp).glob("projects/*/*.jsonl"))
            rows = [json.loads(line) for file in files for line in file.read_text().splitlines()]
            self.assertEqual(len(files), 2)
            self.assertGreaterEqual(sum(file.stat().st_size for file in files), 1024 * 1024)
            self.assertEqual(len({row["requestId"] for row in rows}), len(rows))
            self.assertEqual(data["input_tokens"], len(rows) * 100)
            self.assertTrue(all(row["message"]["usage"]["input_tokens"] == 100 for row in rows))

    def test_memory_units_are_normalized_without_summing_process_peaks(self):
        self.assertEqual(self.bench.peak_rss_mib(" 2097152  maximum resident set size\n", "Darwin"), 2)
        self.assertEqual(self.bench.peak_rss_mib("Maximum resident set size (kbytes): 2048\n", "Linux"), 2)
        self.assertIsNone(self.bench.peak_rss_mib("", "Windows"))

    def test_failed_or_empty_command_is_not_a_successful_measurement(self):
        import os
        import sys
        with tempfile.TemporaryDirectory() as tmp:
            for code in ("raise SystemExit(7)", "pass", "print('statusline error')"):
                with self.subTest(code=code), self.assertRaises(RuntimeError):
                    self.bench.measure([sys.executable, "-c", code], "{}", os.environ.copy(), Path(tmp), "sample", 5)


if __name__ == "__main__":
    unittest.main()

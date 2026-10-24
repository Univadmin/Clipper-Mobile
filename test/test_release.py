import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('publisher', ROOT / 'scripts/publish_release.py')
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)

class ReleaseTests(unittest.TestCase):
    def test_downloads_only_lists_published_apks_and_uses_istanbul_date(self):
        def release(tag, date, draft=False, prerelease=False, asset=True):
            return {'tag_name': tag, 'published_at': date, 'draft': draft, 'prerelease': prerelease,
                    'assets': [{'name': 'Clipper.apk', 'size': 10, 'browser_download_url': 'https://example.test/'+tag}] if asset else []}
        text = publisher.render_downloads([
            release('v1.0.1+2', '2026-10-24T22:30:00Z'),
            release('v1.0.2+3', '2026-10-25T10:00:00Z'),
            release('v2.0.0+4', None, draft=True),
            release('v2.0.1+5', '2026-10-25T11:00:00Z', prerelease=True),
            release('v2.0.2+6', '2026-10-25T12:00:00Z', asset=False),
        ])
        self.assertIn('| 1.0.1+2 | 25.10.2026 |', text)
        self.assertLess(text.index('| 1.0.2+3'), text.index('| 1.0.1+2'))
        self.assertNotIn('2.0.0+4', text)
        self.assertNotIn('2.0.1+5', text)
        self.assertNotIn('2.0.2+6', text)
        self.assertIn('/releases/latest/download/Clipper.apk', text)

if __name__ == '__main__':
    unittest.main()

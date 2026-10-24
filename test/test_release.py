import importlib.util
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch, Mock
import json

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

    def test_new_draft_can_be_verified_and_published_without_by_tag_lookup(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'pubspec.yaml').write_text('version: 1.0.1+2\n')
            apk = root / 'build/app/outputs/flutter-apk/app-release.apk'
            apk.parent.mkdir(parents=True)
            apk.write_bytes(bytes(1000001))
            draft = {'tag_name': 'v1.0.1+2', 'draft': True,
                     'assets': [{'name': 'Clipper.apk', 'size': 1000001}]}
            ref = Mock(returncode=0, stdout=json.dumps({'object': {'sha': 'source-sha'}}))
            with patch.object(publisher, 'ROOT', root), \
                 patch.object(publisher, 'all_releases', side_effect=[[], [], [draft]]), \
                 patch.object(publisher, 'gh', return_value='') as api, \
                 patch.object(publisher, 'finish_draft') as finish, \
                 patch.object(publisher.subprocess, 'run', return_value=ref), \
                 patch.object(publisher.subprocess, 'check_output', return_value='source-sha'), \
                 patch.dict(publisher.os.environ, {'GITHUB_REF_TYPE': 'branch'}, clear=False):
                publisher.publish()
            finish.assert_called_once_with('v1.0.1+2')
            self.assertFalse(any('/releases/tags/' in str(call) for call in api.call_args_list))

    def test_draft_finishing_checks_the_server_digest_before_publication(self):
        digest = 'a' * 64
        draft = {'tag_name': 'v1.0.1+2', 'draft': True, 'assets': [
            {'name': 'Clipper.apk', 'size': 1000001, 'digest': 'sha256:' + digest},
            {'name': 'SHA256SUMS', 'size': 78},
        ]}
        with patch.object(publisher, 'all_releases', return_value=[draft]), \
             patch.object(publisher, 'gh', return_value=digest + '  Clipper.apk\n') as api, \
             patch.object(publisher, 'refresh_downloads') as refresh:
            publisher.finish_draft('v1.0.1+2')
        api.assert_any_call('release', 'edit', 'v1.0.1+2', '--repo', publisher.REPO, '--draft=false', '--latest')
        refresh.assert_called_once()
        with patch.object(publisher, 'all_releases', return_value=[draft]), \
             patch.object(publisher, 'gh', return_value='b' * 64 + '  Clipper.apk\n') as api:
            with self.assertRaises(ValueError):
                publisher.finish_draft('v1.0.1+2')
        self.assertFalse(any(call.args[:2] == ('release', 'edit') for call in api.call_args_list))

if __name__ == '__main__':
    unittest.main()

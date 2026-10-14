import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('bridge', Path(__file__).with_name('sync.py'))
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)

class BridgeTests(unittest.TestCase):
    def test_rejects_self_sync_and_untrusted_repositories(self):
        for source, target in [('macfanpro/macfanpro', 'macfanpro/macfanpro'), ('attacker/repo', 'macfanpro/update-compat'), ('macfancontrol/macfancontrol', 'someone/repo')]:
            with self.assertRaises(ValueError):
                bridge.sync(source, target)

    def test_bad_source_digest_never_uploads_or_publishes(self):
        release = {'tag_name': 'v0.2.3.64', 'name': 'MacFanControl', 'body': '', 'draft': False, 'prerelease': False,
                   'assets': [{'name': 'app.tar.gz', 'size': 3, 'digest': 'sha256:expected', 'browser_download_url': 'https://github.com/asset'}]}
        dest = {**release, 'draft': True, 'assets': [], 'id': 1}
        import json
        def command(*args):
            if '--slurp' in args:
                return json.dumps([[release if 'macfancontrol/macfancontrol' in args[-1] else dest]])
            raise AssertionError('Unexpected mutation: ' + str(args))
        with patch.object(bridge, 'gh', side_effect=command), patch.object(bridge, 'api', return_value={'tag_name':'v0.2.3.64'}), patch.object(bridge, 'download', return_value='sha256:wrong'):
            with self.assertRaisesRegex(ValueError, 'Source checksum mismatch'):
                bridge.sync('macfancontrol/macfancontrol', 'macfanpro/update-compat')

    def test_download_rejects_non_github_asset(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaises(ValueError):
                bridge.download('https://example.org/asset', Path(root)/'asset')

if __name__ == '__main__':
    unittest.main()

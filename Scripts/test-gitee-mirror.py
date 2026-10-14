#!/usr/bin/env python3
"""Offline mirror regression checks; no credentials or network calls."""
import copy
import hashlib
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

spec = importlib.util.spec_from_file_location("mirror", Path(__file__).with_name("mirror-gitee.py"))
mirror = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mirror)


class Fixture:
    def __init__(self):
        self.release = None
        self.assets = []
        self.content = {}
        self.calls = []

    def pages(self, endpoint):
        return copy.deepcopy(self.assets)

    def call(self, method, endpoint, values=None, upload=None):
        self.calls.append((method, endpoint))
        if method == "GET":
            return copy.deepcopy(self.release)
        if method == "POST" and endpoint.endswith("/releases"):
            self.release = {**values, "id": 1}
            return copy.deepcopy(self.release)
        if upload:
            asset = {"name": upload.name, "size": upload.stat().st_size, "id": len(self.assets) + 1,
                     "browser_download_url": "https://gitee.com/download/" + upload.name}
            self.assets.append(asset)
            self.content[asset["browser_download_url"]] = upload.read_bytes()
            return copy.deepcopy(asset)
        if method == "PATCH":
            self.release.update(values)
            return copy.deepcopy(self.release)
        if method == "DELETE":
            self.assets = [a for a in self.assets if not endpoint.endswith("/" + str(a["id"]))]
            return None
        raise AssertionError((method, endpoint))

    def download(self, url, path, host):
        data = self.content[url]
        path.write_bytes(data)
        return hashlib.sha256(data).hexdigest()


class MirrorTests(unittest.TestCase):
    def test_old_github_download_links_are_rewritten_after_transfer(self):
        old = "https://github.com/macfanpro/macfanpro/releases/download/v1/app.dmg"
        source = [{"name": "app.dmg", "browser_download_url": old.replace("macfanpro/macfanpro", "macfancontrol/macfancontrol")}]
        target = [{"name": "app.dmg", "browser_download_url": "https://gitee.com/download/app.dmg"}]
        self.assertEqual(mirror.rewrite_downloads(old, source, target), target[0]["browser_download_url"])

    def test_download_links_keep_checksum_suffixes_and_evidence(self):
        prefix = "https://github.com/macfancontrol/macfancontrol/releases/download/v1/"
        original = [{"name": name, "browser_download_url": prefix + name}
                    for name in ["app.dmg", "app.dmg.sha256"]]
        target = [{"name": name, "browser_download_url": "https://gitee.com/download/" + name}
                  for name in ["app.dmg", "app.dmg.sha256"]]
        body = prefix + "app.dmg " + prefix + "app.dmg.sha256 https://github.com/macfancontrol/macfancontrol/actions/runs/1"
        result = mirror.rewrite_downloads(body, original, target)
        self.assertEqual(result, "https://gitee.com/download/app.dmg https://gitee.com/download/app.dmg.sha256 "
                                "https://github.com/macfancontrol/macfancontrol/actions/runs/1")

    def test_attachment_names_cannot_escape_or_break_multipart_headers(self):
        for name in ["", ".", "..", "../key", "/tmp/key", "a\\b", 'a"b', "a\r\nb"]:
            with self.subTest(name=name), self.assertRaises(mirror.MirrorError):
                mirror.safe_name(name)
        mirror.safe_name("MacFanControl-0.2.3.63-macos-arm64.dmg")

    def test_restart_is_idempotent_and_corrupt_destination_is_preserved(self):
        api = Fixture()
        url = "https://github.com/download/app.dmg"
        api.content[url] = b"original signed application"
        source = {"tag_name": "v1", "name": "Release 1", "body": "Download: " + url, "prerelease": False,
                  "assets": [{"name": "app.dmg", "size": len(api.content[url]), "browser_download_url": url,
                              "digest": "sha256:" + hashlib.sha256(api.content[url]).hexdigest()}]}
        with tempfile.TemporaryDirectory() as folder, patch.object(mirror, "command", return_value="commit"), \
                patch.object(mirror, "download", side_effect=api.download):
            path = Path(folder)
            mirror.mirror_release(api, source, path, path)
            creates = sum(method == "POST" for method, _ in api.calls)
            mirror.mirror_release(api, source, path, path)
            self.assertEqual(creates, sum(method == "POST" for method, _ in api.calls))
            self.assertIn("https://gitee.com/download/app.dmg", api.release["body"])
            api.content[api.assets[0]["browser_download_url"]] = b"different content"
            api.calls.clear()
            with self.assertRaisesRegex(mirror.MirrorError, "digest mismatch"):
                mirror.mirror_release(api, source, path, path)
            self.assertFalse(any(method in {"POST", "DELETE", "PATCH"} for method, _ in api.calls))
            self.assertEqual(len(api.assets), 1)

    def test_github_digest_failure_prevents_attachment_upload(self):
        api = Fixture()
        url = "https://github.com/download/app.dmg"
        api.content[url] = b"damaged"
        source = {"tag_name": "v1", "name": "Release 1", "body": "Download", "prerelease": False,
                  "assets": [{"name": "app.dmg", "size": 7, "browser_download_url": url, "digest": "sha256:wrong"}]}
        with tempfile.TemporaryDirectory() as folder, patch.object(mirror, "command", return_value="commit"), \
                patch.object(mirror, "download", side_effect=api.download):
            path = Path(folder)
            with self.assertRaisesRegex(mirror.MirrorError, "GitHub attachment"):
                mirror.mirror_release(api, source, path, path)
            self.assertEqual(api.assets, [])

    def test_api_errors_redact_credentials(self):
        token = "test-secret-only"
        error = urllib.error.HTTPError("https://gitee.com/api", 401, "Unauthorized", {},
                                       io.BytesIO(b'{"message":"bad token test-secret-only"}'))
        with patch.object(mirror.urllib.request, "urlopen", side_effect=error):
            with self.assertRaises(mirror.APIError) as result:
                mirror.Gitee(token).call("GET", "/user")
        self.assertNotIn(token, str(result.exception))
        self.assertIn("[redacted]", str(result.exception))

    def test_single_release_retry_never_prunes_other_releases(self):
        api = Fixture()
        releases = [{"tag_name": tag, "published_at": "2026-10-11"} for tag in ["v1", "v2"]]
        with patch.dict(os.environ, {"GITEE_TOKEN": "offline-test"}), \
                patch.object(mirror, "Gitee", return_value=api), \
                patch.object(mirror, "mirror_refs", return_value=Path("unused")), \
                patch.object(mirror, "github_releases", return_value=releases), \
                patch.object(mirror, "mirror_release") as sync, \
                patch.object(api, "pages", side_effect=AssertionError("single retry must not prune")):
            with patch("sys.argv", ["mirror", "--tag", "v1"]):
                mirror.main()
            self.assertEqual(sync.call_count, 1)
            self.assertEqual(sync.call_args.args[1]["tag_name"], "v1")
            sync.reset_mock()
            with patch("sys.argv", ["mirror", "--tag", "missing"]):
                with self.assertRaisesRegex(mirror.MirrorError, "No published"):
                    mirror.main()
            sync.assert_not_called()
            self.assertEqual(api.calls, [])


if __name__ == "__main__":
    unittest.main(verbosity=2)

#!/usr/bin/env python3
"""Isolated installer integration tests. No network, sudo, SMC or installed-app writes.

Use real bash, tar, SHA256 and plist parsing with temporary release fixtures;
replace only OS/network/signing/installation boundaries in the sourced script.
"""
import hashlib
import io
import os
from pathlib import Path
import plistlib
import subprocess
import tarfile
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().with_name('install.sh')
VERSION = '1.2.3.4'
NAME = f'MacFanPro-{VERSION}-macos-arm64'

HARNESS = r'''
source "$SCRIPT"
uname() { if [ "$1" = -s ]; then echo "${OS:-Darwin}"; else echo "${ARCH:-arm64}"; fi; }
sw_vers() { echo "${MACOS:-14.0}"; }
id() { echo "${UID_FIXTURE:-501}"; }
scutil() { printf 'HTTPSEnable : 1\nHTTPSProxy : proxy.test\nHTTPSPort : 8080\n'; }
installed_versions() { printf '%s' "${INSTALLED:-}"; }
find_brew() { if [ "${BREW_FIXTURE:-0}" = 1 ]; then echo "$FIXTURE/brew"; fi; }
codesign() { echo codesign >> "$EVENTS"; [ "${BAD_SIGN:-0}" = 0 ]; }
curl() {
    echo "curl $* proxy=${https_proxy:-}" >> "$EVENTS"
    [ "${BAD_DOWNLOAD:-0}" = 0 ] || return 22
    local dest='' url=''
    while [ "$#" -gt 0 ]; do
        if [ "$1" = --output ]; then shift; dest="$1"; fi
        url="$1"; shift
    done
    case "$url" in
        https://github.com/macfanpro/macfanpro/releases/download/v1.2.3.4/*) ;;
        *) return 99 ;;
    esac
    cp "$FIXTURE/${url##*/}" "$dest"
}
sudo() {
    echo "sudo $*" >> "$EVENTS"
    [ "${NO_SUDO:-0}" = 0 ] || return 1
    if [ "$1" != -v ]; then "$@"; fi
}
verify_installation() {
    echo verify-installed >> "$EVENTS"
    [ "${BAD_SERVICE:-0}" = 0 ] || return 1
    [ "$(cat "$FIXTURE/installed")" = "$1" ]
}
open() { echo open >> "$EVENTS"; }
main "$@"
'''

CLI = '''#!/bin/bash
case "$1" in
 --version) echo "${CLI_VERSION:-1.2.3.4}" ;;
 auto) echo stop-app >> "$EVENTS" ;;
 install)
   echo "install $*" >> "$EVENTS"
   [ "${BAD_INSTALL:-0}" = 0 ] || exit 1
   echo "${CLI_VERSION:-1.2.3.4}" > "$FIXTURE/installed" ;;
 *) exit 2 ;;
esac
'''
BREW = '''#!/bin/bash
echo "brew $*" >> "$EVENTS"
case "$1" in
 update|upgrade) [ "${BAD_BREW:-0}" = 0 ] ;;
 --prefix) echo "$FIXTURE/keg" ;;
 *) exit 2 ;;
esac
'''

class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='macfanpro-installer-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.pkg = self.root / 'keg'
        (self.pkg / 'bin').mkdir(parents=True)
        cli = self.pkg / 'bin/macfanpro'
        cli.write_text(CLI)
        cli.chmod(0o755)
        app = self.pkg / 'MacFanPro.app/Contents'
        app.mkdir(parents=True)
        (app / 'Info.plist').write_bytes(plistlib.dumps(dict(
            CFBundleIdentifier='io.github.macfanpro.app',
            CFBundleShortVersionString=VERSION, CFBundleVersion=VERSION)))
        (self.root / 'brew').write_text(BREW)
        (self.root / 'brew').chmod(0o755)
        (self.root / 'tmp').mkdir()
        self.events = self.root / 'events'
        self.pack()

    def pack(self, malicious=None, kind=None):
        archive = self.root / f'{NAME}.tar.gz'
        with tarfile.open(archive, 'w:gz', format=tarfile.USTAR_FORMAT) as tar:
            tar.add(self.pkg, arcname=NAME)
            if malicious:
                entry = tarfile.TarInfo(malicious)
                if kind == 'symlink':
                    entry.type, entry.linkname = tarfile.SYMTYPE, '../../escape'
                    tar.addfile(entry)
                elif kind == 'hardlink':
                    entry.type, entry.linkname = tarfile.LNKTYPE, '/etc/passwd'
                    tar.addfile(entry)
                else:
                    entry.size = 1
                    tar.addfile(entry, io.BytesIO(b'x'))
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        self.manifest = self.root / 'SHA256SUMS'
        self.manifest.write_text(f'{digest}  {archive.name}\n')

    def run_installer(self, *args, success=True, **overrides):
        env = dict(os.environ)
        for name in ('https_proxy', 'HTTPS_PROXY', 'all_proxy', 'ALL_PROXY'):
            env.pop(name, None)
        env.update(SCRIPT=str(SCRIPT), FIXTURE=str(self.root), EVENTS=str(self.events),
                   TMPDIR=str(self.root / 'tmp'))
        env.update(overrides)
        result = subprocess.run(['/bin/bash', '-c', HARNESS, 'installer-test', '--version', VERSION, *args],
                                env=env, text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        self.assertEqual(list((self.root / 'tmp').iterdir()), [], 'temporary downloads were not removed')
        events = self.events.read_text() if self.events.exists() else ''
        if not success:
            self.assertNotIn('installed and the background service is running', result.stdout)
        return result, events

    def test_fresh_upgrade_and_reinstall(self):
        for installed in ('', '1.2.3.3', VERSION):
            with self.subTest(installed=installed):
                self.events.unlink(missing_ok=True)
                result, events = self.run_installer(INSTALLED=installed)
                order = [events.index(x) for x in ('curl ', 'codesign', 'sudo -v', 'stop-app', 'install install', 'verify-installed', '\nopen')]
                self.assertEqual(order, sorted(order))
                self.assertIn('installed and the background service is running', result.stdout)
                self.assertIn('--proto =https --proto-redir =https', events)

    def test_check_never_installs_even_with_homebrew(self):
        _, events = self.run_installer('--check', BREW_FIXTURE='1', INSTALLED='9.0.0')
        self.assertIn('codesign', events)
        for forbidden in ('sudo ', 'stop-app', 'brew ', '\nopen'):
            self.assertNotIn(forbidden, events)

    def test_no_open_and_explicit_migration(self):
        _, events = self.run_installer('--no-open', '--migrate-thermalforge')
        self.assertIn('install --migrate-thermalforge', events)
        self.assertNotIn('\nopen', events)

    def test_downgrade_refused(self):
        _, events = self.run_installer(success=False, INSTALLED='1.2.3.10')
        self.assertEqual(events, '')

    def test_download_signature_and_cli_fail_before_stop(self):
        for override in ({'BAD_DOWNLOAD':'1'}, {'BAD_SIGN':'1'}, {'CLI_VERSION':'8.0.0'}, {'NO_SUDO':'1'}):
            with self.subTest(override=override):
                self.events.unlink(missing_ok=True)
                _, events = self.run_installer(success=False, **override)
                self.assertNotIn('stop-app', events)
                self.assertNotIn('install install', events)

    def test_app_identity_and_version(self):
        path = self.pkg / 'MacFanPro.app/Contents/Info.plist'
        original = plistlib.loads(path.read_bytes())
        for key, value in [('CFBundleIdentifier','bad.app'), ('CFBundleVersion','9.0.0'), ('CFBundleShortVersionString','9.0.0')]:
            with self.subTest(key=key):
                path.write_bytes(plistlib.dumps(dict(original, **{key:value})))
                self.pack()
                _, events = self.run_installer(success=False)
                self.assertNotIn('stop-app', events)

    def test_checksums_reject_corrupt_missing_duplicate(self):
        original = self.manifest.read_text()
        for manifest in ('0'*64 + f'  {NAME}.tar.gz\n', '', original + original):
            with self.subTest(manifest=manifest):
                self.manifest.write_text(manifest)
                _, events = self.run_installer(success=False)
                self.assertNotIn('codesign', events)
                self.assertNotIn('stop-app', events)

    def test_unrelated_checksum_does_not_break_old_manifest_contract(self):
        self.manifest.write_text(self.manifest.read_text() + '0'*64 + '  install.sh\n')
        self.run_installer('--check')

    def test_unsafe_archive_members(self):
        for path, kind in [('../escape',None), ('/absolute',None), (f'{NAME}/../escape',None), ('other/file',None),
                           (f'{NAME}/link','symlink'), (f'{NAME}/link','hardlink')]:
            with self.subTest(path=path, kind=kind):
                self.pack(path, kind)
                _, events = self.run_installer(success=False)
                self.assertNotIn('codesign', events)
                self.assertFalse((self.root / 'escape').exists())

    def test_failed_install_or_service_never_opens_app(self):
        for override in ({'BAD_INSTALL':'1'}, {'BAD_SERVICE':'1'}):
            with self.subTest(override=override):
                _, events = self.run_installer(success=False, **override)
                self.assertNotIn('\nopen', events)

    def test_homebrew_keeps_ownership(self):
        _, events = self.run_installer('--homebrew', BREW_FIXTURE='1')
        self.assertIn('brew upgrade macfanpro', events)
        self.assertIn('install install', events)
        self.assertNotIn('curl ', events)

    def test_homebrew_unavailable_or_behind(self):
        for override in ({}, {'BREW_FIXTURE':'1','CLI_VERSION':'1.2.3.3'}, {'BREW_FIXTURE':'1','BAD_BREW':'1'}):
            with self.subTest(override=override):
                _, events = self.run_installer('--homebrew', success=False, **override)
                self.assertNotIn('stop-app', events)
                self.assertNotIn('curl ', events)

    def test_platform_root_and_invalid_arguments(self):
        for override in ({'ARCH':'x86_64'}, {'OS':'Linux'}, {'MACOS':'13.6'}, {'UID_FIXTURE':'0'}):
            with self.subTest(override=override):
                _, events = self.run_installer(success=False, **override)
                self.assertEqual(events, '')
        self.run_installer('--version', '1.2.3;echo unsafe', success=False)
        self.run_installer('--unknown', success=False)
        self.run_installer('--version', success=False)

    def test_proxy_respects_environment(self):
        for proxy in ('http://custom.test:1234', ''):
            self.events.unlink(missing_ok=True)
            _, events = self.run_installer('--check', https_proxy=proxy)
            self.assertIn('proxy=' + (proxy or 'http://proxy.test:8080'), events)

    def test_piped_and_file_entrypoints(self):
        source = SCRIPT.read_text()
        direct = subprocess.run(['/bin/bash', str(SCRIPT), '--help'], capture_output=True, text=True)
        piped = subprocess.run(['/bin/bash', '-s', '--', '--help'], input=source, capture_output=True, text=True)
        self.assertEqual(direct.returncode, 0)
        self.assertEqual(piped.returncode, 0)
        self.assertIn('Usage:', direct.stdout)
        self.assertEqual(piped.stdout, direct.stdout)

if __name__ == '__main__':
    unittest.main(verbosity=2)

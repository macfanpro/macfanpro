#!/usr/bin/env python3
"""Publish verified public release copies for old MacFanPro update clients."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import urllib.request


def gh(*args):
    return subprocess.check_output(['gh', *args], text=True).strip()


def api(path):
    return json.loads(gh('api', path))


def download(url, path):
    if not url.startswith('https://github.com/'):
        raise ValueError('Unexpected asset host')
    with urllib.request.urlopen(url, timeout=120) as response:
        path.write_bytes(response.read())
    return 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest()


def sync_tags(source, target):
    # Preserve actual source commits for GitHub's automatically generated archives.
    def refs(repo):
        text = subprocess.check_output(['git', 'ls-remote', '--refs', 'https://github.com/' + repo + '.git', 'refs/tags/*'], text=True)
        return {ref: sha for sha, ref in (line.split() for line in text.splitlines())}
    wanted, existing = refs(source), refs(target)
    changed = {ref: sha for ref, sha in wanted.items() if existing.get(ref) != sha}
    if not changed:
        return
    with tempfile.TemporaryDirectory() as temp:
        bare = Path(temp) / 'source.git'
        subprocess.run(['git', 'clone', '--bare', 'https://github.com/' + source + '.git', str(bare)], check=True)
        askpass = Path(temp) / 'askpass.py'
        askpass.write_text("#!/usr/bin/env python3\nimport os,sys\nprint('x-access-token' if 'Username' in sys.argv[1] else os.environ['GH_TOKEN'])\n")
        askpass.chmod(0o700)
        env = {**os.environ, 'GIT_ASKPASS': str(askpass), 'GIT_TERMINAL_PROMPT': '0'}
        leases = [f'--force-with-lease={ref}:{existing.get(ref, "")}' for ref in sorted(changed)]
        subprocess.run(['git', '--git-dir=' + str(bare), '-c', 'credential.helper=', 'push', *leases,
                        'https://github.com/' + target + '.git', *[f'{ref}:{ref}' for ref in sorted(changed)]], check=True, env=env)
        actual = refs(target)
        if any(actual.get(ref) != sha for ref, sha in wanted.items()):
            raise ValueError('Legacy source tags differ from the main repository')
    print(f'Verified {len(wanted)} source tags', flush=True)


def sync(source, target):
    if source not in {'macfanpro/macfanpro', 'macfancontrol/macfancontrol'}:
        raise ValueError('Unexpected source')
    if target not in {'macfanpro/update-compat', 'macfanpro/macfanpro'} or source == target:
        raise ValueError('Unexpected target')
    sync_tags(source, target)
    releases = json.loads(gh('api', '--paginate', '--slurp', f'repos/{source}/releases?per_page=100'))
    releases = [r for page in releases for r in page if not r['draft'] and not r['prerelease']]
    latest = api(f'repos/{source}/releases/latest')['tag_name']
    existing = {r['tag_name']: r for page in json.loads(gh('api', '--paginate', '--slurp', f'repos/{target}/releases?per_page=100')) for r in page}
    for release in reversed(releases):
        tag = release['tag_name']
        if not re.fullmatch(r'v[0-9]+(?:\.[0-9]+){2,3}', tag):
            raise ValueError('Unexpected release tag')
        dest = existing.get(tag)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            # Keep source release links on the authoritative repository; old
            # clients obtain binaries from the identical assets copied below.
            notes = root / 'notes.md'
            notes.write_text('> MacFanControl 官方旧版升级入口。主仓库 / Main repository: '
                             'https://github.com/macfancontrol/macfancontrol\n\n' + (release['body'] or ''))
            if dest and not dest['draft'] and dest.get('body') == notes.read_text() and dest['name'] == (release['name'] or tag):
                current = {a['name']: a for a in dest['assets']}
                if all(a.get('digest') and current.get(a['name'], {}).get('digest') == a['digest']
                       and current[a['name']]['size'] == a['size'] for a in release['assets']):
                    print(f'Already verified {tag}', flush=True)
                    continue
            if dest is None:
                dest = json.loads(subprocess.check_output(['gh', 'api', '--method', 'POST', f'repos/{target}/releases', '--input', '-'],
                    input=json.dumps({'tag_name': tag, 'draft': True, 'name': release['name'] or tag, 'body': notes.read_text()}), text=True))
            assets = {a['name']: a for a in dest['assets']}
            for asset in release['assets']:
                name = asset['name']
                if Path(name).name != name or name in {'.', '..', 'notes.md'}:
                    raise ValueError('Unsafe asset name')
                old = assets.get(name)
                if old and asset.get('digest') and old.get('digest') == asset['digest'] and old['size'] == asset['size']:
                    continue
                path = root / name
                digest = download(asset['browser_download_url'], path)
                if asset.get('digest') and digest != asset['digest']:
                    raise ValueError('Source checksum mismatch: ' + name)
                gh('release', 'upload', tag, str(path), '-R', target, '--clobber')
                # A download from the destination verifies the actual published bytes.
                # Draft attachments require authenticated download through gh.
                verify = root / 'verified'
                verify.mkdir(exist_ok=True)
                gh('release', 'download', tag, '-R', target, '-p', name, '-D', str(verify), '--clobber')
                if 'sha256:' + hashlib.sha256((verify / name).read_bytes()).hexdigest() != digest:
                    raise ValueError('Destination checksum mismatch: ' + name)
            gh('release', 'edit', tag, '-R', target, '--draft=false', '--latest=' + str(tag == latest).lower(),
               '--title', release['name'] or tag, '--notes-file', str(notes))
            print(f'Verified {tag}: {len(release["assets"])} assets', flush=True)
    gh('release', 'edit', latest, '-R', target, '--latest')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', default='macfancontrol/macfancontrol')
    parser.add_argument('--target', default=os.environ.get('GITHUB_REPOSITORY'))
    args = parser.parse_args()
    sync(args.source, args.target)

#!/usr/bin/env python3
"""Mirror public GitHub refs and releases to the project's Gitee repository."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

REPOSITORY = "macfanpro/macfanpro"
GITEE_API = "/repos/" + REPOSITORY
GITEE_GIT = "https://gitee.com/" + REPOSITORY + ".git"


class MirrorError(Exception):
    pass


class APIError(MirrorError):
    def __init__(self, status, message):
        self.status = status
        super().__init__(f"Gitee HTTP {status}: {message}")


class Gitee:
    def __init__(self, token):
        self.token = token

    def call(self, method, endpoint, values=None, upload=None):
        fields = {**(values or {}), "access_token": self.token}
        url = "https://gitee.com/api/v5" + endpoint
        headers = {"Accept": "application/json"}
        if method == "GET":
            url += "?" + urllib.parse.urlencode(fields)
            data = None
        elif upload:
            safe_name(upload.name)
            boundary = "macfancontrol-" + uuid.uuid4().hex
            data = b"".join(
                f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
                for key, value in fields.items())
            data += (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
                     f'filename="{upload.name}"\r\nContent-Type: application/octet-stream\r\n\r\n').encode()
            data += upload.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
            headers["Content-Type"] = "multipart/form-data; boundary=" + boundary
        else:
            data = json.dumps(fields).encode()
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        # Retry reads only. A failed POST may already have created a release/file;
        # the next run inspects it instead of blindly creating a duplicate.
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=180 if upload else 40) as response:
                    body = response.read()
                    return json.loads(body) if body else None
            except urllib.error.HTTPError as error:
                if method == "GET" and error.code in {429, 502, 503, 504} and attempt < 2:
                    time.sleep(2 ** (attempt + 1))
                    continue
                try:
                    detail = json.load(error)
                    message = str(detail.get("message", detail.get("error", "request rejected")))
                except Exception:
                    message = "request rejected"
                raise APIError(error.code, message.replace(self.token, "[redacted]")) from None
            except Exception as error:
                raise MirrorError("Gitee request failed: " + type(error).__name__) from None

    def pages(self, endpoint):
        result = []
        page = 1
        while True:
            items = self.call("GET", endpoint, {"page": page, "per_page": 100})
            result.extend(items)
            if len(items) < 100:
                return result
            page += 1


def command(*args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def safe_name(name):
    if not name or name in {".", ".."} or any(c in name for c in '/\\\r\n"'):
        raise MirrorError("Unsafe attachment filename")


def refs(text):
    return {ref: sha for sha, ref in (line.split() for line in text.splitlines())}


def mirror_refs(api, directory):
    login = api.call("GET", "/user")["login"]
    bare = directory / "repository.git"
    subprocess.run(["git", "clone", "--bare", "https://github.com/" + REPOSITORY + ".git", str(bare)], check=True)
    askpass = directory / "askpass.py"
    askpass.write_text("#!/usr/bin/env python3\nimport os,sys\n"
                       "print(os.environ['GITEE_LOGIN'] if 'Username' in sys.argv[1] else os.environ['GITEE_TOKEN'])\n")
    askpass.chmod(0o700)
    env = {**os.environ, "GIT_ASKPASS": str(askpass), "GIT_TERMINAL_PROMPT": "0",
           "GITEE_LOGIN": login, "GITEE_TOKEN": api.token}
    git = ["git", "--git-dir=" + str(bare), "-c", "credential.helper="]
    source = refs(command(*git, "for-each-ref", "--format=%(objectname) %(refname)", "refs/heads", "refs/tags"))
    target = refs(command(*git, "ls-remote", "--refs", GITEE_GIT, "refs/heads/*", "refs/tags/*", env=env))
    # Gitee is the mirror: propagate changed/deleted refs, but refuse concurrent
    # destination changes between this snapshot and the atomic push.
    leases = [f"--force-with-lease={ref}:{target.get(ref, '')}" for ref in sorted(source.keys() | target.keys())]
    subprocess.run([*git, "push", "--atomic", "--prune", *leases, GITEE_GIT,
                    "refs/heads/*:refs/heads/*", "refs/tags/*:refs/tags/*"], check=True, env=env)
    actual = refs(command(*git, "ls-remote", "--refs", GITEE_GIT, "refs/heads/*", "refs/tags/*", env=env))
    if source != actual:
        raise MirrorError("Gitee branch/tag refs differ from the GitHub snapshot")
    print(f"Verified {len(source)} branch/tag refs", flush=True)
    return bare


def download(url, destination, host):
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != host:
        raise MirrorError("Unexpected attachment download host")
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=90) as response, destination.open("wb") as output:
                while chunk := response.read(1024 * 1024):
                    output.write(chunk)
            return hashlib.sha256(destination.read_bytes()).hexdigest()
        except Exception as error:
            if attempt == 2:
                raise MirrorError("Attachment download failed: " + type(error).__name__) from None
            time.sleep(2 ** (attempt + 1))


def rewrite_downloads(body, source_assets, target_assets):
    links = {asset["name"]: asset["browser_download_url"] for asset in target_assets}
    # .dmg is a prefix of .dmg.sha256; replace longer URLs first.
    for asset in sorted(source_assets, key=lambda a: len(a["browser_download_url"]), reverse=True):
        body = body.replace(asset["browser_download_url"], links[asset["name"]])
    return body


def get_target_release(api, tag):
    try:
        # Gitee returns HTTP 200/null for an existing tag without a Release.
        return api.call("GET", GITEE_API + "/releases/tags/" + urllib.parse.quote(tag, safe=""))
    except APIError as error:
        if error.status != 404:
            raise
        return None


def mirror_release(api, source, bare, directory):
    tag = source["tag_name"]
    sha = command("git", "--git-dir=" + str(bare), "rev-parse", "--verify", "refs/tags/" + tag + "^{commit}")
    target = get_target_release(api, tag)
    values = {key: source[key] for key in ["tag_name", "name", "body", "prerelease"]}
    values["name"] = values["name"] or tag
    values["body"] = values["body"] or ""
    if not target:
        target = api.call("POST", GITEE_API + "/releases", {**values, "target_commitish": sha})
    endpoint = f"{GITEE_API}/releases/{target['id']}"
    existing = api.pages(endpoint + "/attach_files")
    mirrored = []
    for asset in source["assets"]:
        name = asset["name"]
        safe_name(name)
        source_file = directory / name
        digest = download(asset["browser_download_url"], source_file, "github.com")
        if source_file.stat().st_size != asset["size"] or (asset.get("digest") and asset["digest"] != "sha256:" + digest):
            raise MirrorError("GitHub attachment size/digest mismatch: " + name)
        matches = [item for item in existing if item["name"] == name]
        if len(matches) > 1:
            raise MirrorError("Duplicate Gitee attachment: " + name)
        uploaded = matches[0] if matches else api.call("POST", endpoint + "/attach_files", upload=source_file)
        actual = download(uploaded["browser_download_url"], directory / "gitee-download", "gitee.com")
        if actual != digest:
            # Published assets are immutable. Surface a mismatch for investigation
            # instead of destroying a possibly useful existing package.
            raise MirrorError("Gitee attachment digest mismatch: " + name)
        mirrored.append(uploaded)
    wanted = {asset["name"] for asset in source["assets"]}
    for old in existing:
        if old["name"] not in wanted:
            api.call("DELETE", endpoint + "/attach_files/" + str(old["id"]))
    values["body"] = rewrite_downloads(values["body"], source["assets"], mirrored)
    if any(target[key] != value for key, value in values.items()):
        api.call("PATCH", endpoint, values)
    check = api.call("GET", endpoint)
    if any(check[key] != value for key, value in values.items()):
        raise MirrorError("Release metadata differs after synchronization: " + tag)
    attachments = api.pages(endpoint + "/attach_files")
    if sorted((a["name"], a["size"]) for a in attachments) != sorted((a["name"], a["size"]) for a in source["assets"]):
        raise MirrorError("Attachment list differs after synchronization: " + tag)
    print(f"Verified {tag}: {len(mirrored)} attachments", flush=True)


def remove_release(api, tag):
    target = get_target_release(api, tag)
    if target:
        api.call("DELETE", f"{GITEE_API}/releases/{target['id']}")
        print("Removed unpublished GitHub release from mirror: " + tag, flush=True)


def github_releases():
    pages = json.loads(command("gh", "api", "--paginate", "--slurp", "repos/" + REPOSITORY + "/releases"))
    return [release for page in pages for release in page if not release["draft"]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event", type=Path, help="GitHub Actions event JSON")
    parser.add_argument("--event-name", choices=["push", "delete", "release", "workflow_dispatch"], default="workflow_dispatch")
    parser.add_argument("--tag", default="", help="Manually retry one published release; omit to sync all")
    args = parser.parse_args()
    if args.tag and args.event_name != "workflow_dispatch":
        raise MirrorError("--tag is only supported for manual synchronization")
    token = os.environ.get("GITEE_TOKEN")
    if not token:
        raise MirrorError("Set the GITEE_TOKEN repository secret (Gitee projects permission)")
    api = Gitee(token)
    with tempfile.TemporaryDirectory(prefix="macfancontrol-gitee-") as folder:
        directory = Path(folder)
        bare = mirror_refs(api, directory)
        if args.event_name in {"push", "delete"}:
            return
        releases = github_releases()
        if args.tag:
            releases = [r for r in releases if r["tag_name"] == args.tag]
            if not releases:
                raise MirrorError("No published GitHub release found for tag: " + args.tag)
        if args.event_name == "release":
            if not args.event:
                raise MirrorError("Release events require --event")
            tag = json.loads(args.event.read_text())["release"]["tag_name"]
            selected = [r for r in releases if r["tag_name"] == tag]
            if not selected:
                remove_release(api, tag)
            releases = selected
        elif not args.tag:
            wanted = {r["tag_name"] for r in releases}
            for stale in api.pages(GITEE_API + "/releases"):
                if stale["tag_name"] not in wanted:
                    remove_release(api, stale["tag_name"])
        for release in sorted(releases, key=lambda r: r["published_at"]):
            with tempfile.TemporaryDirectory(prefix="release-", dir=directory) as assets:
                mirror_release(api, release, bare, Path(assets))


if __name__ == "__main__":
    try:
        main()
    except (MirrorError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None

# Security policy

MacFanPro installs a background service that runs as root and talks to the Mac's SMC, so security reports are taken seriously.

## Reporting a vulnerability

Please **do not open a public issue**. Report it privately through GitHub: go to the repository's **Security** tab and choose **Report a vulnerability** ([direct link](https://github.com/macfanpro/macfanpro/security/advisories/new)).

Include the MacFanPro version, your macOS version, the steps to reproduce, and what an attacker could achieve. You'll get an acknowledgement within a few days. Once a fix is released, the release notes credit the reporter unless you prefer otherwise.

## Supported versions

Only the latest release receives security fixes. Update with the steps in the [README](README.md#updating).

## Scope

In scope: privilege escalation through the background service or `sudo macfanpro` commands, the service's local socket, file handling under sudo, and anything that could leave the fans unsafe without the user's knowledge.

Out of scope: problems that require an attacker who already has root, and the fact that release packages are ad-hoc signed rather than notarized (this is documented).

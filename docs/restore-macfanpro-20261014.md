# Restore MacFanPro 0.2.3.63

The maintainer cancelled the MacFanControl rename and requested restoration of 0.2.3.63.

- Application sources, tests, resources, installer and package layout match tag v0.2.3.63. No new application release is being published.
- Original GitHub repository ID 1378207908 is restored to macfanpro/macfanpro, preserving history and stars. macfancontrol/macfancontrol is an informational link to it.
- Homebrew is restored to macfanpro/homebrew-tap and the existing 0.2.3.63 bottle.
- Gitee repository ID 50759731 is restored to macfanpro/macfanpro, as a mirror only. Mirror automation and current main-branch contributor instructions are retained.
- The unpublished 0.2.3.65 draft and authoritative tag were removed. 0.2.3.63 is latest stable; 0.2.3.64 is marked prerelease to stop stable update prompts, preserving historical artifacts.

## Verification

- Debug and Release: 168 tests each, simulated SMC.
- Installer: 17 tests; disconnected-client checks passed.
- Mirror: 7 temporary-fixture tests passed.
- Release localization/installer packaging passed for version 0.2.3.63; website generated 18 languages.
- No local application installation, service restart or fan-control operation was performed.

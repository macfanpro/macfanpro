---
name: Compatibility Report
about: Report whether MacFanControl works on your Mac
title: "[Compat] Mac __ M__"
labels: compatibility
---

**Machine / model identifier:** (e.g. MacBook Pro, Mac16,5)
**Chip:** (exact chip, including Pro, Max or Ultra when applicable)
**Year:**
**macOS version:**
**macfancontrol version:**
**Installation method:** (Homebrew, online installer, release package, source)

## Results

Run `macfancontrol discover --output discover.txt` and attach the file. Mark only actions you actually tested. The fan-control commands below change fan state; record your current profile or CLI hold first and restore it afterwards. Read-only discovery alone does not require these tests.

- [ ] `macfancontrol status` works (reads fans + temps)
- [ ] `macfancontrol max` works through the installed daemon (fans spin up)
- [ ] `macfancontrol auto` works (returns control to macOS)
- [ ] `sudo macfancontrol install` works (daemon starts)
- [ ] Menu bar app shows temps

## Discover output

<!-- Attach your discover.txt file or paste key excerpts -->

## Notes

<!-- Any issues, different key names, unexpected behavior -->

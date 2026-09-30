#!/bin/bash
# Published copies are pinned to their release by package-release.sh.
# Run as the logged-in user; only the existing CLI's install command uses sudo.
set -Eeuo pipefail

fail() { printf 'MacFanPro: %s\n' "$*" >&2; exit 1; }
valid_version() { [[ "$1" =~ ^[0-9]+(\.[0-9]+){2,3}$ ]]; }
version_gt() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        split(a,x,"."); split(b,y,".");
        for(i=1;i<=4;i++) { if(x[i]+0>y[i]+0) exit 0; if(x[i]+0<y[i]+0) exit 1 }
        exit 1
    }'
}
plist_value() { /usr/libexec/PlistBuddy -c "Print $2" "$1/Contents/Info.plist"; }
installed_versions() {
    if [ -e /usr/local/bin/macfanpro ]; then /usr/local/bin/macfanpro --version || return; fi
    if [ -d /Applications/MacFanPro.app ]; then
        plist_value /Applications/MacFanPro.app CFBundleShortVersionString || return
    fi
}
check_downgrade() {
    local installed versions
    versions=$(installed_versions) || fail 'Cannot read the installed version.'
    for installed in $versions; do
        valid_version "$installed" || fail "Unrecognized installed version: $installed"
        if version_gt "$installed" "$1"; then fail "Refusing to downgrade $installed to $1."; fi
    done
}
find_brew() {
    local brew
    for brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        # A broken/untrusted brew command must not silently change ownership to
        # a standalone install when its managed keg is still present.
        if [ -d "${brew%/bin/brew}/opt/macfanpro" ]; then
            [ -x "$brew" ] || fail "Homebrew-managed MacFanPro exists but $brew is unavailable. Repair Homebrew first."
            printf '%s\n' "$brew"; return
        fi
        if [ -x "$brew" ] && "$brew" list --versions macfanpro >/dev/null 2>&1; then
            printf '%s\n' "$brew"; return
        fi
    done
}
setup_proxy() {
    if [ -z "${https_proxy:-}${HTTPS_PROXY:-}${all_proxy:-}${ALL_PROXY:-}" ]; then
        local proxy
        proxy=$(scutil --proxy | awk '
            /HTTPSEnable : 1/ {https=1}
            /HTTPSProxy :/ {https_host=$3}
            /HTTPSPort :/ {https_port=$3}
            /SOCKSEnable : 1/ {socks=1}
            /SOCKSProxy :/ {socks_host=$3}
            /SOCKSPort :/ {socks_port=$3}
            END {
                if (https && https_host && https_port)
                    print "http://" https_host ":" https_port
                else if (socks && socks_host && socks_port)
                    print "socks5h://" socks_host ":" socks_port
            }
        ')
        if [ -n "$proxy" ]; then
            if [[ "$proxy" == socks5h://* ]]; then export all_proxy="$proxy"
            else export https_proxy="$proxy"; fi
        fi
    fi
}
download() {
    curl --fail --location --show-error --silent --proto '=https' --proto-redir '=https' \
        --connect-timeout 20 --max-time 600 --retry 2 --output "$2" "$1"
}
verify_archive() {
    local archive="$1" name="$2" digest count
    # Select exactly this archive, not every entry in a potentially larger manifest.
    count=$(awk -v n="$name.tar.gz" '$2==n {c++} END {print c+0}' "$WORK/SHA256SUMS")
    [ "$count" = 1 ] || fail 'Missing or duplicate archive checksum.'
    digest=$(awk -v n="$name.tar.gz" '$2==n {print $1}' "$WORK/SHA256SUMS")
    [[ "$digest" =~ ^[a-fA-F0-9]{64}$ ]] || fail 'Invalid SHA256 checksum.'
    printf '%s  %s\n' "$digest" "$name.tar.gz" > "$WORK/archive.sha256"
    (cd "$WORK" && shasum -a 256 -c archive.sha256)
    # Reject links, devices and unexpected paths before extraction. Release archives
    # contain only regular files and directories under one versioned directory.
    tar -tzf "$archive" > "$WORK/members"
    awk -v root="$name" '
        /^\// || /\\/ || /(^|\/)\.\.?($|\/)/ {exit 1}
        $0!=root && index($0,root "/")!=1 {exit 1}
        END {if(NR==0) exit 1}
    ' "$WORK/members" || fail 'Unsafe archive paths.'
    tar -tvzf "$archive" > "$WORK/types"
    awk 'substr($0,1,1)!="-" && substr($0,1,1)!="d" {exit 1}' "$WORK/types" \
        || fail 'Archive contains links or special files.'
    tar -xzf "$archive" -C "$WORK"
}
verify_package() {
    local root="$1" version="$2" app="$1/MacFanPro.app"
    [ -x "$root/bin/macfanpro" ] || fail 'The package has no executable CLI.'
    [ "$(plist_value "$app" CFBundleIdentifier)" = io.github.macfanpro.app ] || fail 'Unexpected app identity.'
    [ "$(plist_value "$app" CFBundleShortVersionString)" = "$version" ] || fail 'App version mismatch.'
    [ "$(plist_value "$app" CFBundleVersion)" = "$version" ] || fail 'App build version mismatch.'
    codesign --verify --deep --strict "$app"
    [ "$("$root/bin/macfanpro" --version)" = "$version" ] || fail 'CLI version mismatch.'
}
verify_installation() {
    local version="$1"
    [ "$(/usr/local/bin/macfanpro --version)" = "$version" ] || fail 'Installed CLI version mismatch.'
    [ "$(plist_value /Applications/MacFanPro.app CFBundleShortVersionString)" = "$version" ] || fail 'Installed app version mismatch.'
    codesign --verify --deep --strict /Applications/MacFanPro.app
    launchctl print system/io.github.macfanpro.daemon | grep 'state = running' >/dev/null \
        || fail 'The installed daemon is not running.'
    [ -S /var/run/macfanpro.sock ] || fail 'The daemon socket is missing.'
}
finish_install() {
    local cli="$1" version="$2"
    # Obtain credentials before stopping the app; never pipe a password to sudo.
    sudo -v
    "$cli" auto --stop-app
    if [ "$MIGRATE" = 1 ]; then sudo "$cli" install --migrate-thermalforge
    else sudo "$cli" install; fi
    verify_installation "$version"
    if [ "$NO_OPEN" = 0 ]; then open /Applications/MacFanPro.app; fi
    printf 'MacFanPro %s installed and the background service is running.\n' "$version"
}
main() {
    local version='@MACFANPRO_VERSION@' brew='' check=0 require_brew=0 name base root
    NO_OPEN=0 MIGRATE=0 WORK=''
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --version) [ "$#" -ge 2 ] || fail '--version needs a version number.'; version="$2"; shift ;;
            --check) check=1 ;;
            --no-open) NO_OPEN=1 ;;
            --homebrew) require_brew=1 ;;
            --migrate-thermalforge) MIGRATE=1 ;;
            -h|--help)
                printf '%s\n' 'Usage: bash install.sh [--version X.Y.Z.N] [--check] [--no-open] [--homebrew] [--migrate-thermalforge]' \
                    '--check downloads and validates the release without changing the installation.' \
                    'Homebrew installations stay managed by Homebrew; --version is a minimum on that path.'
                return ;;
            *) fail "Unknown option: $1" ;;
        esac
        shift
    done
    valid_version "$version" || fail 'This source template needs --version X.Y.Z.N; published installers have a pinned version.'
    [ "$(uname -s)" = Darwin ] || fail 'Requires macOS.'
    [ "$(uname -m)" = arm64 ] || fail 'Requires an Apple Silicon shell (arm64); disable Rosetta for Terminal.'
    [ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || fail 'Requires macOS 14 or later.'
    [ "$(id -u)" != 0 ] || fail 'Run as your normal login user, without sudo.'
    umask 077
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/macfanpro-install.XXXXXX")
    trap 'rm -rf "$WORK"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'printf "MacFanPro installation did not finish. See the error above.\n" >&2' ERR
    setup_proxy
    brew=$(find_brew)
    if [ "$require_brew" = 1 ] && [ -z "$brew" ]; then fail 'No Homebrew-managed MacFanPro installation found.'; fi
    if [ -n "$brew" ] && [ "$check" = 0 ]; then
        printf 'Updating the Homebrew-managed installation…\n'
        # Homebrew 7 refuses an untrusted tap; trusting is a no-op when already
        # trusted and unknown to older Homebrew.
        "$brew" trust macfanpro/tap >/dev/null 2>&1 || true
        # Refresh only this tap: brew update fetches every tap (slow, noisy when an
        # unrelated tap or mirror is broken) and HOMEBREW_NO_AUTO_UPDATE users skip
        # it. Fall back to it; the version check below still refuses a stale formula.
        if ! git -C "$("$brew" --repository macfanpro/tap)" pull --ff-only --quiet; then
            "$brew" update || printf 'brew update failed; continuing with the current tap.\n' >&2
        fi
        # Running this script is the confirmation; Homebrew 7 would otherwise wait
        # at a y/n prompt in Terminal. The tap is fresh, so skip auto-update too.
        # brew upgrade is a successful no-op for an already-current formula.
        HOMEBREW_NO_ASK=1 HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 "$brew" upgrade macfanpro
        root=$("$brew" --prefix macfanpro)
        local brew_version
        brew_version=$("$root/bin/macfanpro" --version)
        valid_version "$brew_version" || fail 'Invalid Homebrew version.'
        if version_gt "$version" "$brew_version"; then
            fail "Homebrew currently provides $brew_version; the requested $version is not available yet. Retry after the tap is updated."
        fi
        check_downgrade "$brew_version"
        verify_package "$root" "$brew_version"
        finish_install "$root/bin/macfanpro" "$brew_version"
        return
    fi
    if [ "$check" = 0 ]; then check_downgrade "$version"; fi
    name="MacFanPro-$version-macos-arm64"
    base="https://github.com/macfanpro/macfanpro/releases/download/v$version"
    printf 'Downloading MacFanPro %s…\n' "$version"
    download "$base/$name.tar.gz" "$WORK/$name.tar.gz"
    download "$base/SHA256SUMS" "$WORK/SHA256SUMS"
    verify_archive "$WORK/$name.tar.gz" "$name"
    root="$WORK/$name"
    verify_package "$root" "$version"
    if [ "$check" = 1 ]; then printf 'MacFanPro %s package verification passed; no installation performed.\n' "$version"; return; fi
    # Recheck after downloading in case another updater completed meanwhile.
    check_downgrade "$version"
    finish_install "$root/bin/macfanpro" "$version"
}

# Supports direct execution, curl | bash, and sourcing by the isolated test harness.
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi

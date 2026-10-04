# MacFanPro website

Public address: <https://macfanpro.github.io/macfanpro/>.

The site is hosted on GitHub Pages. A shared HTML template, local CSS/JavaScript and 18 translation files produce static pages; visitors need no JavaScript to read the content, use language links or view installation commands. There are no external fonts, UI frameworks, analytics or runtime translation requests.

## Build and preview

From the repository root:

```bash
python3 Scripts/build-website.py
python3 -m http.server 8765 --bind 127.0.0.1 --directory .build/website
```

Open <http://127.0.0.1:8765/>. The generated site lives in `.build/website/`; rebuild after editing. Existing Swift build products are preserved.

## Languages

`locales/` matches the app's 18 locale codes: `en`, `zh-Hans`, `zh-Hant`, `ja`, `ko`, `de`, `fr`, `es`, `it`, `pt-BR`, `ru`, `uk`, `pl`, `nl`, `tr`, `vi`, `id`, `ar`.

- Simplified Chinese is at `/macfanpro/`. Other languages use `/macfanpro/<locale>/`.
- The entry page detects the first supported browser language, defaulting to English for unsupported browser languages. A manual selection is stored locally and takes precedence. An explicit localized URL always keeps its own language.
- `/macfanpro/?lang=zh-Hans` explicitly selects Simplified Chinese, including when browser storage is unavailable.
- Arabic uses RTL layout, while shell commands remain LTR.
- All languages show direct installation first. Proxy installation is a fallback when GitHub cannot be reached; HTTP, SOCKS5 and Homebrew remain available.
- Each page has its own title, description, canonical URL, `hreflang` links and sitemap entry.
- Translations must have the same keys and array shapes as English. Missing/empty translations fail the build rather than silently falling back to English.

Edit `template.html` for structure, `assets/` for behavior/style, and all affected `locales/*.json` entries for copy. Product facts and commands must agree with the repository README and installer. Link to `releases/latest` rather than hardcoding a downloadable version.

The build copies the existing logo, real app screenshots and social previews from `docs/images/`. Screenshots are labeled with the version and interface language actually shown; the site does not pretend that the English screenshots are localized. Detailed repository documentation remains in English and Simplified Chinese.

## Publish

GitHub repository settings must use **Pages → Source → GitHub Actions**. `.github/workflows/pages.yml` builds on relevant pushes to `main` and can be run manually. Pull requests build only; deployment runs from `main`, with Pages/OIDC permissions limited to the deploy job. Only `.build/website/` is published, excluding translation sources and development notes. Publishing the website does not create an application release or install anything locally.

For a copy or layout change, build the site and check the affected languages in a browser. Check desktop and narrow mobile widths, longer German/Cyrillic text, Arabic RTL, manual/automatic language selection, installation tabs, proxy validation, clipboard success/failure, and basic navigation without JavaScript. Do not run the installation commands as part of a website check.

## 中文维护说明

- 网站和应用均支持 18 种语言；修改文案后同步各语言 JSON，构建会检查缺漏。
- 首页按浏览器语言选择页面，手动选择会在本机保存；明确访问某语言网址时不自动跳转。
- 所有语言默认展示直接安装，无法正常访问 GitHub 时再切换到代理方式；代理端口由访客自行填写，不提供代理服务。
- 只发布构建结果，网站更新与应用发行独立；不会修改本机风扇模式或安装应用。

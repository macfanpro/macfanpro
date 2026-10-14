#!/usr/bin/env python3
"""Build the 18-language GitHub Pages site using only Python's standard library."""
from html import escape
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
from string import Template
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'website'
OUTPUT = ROOT / '.build' / 'website'
BASE = 'https://macfanpro.github.io/macfanpro/'
REPO = 'https://github.com/macfanpro/macfanpro'
LANGUAGES = {
    'zh-Hans': '简体中文', 'en': 'English', 'zh-Hant': '繁體中文',
    'ja': '日本語', 'ko': '한국어', 'de': 'Deutsch', 'fr': 'Français',
    'es': 'Español', 'it': 'Italiano', 'pt-BR': 'Português (Brasil)',
    'ru': 'Русский', 'uk': 'Українська', 'pl': 'Polski', 'nl': 'Nederlands',
    'tr': 'Türkçe', 'vi': 'Tiếng Việt', 'id': 'Bahasa Indonesia', 'ar': 'العربية',
}
PROXY = '(\n  export https_proxy=http://127.0.0.1:7890\n  set -o pipefail\n  curl -fsSL https://github.com/macfanpro/macfanpro/releases/latest/download/install.sh | bash\n)'
DIRECT = '(\n  set -o pipefail\n  curl -fsSL https://github.com/macfanpro/macfanpro/releases/latest/download/install.sh | bash\n)'
BREW = 'brew tap macfanpro/tap &&\nbrew trust macfanpro/tap &&\nbrew install macfanpro &&\nsudo "$(brew --prefix macfanpro)/bin/macfanpro" install &&\nopen /Applications/MacFanPro.app'


def route(lang):
    return '' if lang == 'zh-Hans' else lang + '/'


def escaped(value):
    if isinstance(value, str):
        return escape(value, quote=True)
    return [escaped(item) for item in value]


def shape(value):
    if isinstance(value, str) and value.strip():
        return str
    if isinstance(value, list):
        return [shape(item) for item in value]
    raise ValueError('Translations must contain nonempty strings or arrays of strings')


class PageLinks(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids = set()
        self.references = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            if attrs['id'] in self.ids:
                raise ValueError(f'Duplicate HTML id: {attrs["id"]}')
            self.ids.add(attrs['id'])
        for key in ('href', 'src'):
            if key in attrs:
                self.references.append(attrs[key])


def validate_links():
    pages = {path.resolve(): PageLinks(path.read_text()) for path in OUTPUT.rglob('*.html')}
    for path, page in pages.items():
        for reference in page.references:
            url = urlsplit(reference)
            # Check repository documentation anchors without network access.
            if reference.startswith(REPO + '/blob/main/'):
                local = ROOT / unquote(url.path.split('/blob/main/', 1)[1])
                if not local.is_file():
                    raise ValueError(f'Missing repository document: {reference}')
                if url.fragment:
                    headings = re.findall(r'^#{1,6}\s+(.+)$', local.read_text(), re.M)
                    anchors = {re.sub(r'[^\w\- ]', '', h.lower()).replace(' ', '-') for h in headings}
                    if unquote(url.fragment) not in anchors:
                        raise ValueError(f'Missing documentation anchor: {reference}')
            elif not url.scheme and not url.netloc:
                target = (path.parent / unquote(url.path)).resolve() if url.path else path
                if target.is_dir():
                    target /= 'index.html'
                if not target.is_file() or not target.is_relative_to(OUTPUT.resolve()):
                    raise ValueError(f'{path}: invalid local link {reference}')
                if url.fragment and unquote(url.fragment) not in pages[target].ids:
                    raise ValueError(f'{path}: missing local anchor {reference}')


def build():
    app_languages = {p.stem for p in (ROOT / 'Sources/MacFanProLocalization/Resources').glob('*.json')}
    if set(LANGUAGES) != app_languages:
        raise ValueError('Website language list must match the app')
    translations = {lang: json.loads((SOURCE / 'locales' / f'{lang}.json').read_text()) for lang in LANGUAGES}
    reference = {key: shape(value) for key, value in translations['en'].items()}
    for lang, data in translations.items():
        if {key: shape(value) for key, value in data.items()} != reference:
            raise ValueError(f'{lang}: translation keys or array shapes differ from English')
    # Only the generated website directory is replaced; app build products are retained.
    if OUTPUT.is_symlink():
        raise ValueError('Refusing to replace a symlinked website output directory')
    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)
    (OUTPUT / 'assets').mkdir(parents=True)
    for name in ['site.css', 'site.js']:
        shutil.copy2(SOURCE / 'assets' / name, OUTPUT / 'assets' / name)
    for name in ['icon.png', 'menu-bar-en.png', 'menu-bar-zh-CN.png', 'social-preview.png', 'social-preview-zh-CN.png']:
        shutil.copy2(ROOT / 'docs' / 'images' / name, OUTPUT / 'assets' / name)
    template = Template((SOURCE / 'template.html').read_text())
    alternates = '\n  '.join(f'<link rel="alternate" hreflang="{lang}" href="{BASE}{route(lang)}">' for lang in LANGUAGES)
    alternates += f'\n  <link rel="alternate" hreflang="x-default" href="{BASE}">'
    for lang, raw in translations.items():
        d = {key: escaped(value) for key, value in raw.items()}
        chinese = lang.startswith('zh-')
        prefix = '../' if route(lang) else './'
        doc = REPO + '/blob/main/' + ('README.zh-CN.md' if chinese else 'README.md')
        methods = ['direct', 'proxy', 'brew']
        panels = []
        for method in methods:
            fields = ''
            if method == 'proxy':
                fields = f'<div class="proxy-fields"><label>{d["type"]}<select id="proxy-protocol" disabled><option value="http">HTTP</option><option value="socks5h">SOCKS5</option></select></label><label>{d["port"]}<input id="proxy-port" type="number" min="1" max="65535" step="1" value="7890" inputmode="numeric" aria-describedby="proxy-error" disabled></label></div><p id="proxy-error" class="form-error" role="alert"></p>'
            command = escape({'proxy': PROXY, 'direct': DIRECT, 'brew': BREW}[method])
            panels.append(f'<section class="install-panel" id="panel-{method}" aria-labelledby="heading-{method}"><h3 id="heading-{method}">{d[method]}</h3><p class="method-note">{d[method + "_note"]}</p>{fields}<div class="terminal"><div class="terminal-bar"><span><i></i><i></i><i></i> Terminal</span><button type="button" class="copy-button" data-copy="command-{method}" hidden>{d["copy"]}</button></div><pre tabindex="0" aria-label="{d[method]}"><code id="command-{method}">{command}</code></pre></div></section>')
        language_items = ''.join(f'<li><a href="{prefix}{route(code) or "?lang=zh-Hans"}" lang="{code}" hreflang="{code}" dir="auto" data-language="{code}"' + (' aria-current="page"' if code == lang else '') + f'>{name}</a></li>' for code,name in LANGUAGES.items())
        schema = {'@context': 'https://schema.org', '@type': 'SoftwareApplication', 'name': 'MacFanPro', 'applicationCategory': 'UtilitiesApplication', 'operatingSystem': 'macOS 14+ (Apple Silicon with physical fans)', 'inLanguage': lang, 'url': BASE + route(lang), 'downloadUrl': REPO + '/releases/latest', 'license': REPO + '/blob/main/LICENSE', 'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'USD'}}
        d.update(
            lang=lang, direction='rtl' if lang == 'ar' else 'ltr', prefix=prefix,
            root_page=str(lang == 'zh-Hans').lower(), url=BASE + route(lang), base=BASE, repo=REPO,
            og_locale={'zh-Hans':'zh_CN','zh-Hant':'zh_TW','en':'en_US','pt-BR':'pt_BR',
                       'ja':'ja_JP','ko':'ko_KR','de':'de_DE','fr':'fr_FR','es':'es_ES','it':'it_IT',
                       'ru':'ru_RU','uk':'uk_UA','pl':'pl_PL','nl':'nl_NL','tr':'tr_TR',
                       'vi':'vi_VN','id':'id_ID','ar':'ar_SA'}[lang],
            image='menu-bar-zh-CN.png' if chinese else 'menu-bar-en.png',
            social='social-preview-zh-CN.png' if chinese else 'social-preview.png',
            alternates=alternates, schema=json.dumps(schema,ensure_ascii=False),
            nav_features=d['nav'][0], nav_install=d['nav'][1], nav_faq=d['nav'][2],
            headline_first=d['headline'][0], headline_second=d['headline'][1],
            language_menu=f'<details class="language-menu"><summary aria-label="{d["languages"]}"><span aria-hidden="true">◎</span> {LANGUAGES[lang]}</summary><ul>{language_items}</ul></details>',
            facts_html=''.join(f'<div><strong>{a}</strong><span>{b}</span></div>' for a,b in d['facts']),
            features_html=''.join(f'<article class="feature"><span class="eyebrow">{a}</span><div class="feature-glyph glyph-{i}" aria-hidden="true">{["◉","⌁","&gt;_"][i]}</div><h3>{b}</h3><p>{c}</p><code>{e}</code></article>' for i,(a,b,c,e) in enumerate(d['features'])),
            safety_url=doc + ('#安全机制与权限' if chinese else '#safety-and-permissions'),
            install_url=doc + ('#安装' if chinese else '#install'),
            source_url=doc + ('#方式三从源码构建安装' if chinese else '#option-3-from-source'),
            tabs_html=''.join(f'<button type="button" id="tab-{m}" role="tab" aria-controls="panel-{m}" aria-selected="{str(i==0).lower()}" tabindex="{0 if i==0 else -1}" data-method="{m}">{d[m]}</button>' for i,m in enumerate(methods)),
            panels_html='\n'.join(panels),
            steps_html=''.join(f'<li><span class="step-number">0{i+1}</span><h3>{a}</h3><p>{b}</p></li>' for i,(a,b) in enumerate(d['steps'])),
            faq_html=''.join(f'<details><summary>{a}<span aria-hidden="true">+</span></summary><p>{b}</p></details>' for a,b in d['faq']),
            doc=doc,
        )
        destination = OUTPUT / route(lang) / 'index.html'
        destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_text(template.substitute(d))
    (OUTPUT / '.nojekyll').touch()
    (OUTPUT / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + ''.join(f'  <url><loc>{BASE}{route(lang)}</loc></url>\n' for lang in LANGUAGES) + '</urlset>\n')
    validate_links()
    print(f'Built {len(translations)} complete language pages: {OUTPUT}')


if __name__ == '__main__':
    build()

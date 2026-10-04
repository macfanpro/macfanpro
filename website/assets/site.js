(() => {
  'use strict';
  const html = document.documentElement;
  const languageLinks = [...document.querySelectorAll('[data-language]')];
  const supported = languageLinks.map(link => link.dataset.language);
  const storageKey = 'macfanpro.website.language';
  function remember(language) { try { localStorage.setItem(storageKey, language); } catch {} }
  function matchLanguage(language) {
    const lower = language.toLowerCase();
    const exact = supported.find(code => code.toLowerCase() === lower);
    if (exact) return exact;
    if (lower.startsWith('zh')) return /hant|tw|hk|mo/.test(lower) ? 'zh-Hant' : 'zh-Hans';
    if (lower.startsWith('pt')) return 'pt-BR';
    return supported.find(code => code === lower.split('-')[0]);
  }
  languageLinks.forEach(link => link.addEventListener('click', () => remember(link.dataset.language)));
  // An explicit language URL always wins. Only the entry page detects language.
  const requested = new URLSearchParams(location.search).get('lang');
  if (supported.includes(requested)) remember(requested);
  if (html.dataset.rootPage === 'true' && !supported.includes(requested)) {
    let preferred;
    try { preferred = localStorage.getItem(storageKey); } catch {}
    if (!supported.includes(preferred)) preferred = (navigator.languages || [navigator.language]).map(matchLanguage).find(Boolean) || 'en';
    if (preferred && preferred !== html.lang) {
      const target = languageLinks.find(link => link.dataset.language === preferred);
      const url = new URL(target.href);
      url.hash = location.hash;
      location.replace(url.href);
      return;
    }
  }
  document.addEventListener('click', event => {
    const menu = document.querySelector('.language-menu');
    if (menu && !menu.contains(event.target)) menu.open = false;
  });
  document.addEventListener('keydown', event => {
    const menu = document.querySelector('.language-menu');
    if (event.key === 'Escape' && menu?.open) { menu.open = false; menu.querySelector('summary').focus(); }
  });

  // Older releases have no DMG. Never advertise a nonexistent asset or replace
  // the working proxy installer when GitHub's API is unavailable.
  const dmg = document.querySelector('.dmg-install');
  if (dmg) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    fetch('https://api.github.com/repos/macfanpro/macfanpro/releases/latest', { signal: controller.signal })
      .then(response => { if (!response.ok) throw new Error('Release unavailable'); return response.json(); })
      .then(release => {
        if (release.draft || release.prerelease || !/^v[0-9]+(?:\.[0-9]+){2,3}$/.test(release.tag_name)) return;
        const name = `MacFanPro-${release.tag_name.slice(1)}-macos-arm64.dmg`;
        const url = `https://github.com/macfanpro/macfanpro/releases/download/${release.tag_name}/${name}`;
        if (!Array.isArray(release.assets) || !release.assets.some(asset => asset.name === name && asset.browser_download_url === url)) return;
        dmg.querySelector('[data-dmg-download]').href = url;
        dmg.hidden = false;
      }).catch(() => {}).finally(() => clearTimeout(timeout));
  }

  const installer = document.querySelector('.installer');
  const tabs = [...installer.querySelectorAll('[role=tab]')];
  const status = installer.querySelector('.copy-status');
  function activate(tab, focus = false) {
    tabs.forEach(item => {
      const active = item === tab;
      item.setAttribute('aria-selected', String(active));
      item.tabIndex = active ? 0 : -1;
      const panel = document.getElementById(item.getAttribute('aria-controls'));
      panel.hidden = !active;
      panel.setAttribute('role', 'tabpanel');
      panel.setAttribute('aria-labelledby', item.id);
    });
    status.textContent = '';
    if (focus) tab.focus();
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => activate(tab));
    tab.addEventListener('keydown', event => {
      let next;
      const forward = html.dir === 'rtl' ? 'ArrowLeft' : 'ArrowRight';
      const backward = html.dir === 'rtl' ? 'ArrowRight' : 'ArrowLeft';
      if (event.key === forward) next = (index + 1) % tabs.length;
      if (event.key === backward) next = (index - 1 + tabs.length) % tabs.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = tabs.length - 1;
      if (next !== undefined) { event.preventDefault(); activate(tabs[next], true); }
    });
  });
  installer.classList.add('enhanced');
  installer.querySelector('[role=tablist]').hidden = false;
  activate(tabs[0]);

  const port = document.getElementById('proxy-port');
  const protocol = document.getElementById('proxy-protocol');
  port.disabled = protocol.disabled = false;
  const proxyButton = document.querySelector('[data-copy=command-proxy]');
  function updateProxy() {
    const valid = /^\d{1,5}$/.test(port.value) && Number(port.value) >= 1 && Number(port.value) <= 65535;
    port.setAttribute('aria-invalid', String(!valid));
    document.getElementById('proxy-error').textContent = valid ? '' : document.body.dataset.portError;
    proxyButton.disabled = !valid;
    status.textContent = '';
    if (!valid) return;
    const socks = protocol.value === 'socks5h';
    document.getElementById('command-proxy').textContent = `(\n  export ${socks ? 'all_proxy' : 'https_proxy'}=${socks ? 'socks5h' : 'http'}://127.0.0.1:${Number(port.value)}\n  set -o pipefail\n  curl -fsSL https://github.com/macfanpro/macfanpro/releases/latest/download/install.sh | bash\n)`;
  }
  port.addEventListener('input', updateProxy);
  protocol.addEventListener('change', updateProxy);
  document.querySelectorAll('[data-copy]').forEach(button => {
    button.hidden = false;
    button.addEventListener('click', async () => {
      const code = document.getElementById(button.dataset.copy);
      try {
        await navigator.clipboard.writeText(code.textContent);
        status.textContent = document.body.dataset.copied;
      } catch {
        const range = document.createRange();
        range.selectNodeContents(code);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
        status.textContent = document.body.dataset.copyError;
      }
    });
  });
})();

#!/usr/bin/env python3
"""Build every theme with both engines and compare publishing contracts.

Requires Python 3, Bash, PowerShell 7 and Pandoc. --browser additionally uses
Playwright + Chromium to check narrow layouts, keyboard access and code styles.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from html.parser import HTMLParser

ROOT = Path(__file__).resolve().parents[1]

class Contract(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.css, self.headings, self.code, self.nav = [], [], [], []
        self.skip = self.main = self.lang = False
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'html': self.lang = bool(a.get('lang'))
        if tag == 'main': self.main = a.get('id') == 'content'
        if tag == 'a' and a.get('href') == '#content': self.skip = True
        if tag == 'link' and a.get('rel') == 'stylesheet': self.css.append(a['href'])
        if tag in ('h1', 'h2', 'h3'): self.headings.append((tag, a.get('id')))
        if tag == 'code': self.code.append(a.get('class', ''))
        if tag == 'a' and a.get('aria-current') == 'page': self.nav.append(a.get('href'))


def check_palette(theme):
    """Check declared solid text surfaces; this is not a computed CSS audit."""
    css = (ROOT/'templates'/theme/'styles/00-theme-contract.css').read_text()
    colors = dict(re.findall(r'(--[\w-]+):\s*(#[a-fA-F0-9]{3,6})[;}]', css))
    def luminance(value):
        value = value.lstrip('#')
        if len(value) == 3: value = ''.join(c * 2 for c in value)
        rgb = [int(value[i:i+2], 16) / 255 for i in (0, 2, 4)]
        return sum(w * (v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4)
                   for w, v in zip((.2126, .7152, .0722), rgb))
    pairs = [(fg, bg) for fg in ('page-fg', 'page-muted', 'page-link')
             for bg in ('page-bg', 'page-panel')]
    pairs += [('zeta-nav-ink', 'zeta-nav-background'), ('zeta-nav-current', 'zeta-nav-background')]
    for fg, bg in pairs:
        if '--' + fg not in colors or '--' + bg not in colors:
            continue  # CSS variables/gradients require browser-level inspection.
        low, high = sorted((luminance(colors['--' + fg]), luminance(colors['--' + bg])))
        ratio = (high + .05) / (low + .05)
        assert ratio >= 4.5, (theme, fg, bg, f'text contrast {ratio:.2f}:1 is below 4.5:1')


def run(args):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        raise AssertionError(f"{args}\n{result.stdout}\n{result.stderr}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--browser', action='store_true')
    args = ap.parse_args()
    for tool in ('bash', 'pwsh', 'pandoc'):
        if not shutil.which(tool): ap.error(f'{tool} is required')
    themes = sorted(p.parent.name for p in (ROOT/'templates').glob('*/index.html') if p.parent.name != 'common')
    recommendations = {}
    for line in (ROOT/'templates/common/highlight-recommendations.tsv').read_text().splitlines():
        if line and not line.startswith('#'):
            fields = line.split('|')
            assert fields[0] not in recommendations, fields[0]
            recommendations[fields[0]] = fields[1]
    assert set(themes) == set(recommendations), 'Theme registry differs from highlight recommendations'
    for theme in themes:
        check_palette(theme)
    sample = '''---
title: Lesson
nav: true
date: "2026-01-01"
---
## Practice

Readable text with an [example](https://example.org).

```python
def greet(name):
    # A readable comment
    return "Hello " + name
```

```
plain text code
```
'''
    browser = playwright = None
    if args.browser:
        from playwright.sync_api import sync_playwright
        playwright = sync_playwright().start()
        browser = playwright.chromium.launch(executable_path=os.environ.get('CHROMIUM'), headless=True)
    try:
        with tempfile.TemporaryDirectory(prefix='zeta-parity-', dir=ROOT/'sites') as folder:
            site = Path(folder)
            (site/'posts').mkdir(); (site/'pages').mkdir()
            (site/'posts/2026-01-01-lesson.md').write_text(sample)
            (site/'pages/index.md').write_text('# Home\n')
            (site/'pages/lesson.md').write_text(sample)
            for theme_index, theme in enumerate(themes):
                for extension in ('yaml', 'yml'):
                    (site/f'config.{extension}').unlink(missing_ok=True)
                config_name = 'config.yaml' if theme_index % 2 else 'config.yml'
                (site/config_name).write_text(f'''site:
  title: "Theme parity"
  description: "Learning together"
  author: "QA"
  language: "en"
  url: "https://example.org"
theme:
  name: "{theme}"
  pandoc_theme: "{recommendations[theme]}"
build:
  content_dir: "posts"
  output_dir: "public"
homepage:
  layout: theme
  show_posts: false
''')
                snapshots = []
                for engine in ('bash', 'pwsh'):
                    cmd = ['bash', str(ROOT/'zeta.sh')] if engine == 'bash' else ['pwsh', '-NoProfile', '-File', str(ROOT/'zeta.ps1')]
                    run(cmd + ['build', site.name])
                    contracts = []
                    code_styles = []
                    syntax_css = []
                    for route in ('index.html', 'posts.html', 'lesson/index.html', 'posts/2026/lesson.html'):
                        path = site/'public'/route
                        text = path.read_text()
                        c = Contract(text)
                        assert c.lang and c.main and c.skip, (theme, engine, route, 'landmarks')
                        assert all((path.parent/link).is_file() for link in c.css), (theme, route, 'CSS missing')
                        assert not re.search(r'\$(?:body|styles|site_title)\$', text), (theme, route, 'unexpanded template')
                        if 'lesson' in route:
                            assert 'python' in ' '.join(c.code), (theme, route, 'code missing')
                            assert re.search(r'code span\.(kw|cf|fu)', text), (theme, route, 'highlight CSS missing')
                            syntax_css.append(re.findall(r'code span\.[a-z]+\s*\{[^}]*\}', text))
                        contracts.append((c.css, c.headings, c.code, c.nav))
                        if browser:
                            page = browser.new_page(viewport={'width': 375, 'height': 812})
                            page.goto(path.as_uri())
                            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth + 1'), (theme, engine, route, 'mobile overflow')
                            page.keyboard.press('Tab')
                            assert page.locator(':focus').get_attribute('href') == '#content', (theme, route, 'skip link is not first')
                            if 'lesson' in route:
                                code_styles.append(page.locator('div.sourceCode').first.evaluate("e => [getComputedStyle(e).backgroundColor, ...[...e.querySelectorAll('code span')].map(x => getComputedStyle(x).color)]"))
                            page.set_viewport_size({'width': 1440, 'height': 900})
                            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth + 1'), (theme, route, 'desktop overflow')
                            page.close()
                    assert syntax_css[0] == syntax_css[1], (theme, engine, 'page/article syntax CSS differs')
                    if browser: assert code_styles[0] == code_styles[1], (theme, engine, 'page/article syntax palette differs')
                    snapshots.append(contracts)
                assert snapshots[0] == snapshots[1], (theme, 'Bash/PowerShell output contract differs')
                print(f'[OK] {theme}: native engines, routes, navigation, highlighting' + ('; browser checks' if browser else ''), flush=True)
    finally:
        if browser: browser.close()
        if playwright: playwright.stop()

if __name__ == '__main__': main()

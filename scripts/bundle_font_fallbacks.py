#!/usr/bin/env python3
"""Bundle the Flutter SDK's emoji fallbacks; optionally bundle every script.

Initial builds require Internet; the resulting app requests fonts locally.
Pass --all-fonts for complete multilingual fallback coverage (a larger build).
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
from urllib.request import urlopen

parser = argparse.ArgumentParser()
parser.add_argument('flutter_sdk', type=Path)
parser.add_argument('--all-fonts', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
source = args.flutter_sdk / 'engine/src/flutter/lib/web_ui/lib/src/engine/font_fallback_data.dart'
fonts = set(re.findall(r"'([^']+\.woff2)'", source.read_text()))
if not args.all_fonts:
    fonts = {name for name in fonts if name.startswith('notocoloremoji/')}
fonts.add('roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2')
destination = root / 'build/web/font-fallbacks'
def download(name):
    file = destination / name
    if file.exists():
        return
    with urlopen('https://fonts.gstatic.com/s/' + name, timeout=60) as response:
        data = response.read()
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_bytes(data)
with ThreadPoolExecutor(max_workers=6) as executor:
    list(executor.map(download, sorted(fonts)))
print(f'Bundled {len(fonts)} local fallback fonts')

licenses = {
    'Noto-OFL.txt': 'https://raw.githubusercontent.com/googlefonts/noto-emoji/main/LICENSE',
    'Roboto-LICENSE.txt': 'https://raw.githubusercontent.com/googlefonts/roboto-2/main/LICENSE',
}
for name, url in licenses.items():
    file = destination / name
    if not file.exists():
        with urlopen(url, timeout=60) as response:
            file.write_bytes(response.read())

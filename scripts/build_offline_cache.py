#!/usr/bin/env python3
"""Run after flutter build web --no-web-resources-cdn --pwa-strategy=none."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
build = root / 'build/web'
files = sorted(p.relative_to(build).as_posix() for p in build.rglob('*')
               if p.is_file() and p.name not in {'service-worker.js', 'flutter_service_worker.js', 'service-worker.template.js', '.last_build_id'}
               and not p.name.endswith('.symbols'))
version = hashlib.sha256()
for name in files:
    version.update(name.encode())
    version.update((build / name).read_bytes())
worker = (root / 'web/service-worker.template.js').read_text()
worker = worker.replace('__CACHE_VERSION__', version.hexdigest()[:20])
worker = worker.replace('__PRECACHE_FILES__', json.dumps(files))
(build / 'service-worker.js').write_text(worker)
print(f'Offline cache: {len(files)} files, version {version.hexdigest()[:20]}')

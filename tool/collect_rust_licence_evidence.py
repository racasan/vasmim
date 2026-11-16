"""Collect checksum-verified registry source/notices without installing crates.

All lockfile targets are retained conservatively. This is not a binary SBOM or
Cargo feature resolver. Archives are inspected in memory, never extracted/run.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import tarfile
import tomllib
import urllib.request


def collect(package, destination):
    name, version = package['name'], package['version']
    if not re.fullmatch(r'[A-Za-z0-9_.+-]+', name + version):
        raise ValueError('Unexpected package identifier')
    url = f'https://static.crates.io/crates/{name}/{name}-{version}.crate'
    request = urllib.request.Request(url, headers={'User-Agent': 'Vasmim-licence-review/1.0'})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read(32 * 1024 * 1024 + 1)
    if len(data) > 32 * 1024 * 1024:
        raise ValueError(f'Archive exceeds review limit: {name}')
    digest = hashlib.sha256(data).hexdigest()
    if digest != package['checksum']:
        raise ValueError(f'Lockfile checksum mismatch: {name}')
    target = destination / f'{name}-{version}'
    target.mkdir()
    with (target / 'source.crate').open('xb') as output:
        output.write(data)
    notices, metadata = [], {}
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        for member in archive:
            path = PurePosixPath(member.name)
            if not member.isfile() or member.size > 4 * 1024 * 1024:
                continue
            is_manifest = path.parts == (f'{name}-{version}', 'Cargo.toml')
            is_notice = any(term in path.name.upper() for term in
                            ('LICENSE', 'LICENCE', 'COPYING', 'NOTICE', 'COPYRIGHT'))
            if not (is_manifest or is_notice):
                continue
            content = archive.extractfile(member).read()
            if is_manifest:
                manifest = tomllib.loads(content.decode('utf-8'))
                metadata = {key: manifest.get('package', {}).get(key)
                            for key in ('license', 'license-file', 'repository')}
                with (target / 'Cargo.toml').open('xb') as output:
                    output.write(content)
            if is_notice:
                # Numeric output names avoid trusting archive paths.
                filename = f'notice-{len(notices):03d}.txt'
                with (target / filename).open('xb') as output:
                    output.write(content)
                notices.append({'archivePath': member.name, 'file': filename,
                                'sha256': hashlib.sha256(content).hexdigest()})
    return {'name': name, 'version': version, 'sourceUrl': url,
            'sha256': digest, **metadata, 'notices': notices}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lock', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    packages = tomllib.loads(args.lock.read_text(encoding='utf-8'))['package']
    args.output.mkdir(parents=True, exist_ok=False)
    registry = [p for p in packages if p.get('source', '').startswith('registry+')]
    other = [p for p in packages if not p.get('source', '').startswith('registry+')]
    with ThreadPoolExecutor(max_workers=6) as pool:
        entries = list(pool.map(lambda p: collect(p, args.output), registry))
    result = {'scope': 'All lockfile registry crates, all platforms/build/dev; not a binary SBOM',
              'lockSha256': hashlib.sha256(args.lock.read_bytes()).hexdigest(),
              'packages': entries, 'nonRegistryPackagesNotCollected': other}
    with (args.output / 'inventory.json').open('x', encoding='utf-8') as output:
        json.dump(result, output, indent=2)
    print(json.dumps({'verifiedArchives': len(entries),
                      'noticeFiles': sum(len(p['notices']) for p in entries),
                      'withoutNoticeFile': [p['name'] for p in entries if not p['notices']],
                      'nonRegistryPackages': [p['name'] for p in other]}))


if __name__ == '__main__':
    main()

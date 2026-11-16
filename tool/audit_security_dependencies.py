"""Read-only OSV screening of resolved Pub versions; no installs or code upload.

Only public package names/versions and optional public Git commits leave the PC.
Results are advisory matches, not a claim that unlisted vulnerabilities do not exist.
"""
import argparse
import json
from pathlib import Path
import re
import urllib.request


def locked_packages(path):
    entries = []
    current = None
    for line in path.read_text(encoding='utf-8').splitlines():
        match = re.fullmatch(r'  ([a-zA-Z0-9_]+):', line)
        if match:
            current = {'name': match[1]}
        elif current:
            source = re.fullmatch(r'    source: (\S+)', line)
            version = re.fullmatch(r'    version: "([^"]+)"', line)
            if source:
                current['source'] = source[1]
            if version:
                current['version'] = version[1]
                if current.get('source') == 'hosted':
                    entries.append(current)
                current = None
    return entries


def api(path, payload=None):
    request = urllib.request.Request('https://api.osv.dev/v1/' + path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={'Content-Type': 'application/json', 'User-Agent': 'Vasmim-release-audit/1'})
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lock', type=Path, default=Path('pubspec.lock'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    packages = locked_packages(args.lock)
    if not packages:
        raise ValueError('No hosted packages parsed; refusing an empty scan')
    args.output.mkdir(parents=True, exist_ok=False)
    queries = [{'package': {'name': p['name'], 'ecosystem': 'Pub'}, 'version': p['version']}
               for p in packages]
    report = []
    advisory_ids = set()
    # Preserve every page. A batch query returns IDs only, so fetch each record.
    for index, query in enumerate(queries):
        response = api('query', query)
        pages = [response]
        while response.get('next_page_token'):
            response = api('query', {**query, 'page_token': response['next_page_token']})
            pages.append(response)
        vulnerabilities = [v for page in pages for v in page.get('vulns', [])]
        for vuln in vulnerabilities:
            advisory_ids.add(vuln['id'])
            path = args.output / (vuln['id'] + '.json')
            if not path.exists():
                path.write_text(json.dumps(vuln, indent=2) + '\n', encoding='utf-8')
        report.append({**packages[index], 'advisories': [v['id'] for v in vulnerabilities]})
    result = {'database': 'https://api.osv.dev/v1/query',
              'scope': 'All locked hosted packages, including dev/platform packages; native libraries and Flutter/Dart SDK are separate.',
              'packagesQueried': len(packages), 'matchedAdvisories': sorted(advisory_ids), 'packages': report}
    (args.output / 'pub-osv-results.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'packagesQueried': len(packages), 'matchedAdvisories': sorted(advisory_ids),
                      'matches': [r for r in report if r['advisories']]}, indent=2))


if __name__ == '__main__':
    main()

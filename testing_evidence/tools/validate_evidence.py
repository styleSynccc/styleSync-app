"""Verify generated evidence references, counts, preservation and artifact hashes."""
import csv
import hashlib
import json
from pathlib import Path
import re

from PIL import Image

from run_qa import EVIDENCE


def main():
    manifest = json.loads((EVIDENCE / 'reports/Evidence_Manifest.json').read_text(encoding='utf-8'))
    checked = 0
    for item in manifest['files']:
        path = EVIDENCE / item['path']
        assert path.is_file(), item['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256'], item['path']
        checked += 1
    links = 0
    for path in EVIDENCE.rglob('*.md'):
        for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', path.read_text(encoding='utf-8')):
            if '://' not in target and not target.startswith('#'):
                resolved = path.parent / target.split('#')[0]
                assert resolved.exists(), (str(path), target)
                links += 1
    cases = json.loads((EVIDENCE / 'reports/test_cases.json').read_text(encoding='utf-8'))
    assert [case['id'] for case in cases] == [f'TC-{i:03d}' for i in range(1, 37)]
    for case in cases:
        payload = json.loads((EVIDENCE / case['evidence']).read_text(encoding='utf-8'))
        assert payload['status'] == case['status']
        for screenshot in case['screenshots']:
            with Image.open(EVIDENCE / screenshot) as image:
                assert image.format == 'PNG' and image.size == (800, 1000)
    with (EVIDENCE / 'reports/Coverage_Mapping.csv').open(encoding='utf-8-sig', newline='') as file:
        assert len(list(csv.DictReader(file))) == 36
    integrity = json.loads((EVIDENCE / 'logs/integration/repository_integrity.json').read_text())
    assert integrity['tracked_changes'] == []
    assert all(item['same_as_HEAD_normalized'] for item in integrity['existing_test_integrity'])
    assert len(list(EVIDENCE.glob('screenshots/UC-*/*.png'))) == 3
    assert len(list(EVIDENCE.glob('screenshots/UC-*'))) == 12
    assert len(list(EVIDENCE.glob('logs/integration/TC-*_evidence.json'))) == 36
    print(json.dumps({'artifact_hashes_verified': checked, 'local_markdown_links_verified': links,
                      'scenario_records': 36, 'widget_screenshots': 3, 'original_test_files_preserved': len(integrity['existing_test_integrity']),
                      'result': 'PASS'}, indent=2))


if __name__ == '__main__':
    main()

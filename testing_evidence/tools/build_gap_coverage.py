"""Report the executed coverage additions without rewriting historical reports."""
from collections import Counter
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess

from build_report import python_results, SUPPORT
from run_qa import EVIDENCE, ROOT, stamp

FLUTTER_RUN = 'gap_expansion_full_03'
PYTHON_RUN = 'gap_expansion_full_01'
NEW_FILES = {
    'fyp_auth_workflow_test.dart', 'fyp_wardrobe_workflow_test.dart',
    'fyp_twin_workflow_test.dart', 'fyp_tryon_workflow_test.dart',
    'fyp_inspo_workflow_test.dart', 'fyp_planner_workflow_test.dart',
    'tests/test_fyp_workflow_gaps.py',
}


def flutter_results(label):
    # JSONL uses LF records. splitlines() also splits Unicode control characters
    # inside binary-fixture failure diagnostics, corrupting otherwise valid JSON.
    path = EVIDENCE / f'logs/flutter/{label}.jsonl'
    suites, tests, messages, results = {}, {}, {}, []
    for line in path.read_text(encoding='utf-8').split('\n'):
        if not line.strip():
            continue
        event = json.loads(line)
        kind = event['type']
        if kind == 'suite':
            suites[event['suite']['id']] = event['suite']['path']
        elif kind == 'testStart':
            tests[event['test']['id']] = event['test']
        elif kind in ('error', 'print'):
            messages.setdefault(event.get('testID'), []).append(event.get('error', event.get('message', '')))
        elif kind == 'testDone' and not event.get('hidden'):
            test = tests[event['testID']]
            if test['name'].startswith('loading ') or test['name'] in ('(setUpAll)', '(tearDownAll)'):
                continue
            results.append({'framework': 'Flutter', 'name': suites[test['suiteID']].split('/test/')[-1] + '::' + test['name'],
                            'status': 'SKIP' if event.get('skipped') else 'PASS' if event['result'] == 'success' else 'FAIL',
                            'messages': messages.get(event['testID'], []), 'evidence': f'logs/flutter/{label}.jsonl', 'run': label})
    return results

GAPS = {
    'fyp_auth_workflow_test.dart': 'Existing valid-form tests stopped at a recording controller; these exercise the real AuthController success/profile-routing chain and previously untested malformed-email/password-strength variants.',
    'fyp_wardrobe_workflow_test.dart': 'No real ClosetController upload/cancel or Home category-sheet interaction tests existed; these verify processed bytes, selected category, no-write cancellation and category dismissal.',
    'fyp_twin_workflow_test.dart': 'Existing checks covered metric helpers and API processing separately; these cover completed merged profile persistence, missing-weight/style guards and the actual twin/empty-twin screen.',
    'fyp_tryon_workflow_test.dart': 'Backend composition and OutfitDraft were covered, but changed UI selections, no-twin VTON UI, screen-to-save-to-view flow and remote-image failure in the full viewer were not.',
    'fyp_inspo_workflow_test.dart': 'Existing UI tests covered an empty twin list and cancelling an empty picker; these add a real local preview, cancelling replacement, choosing another twin, selected-reference/no-twin guard and processing-error UI.',
    'fyp_planner_workflow_test.dart': 'Only date models and mocked notification service payloads were covered; these exercise real date/time pickers, save/list rendering, date changes and cancellation at all three stages.',
    'tests/test_fyp_workflow_gaps.py': 'Existing list tests seeded stores directly; these create through FastAPI, recreate the app/store and retrieve the actual persisted twin/garment with user isolation.',
}

REMAINING = {
    'TC-001': 'MANUAL / isolated integration: real Auth account creation, Firestore profile persistence and routing.',
    'TC-002': 'Local validation automated; confirm small-screen/keyboard layout on Android.',
    'TC-003': 'MANUAL / isolated integration: real duplicate email rejection and unchanged account count; existing fake-error test reused.',
    'TC-004': 'MANUAL / isolated integration: real credentials/session and completed/incomplete-profile destinations.',
    'TC-005': 'MANUAL / isolated integration: real wrong-password error and signed-out state; existing fake-error test reused.',
    'TC-006': 'Local validation automated; confirm keyboard/field behavior on Android.',
    'TC-007': 'MANUAL / isolated integration: real pose/background-removal models and Firebase uploads/profile.',
    'TC-008': 'Missing photo/height/weight/styles and metric validation automated; confirm on-device notices.',
    'TC-009': 'MANUAL / isolated integration: real user session, device reopen/retrieval and backend-offline Firebase-photo fallback.',
    'TC-010': 'MANUAL: native gallery and real service upload; controller path and API restart persistence now automated.',
    'TC-011': 'MANUAL: camera permission, physical capture and acceptance; source selection/controller upload now automated with picker mock.',
    'TC-012': 'MANUAL: native gallery/camera Back gestures; null-picker no-write business behavior now automated.',
    'TC-013': 'MANUAL / isolated integration: category-first upload across real Firebase/backend; controller category persistence automated.',
    'TC-014': 'REQUIREMENT GAP: no saved category editor. Only the explicitly revised pre-upload category-selection interaction is automated.',
    'TC-015': 'Category-sheet dismissal automated; native navigation/layout confirmation remains manual.',
    'TC-016': 'MANUAL: real AI image/identity/garment quality; existing six credit-confirmation assertions still fail and need approved resolution.',
    'TC-017': 'Final garment request selection automated; real garment change in hosted AI output requires manual review.',
    'TC-018': 'No-twin disabled VTON UI and API rejection automated; verify approved no-twin Android test account.',
    'TC-019': 'Screen-to-storage/document-to-viewer save automated with Firebase fakes; real persistence/reopen requires integration.',
    'TC-020': 'REQUIREMENT GAP: no cancel-save dialog. Revised leave-unsaved behavior is automated; backend result retention is separate.',
    'TC-021': 'Current-draft save locking and disabled Saved UI automated; verify real document/object count. Cross-session deduplication is not implemented.',
    'TC-022': 'Local preview/no-premature-upload automated; native picker and real multipart transfer require integration.',
    'TC-023': 'Server SVG/malformed-input rejection already automated and reused; actual native picker format support/exclusion is manual.',
    'TC-024': 'Both empty-selection and replacement cancellation automated at plugin boundary; native gallery Back is manual.',
    'TC-025': 'Selected twin/reference/result UI automated with fake provider; real outfit/identity fidelity and shared credit-disclosure issue remain.',
    'TC-026': 'Selected reference without a twin now automated; real account/device setup guidance confirmation remains.',
    'TC-027': 'Malformed/undersized checks and mocked provider-error UI automated. Valid-size blank image still reaches provider; semantic suitability and real AI behavior require criteria/manual review.',
    'TC-028': 'Date/time/item selection, plan write, visible card and mocked alarm payload automated; real Firestore/Android alarm delivery remain manual.',
    'TC-029': 'Changing date before commit automated; no dedicated move-existing-plan action exists.',
    'TC-030': 'Date/time/item cancellation and no-write/no-alarm assertions automated; confirm OS navigation/permission interaction manually.',
    'TC-031': 'Upcoming plan cards/items now automated; real multi-session stream/reopen and actual reminder expiry require integration.',
    'TC-032': 'REQUIREMENT GAP: no daily selected-date viewer. Revised empty-upcoming-list behavior automated.',
    'TC-033': 'REQUIREMENT GAP: no daily calendar navigation. Revised multiple dated list cards automated.',
    'TC-034': 'Generated-result display and saved full viewer automated; real visual correctness manual. Applying arbitrary saved/planned items to a twin is a separate absent operation.',
    'TC-035': 'Empty Virtual Twin/Create Twin now automated; verify real no-twin account. Viewing an existing saved image is independent of a current twin.',
    'TC-036': 'Missing URL component and simulated remote-image failure in full viewer automated; confirm real missing test object/offline Android navigation.',
}


def main():
    reports = EVIDENCE / 'reports'
    current = flutter_results(FLUTTER_RUN) + python_results(PYTHON_RUN)
    new = [r for r in current if r['name'].split('::')[0] in NEW_FILES]
    assert len(new) == 39 and all(r['status'] == 'PASS' for r in new)
    assert Counter(r['status'] for r in current) == {'PASS': 255, 'FAIL': 6}
    assert len(current) == 261
    prior = json.loads((EVIDENCE / 'logs/integration/suite_20261116_run2_summary.json').read_text())
    cases = json.loads((reports / 'test_cases.json').read_text())
    indexed = {(r['framework'], r['name']): r for r in current}
    prior_coverage = {r['id']: r for r in prior['coverage']}
    attempts = []
    for folder in ['flutter', 'fastapi']:
        for path in sorted((EVIDENCE / 'logs' / folder).glob('gap_*.log.meta.json')):
            if path.name.startswith('gap_expansion'):
                continue
            meta = json.loads(path.read_text())
            label = path.name.removesuffix('.log.meta.json')
            results = flutter_results(label) if folder == 'flutter' else python_results(label)
            attempts.append({'label': label, 'metadata': meta, 'tests': results,
                             'collection_note': 'Compilation/collection failure: no test body executed.' if not results else None})
    rows = []
    for case in cases:
        tc = case['id']
        existing_keys = {(r['framework'], r['name']) for r in prior_coverage[tc]['executed_related_checks']}
        existing = [indexed[key] for key in existing_keys if key in indexed]
        if tc == 'TC-007':
            # A legacy function named TC007 checks a missing photo, which is
            # a negative TC-008 precondition rather than successful creation.
            existing = [r for r in existing if '::invalid body metric' not in r['name'] and 'missing_twin_photo' not in r['name']]
        if tc == 'TC-008':
            existing += [r for r in current if 'test_TC007_missing_twin_photo' in r['name']]
        additions = [r for r in new if tc in ['TC-' + number for number in re.findall(r'TC-?(\d{3})', r['name'])]]
        if tc == 'TC-016':
            additions += [r for r in new if r['name'].startswith('fyp_tryon_workflow_test.dart::TC-017')]
        checks = existing + additions
        outcome = Counter(r['status'] for r in checks)
        if tc in ['TC-014', 'TC-020', 'TC-032', 'TC-033']:
            scope = 'PASS for revised interaction only; original NOT RUN'
        elif outcome['FAIL']:
            scope = f'MIXED: {outcome["PASS"]} PASS, {outcome["FAIL"]} FAIL (isolated)'
        else:
            scope = f'PASS: {outcome["PASS"]} isolated checks; live acceptance unverified'
        by_script = {}
        for record in checks:
            name = record['name'].split('::')[0]
            by_script.setdefault(name, Counter())[record['status']] += 1
        scripts = '; '.join(f'{name}: ' + ', '.join(f'{v} {k}' for k, v in counts.items()) for name, counts in sorted(by_script.items()))
        rows.append({'id': tc, 'use_case': case['uc'], 'scenario': case['scenario'], 'automated_outcome': scope,
                     'scripts_and_outcomes': scripts, 'new_check_count': len(additions),
                     'original_acceptance_status': case['status'], 'remaining_testing': REMAINING[tc],
                     'existing_checks': existing, 'new_checks': additions})
    integrity = json.loads((EVIDENCE / 'logs/integration/repository_integrity.json').read_text())
    for file in integrity['existing_test_integrity']:
        assert hashlib.sha256((ROOT / file['path']).read_bytes()).hexdigest() == file['sha256'], file['path']
    changes = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD'], cwd=ROOT, text=True).splitlines()
    assert not changes, changes
    data = {'generated_at': stamp(), 'full_runs': {'flutter': FLUTTER_RUN, 'fastapi': PYTHON_RUN},
            'full_suite_outcomes': dict(Counter(r['status'] for r in current)),
            'new_test_outcomes': dict(Counter(r['status'] for r in new)), 'new_tests': new,
            'individual_attempts': attempts, 'coverage': rows,
            'preservation': {'tracked_source_changes': changes, 'original_test_files_hash_verified': len(integrity['existing_test_integrity'])}}
    (reports / 'Functional_Gap_Coverage_Matrix.json').write_text(json.dumps(data, indent=2), encoding='utf-8')
    fields = ['id','use_case','scenario','automated_outcome','scripts_and_outcomes','new_check_count','original_acceptance_status','remaining_testing']
    with (reports / 'Functional_Gap_Coverage_Matrix.csv').open('w', newline='', encoding='utf-8-sig') as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        writer.writerows({key: row[key] for key in fields} for row in rows)
    matrix = '\n'.join(f"| {r['id']} | {r['scenario']} | {r['scripts_and_outcomes']} | {r['automated_outcome']} | {r['remaining_testing']} |" for r in rows)
    new_inventory = []
    for record in new:
        successful = [a for a in attempts if a['metadata']['exit_code'] == 0 and any(r['name'] == record['name'] for r in a['tests'])]
        assert successful, record['name']
        a = successful[-1]
        new_inventory.append(f"| `{record['name']}` | PASS | [{a['label']}](../{Path(a['metadata']['log']).as_posix()}) |")
    failures = [r for r in current if r['status'] == 'FAIL']
    failed_attempts = [a for a in attempts if a['metadata']['exit_code'] != 0]
    rationale = '\n'.join(f"| `{name}` | {reason} |" for name, reason in GAPS.items())
    attempt_table = '\n'.join(f"| {a['label']} | {a['metadata']['exit_code']} | [{Path(a['metadata']['log']).name}](../{Path(a['metadata']['log']).as_posix()}) |" for a in attempts)
    report = f'''# StyleSync added functional coverage and execution matrix

Generated {stamp()} (Asia/Kuala_Lumpur). **39 new tests were created in seven separate test scripts: 37 Flutter widget/controller tests and 2 FastAPI workflow tests. All 39 ran individually and passed; all also passed in the combined suites after fixture isolation corrections.** No pre-existing test file, application code, dependency manifest, Firebase settings/rules or production data was modified. The test-only shared helper uses existing installed platform interfaces; no packages were added.

## Actual execution results

| Suite | Total | Passed | Failed | Skipped / collection errors | Evidence |
| --- | ---: | ---: | ---: | --- | --- |
| Current Flutter suite | 110 | 104 | 6 | 0 / 0 | [Full log](../logs/flutter/{FLUTTER_RUN}.log), [JSONL](../logs/flutter/{FLUTTER_RUN}.jsonl), [metadata](../logs/flutter/{FLUTTER_RUN}.log.meta.json) |
| Current FastAPI suite | 151 | 151 | 0 | 0 / 0 | [Full log](../logs/fastapi/{PYTHON_RUN}.log), [JUnit](../logs/fastapi/{PYTHON_RUN}.xml), [metadata](../logs/fastapi/{PYTHON_RUN}.log.meta.json) |
| New tests only | 39 | 39 | 0 | 0 / 0 | Named individual runs below and combined native results |
| **Combined unique tests** | **261** | **255** | **6** | **0 / 0** | **97.70% assertion pass rate; not live functional acceptance** |

The previous suite had 222 tests (216 PASS / 6 FAIL). Exactly 39 were added; existing assertions were preserved. The original placeholder test remains nonfunctional coverage. Test exit codes are Flutter 1 and pytest 0; the older full-suite capture wrapper records the child's actual status in metadata even though the wrapper exits zero.

Each new test was selected with `flutter test --no-pub <new file> --plain-name <exact name>` or `python -m pytest <new module>::<node>` from the correct app directory. Full suites subsequently ran from `apps/mobile_app` and `apps/ai_service`. `testing_evidence/tools/run_functional_gap.py` preserves stdout/stderr, native results, exact command, cwd, timestamps and actual test exit code, and refuses to overwrite evidence.

Targeted static analysis of the six new Dart test scripts and shared helper completed with **No issues found**: [analyzer log](../logs/flutter/gap_expansion_analyze_final.log). Its initial ten style diagnostics were corrected in the new files before the final full-suite run; no existing file was edited.

## Why these tests were necessary

Tests were added for uncovered behaviors and boundary variants, not to duplicate the existing happy-path API, body-metric helper, empty-form, duplicate-save model or malformed-image assertions.

| New script | Coverage gap addressed |
| --- | --- |
{rationale}

## Coverage matrix TC-001 through TC-036

“PASS” in the automated outcome column means executed assertions at the stated isolated scope. It does not certify real Firebase, paid AI or Android plugin operation. Existing and new results below come from the latest combined native logs. The same check can support multiple cases; per-row counts must not be summed. Exact test names and individual evidence are retained in [the JSON matrix](Functional_Gap_Coverage_Matrix.json); [CSV matrix](Functional_Gap_Coverage_Matrix.csv) is also available.

Original full-scenario acceptance remains conservative: **TC-002/006/008 passed local validation; 29 cases require integration/manual acceptance; TC-014/020/032/033 retain NOT RUN for the literal original interaction.** New tests of the four proposed replacement interactions are labeled “revised”; they do not silently replace the FYP requirements. No complete Android/real-Firebase/real-AI acceptance is claimed.

| Case | Scenario | Test scripts and actual outcomes | Automated evidence outcome | Remaining manual/integration work |
| --- | --- | --- | --- | --- |
{matrix}

## Individual new-test results

Every row below has both a successful individual execution and a successful result in the latest combined suite. Previously failed attempts are preserved in the attempt history, rather than overwritten. A compile error or earlier failed assertion was never recorded as a successful execution.

| New test | Final outcome | Successful individual terminal log |
| --- | --- | --- |
{chr(10).join(new_inventory)}

## Remaining failures and observed limitations

The six **pre-existing** failures remain in `generation_confirmation_test.dart`:

{chr(10).join('- `' + r['name'] + '`' for r in failures)}

They expect credit-total titles/action text while production `confirmGeneration` displays `Generate outfit?` and a generic Generate action. No application fix or assertion weakening was performed. The new workflow tests exercise selected-request/result/save behavior and do not bypass or relabel those failing cost-disclosure assertions. They are supplemental checks with a different scope.

FastAPI still emits one Starlette TestClient/HTTPX deprecation warning. The two new backend tests use real FastAPI decoding and temporary filesystem persistence with fake authentication/model engines; they do not test a live AI model. Semantic suitability remains undefined: the existing blank-reference characterization still calls the fake provider and returns 201. New TC-027 checks error presentation when a processing rejection is returned, not semantic rejection accuracy.

## Test fixture corrections and complete attempt history

There were {len(attempts)} individual execution attempts; {len(failed_attempts)} returned nonzero before correction. All logs remain. Issues were in the new fixtures/tests: awaiting Get.reset despite its void return, missing HTTP redirects in the fake client, Windows stdout encoding of failure diagnostics, lazy-list finder positioning, waiting for native image decoding, binary multipart decoding, mixed path separators in a test-created image filename, and cleanup of the test Android platform override. None required application changes or weaker expectations.

The first combined Flutter run ([log](../logs/flutter/gap_expansion_full_01.log)) had 87 PASS / 23 FAIL: six known application/test-contract failures and seventeen new shared-fixture failures. Root cause was firebase_core caching its core delegate independently of the platform singleton; later tests reused earlier fake Auth/Firestore/Storage clients. The helper now resets and restores Firebase's documented `delegatePackingProperty` testing hook and uses a unique fake app name. Latest combined run is 104 PASS / 6 known FAIL, with all additions passing. HTTP/image test clients are restored after each scoped operation.

| Attempt | Actual test/capture exit | Terminal evidence |
| --- | ---: | --- |
{attempt_table}

## Manual instructions and preservation

[Functional_Gap_Manual_Guide.md](Functional_Gap_Manual_Guide.md) provides all 36 cases with exact steps, data, expected behavior, screenshot timing/names and Firebase/FastAPI evidence inspection. Rows that need device/service interaction are explicitly marked. For an unavailable literal feature, first record the absence and resolve the requirement; do not claim a manual PASS for an unimplemented action.

SDK adapters, picker, HTTP provider and notification channels are test fakes. Their data stays in memory except synthetic image files in a newly created temporary directory, which each test cleans up. API persistence uses pytest tmp_path, not existing AI_DATA_DIR. No production credentials or data were read or changed. All 30 original tracked test/fixture files were hash-checked against the earlier integrity snapshot and remain identical; no tracked source changes are present. Historical reports remain unchanged and are superseded for current coverage by this matrix.
'''
    (reports / 'Functional_Gap_Coverage_Matrix.md').write_text(report, encoding='utf-8')
    manual = '''# StyleSync remaining manual and integration execution guide

These procedures are not executed test results. The 39 newly added isolated tests passed; the native Android and live-service behaviors below still require evidence. See the coverage matrix for the current automated outcomes and the exact passing test nodes.

## Prepare the environment

Use an approved dedicated Firebase test project or isolated Auth/Firestore/Storage emulators and synthetic/consented images. Existing Firebase wiring uses configured project options; changes to application code, dependencies, settings or security rules still need explicit approval. This work made none. Never create/delete production accounts, photos or plans to construct test conditions.

Connect an Android emulator/phone and run `adb devices -l`. Record device model, Android version, build revision and local time in Asia/Kuala_Lumpur. Configure the approved test build to reach the isolated AI service via its actual address; Android emulator host access commonly uses 10.0.2.2. Keep AI_DATA_DIR separate from existing data. Real models/extraction services and approved hosted AI credentials/credits are necessary only for live processing/generation cases. Do not log or screenshot passwords, bearer tokens, API keys, full image base64 or private tokenized image URLs.

Create test-user aliases QA-New, QA-Ready, QA-Incomplete and QA-NoTwin only in the dedicated environment. Keep their actual credentials privately. Use a clear full-body photo at least 320x640, clothing images at least 256x256, two distinct test tops, a clear fully clothed inspiration subject, tiny 120x160 JPEG, safe SVG and a valid-sized blank/non-person reference. Select future local reminder dates; recalculate them when the guide is executed. For real AI requests, confirm the approved budget, submit once and preserve the response rather than blindly retrying.

## Record each outcome

Save redacted execution notes under `testing_evidence/logs/integration/TC-NNN_manual.md`. Include test data alias, setup, exact steps, expected and observed behavior, PASS/FAIL/BLOCKED/NOT RUN, local timestamp and screenshot/log paths. For cancellation, compare before/after document/object counts and API requests. A success snackbar alone is not evidence of persistence. Use the planned screenshot filenames below; they are not proof of execution until the files are captured. Existing `_widget.png` files are earlier widget captures, not Android screenshots.

'''
    for case in cases:
        tc = case['id']
        instructions = case['steps'].split('; ')
        manual += f"## {tc} — {case['scenario']}\n\n**Manual/integration requirement:** {REMAINING[tc]}\n\n**Test data:** {case['data']}\n\n**Execution:**\n\n"
        manual += '\n'.join(f'{i}. {step}' for i, step in enumerate(instructions, 1))
        manual += f"\n\n**Expected behavior:** {case['expected']}\n\n**Capture:** {case['moment']} Save under `testing_evidence/{case['proposed_screenshot']}`; suffix additional variants.\n\n**Supporting service evidence:** {SUPPORT[case['support']]}\n\n"
        if tc in ['TC-014', 'TC-020', 'TC-032', 'TC-033']:
            manual += '**Literal original scenario:** NOT RUN / requirement gap. Inspect available actions and record the absence. The revised local interaction has automated evidence but does not establish acceptance of the original requirement.\n\n'
    (reports / 'Functional_Gap_Manual_Guide.md').write_text(manual, encoding='utf-8')
    # Include all attempt logs and source in this report's own manifest.
    paths = [p for p in (reports / 'Functional_Gap_Coverage_Matrix.md', reports / 'Functional_Gap_Coverage_Matrix.csv', reports / 'Functional_Gap_Coverage_Matrix.json', reports / 'Functional_Gap_Manual_Guide.md')]
    paths += [p for folder in ['flutter','fastapi'] for p in (EVIDENCE / 'logs' / folder).glob('gap_*') if p.is_file()]
    paths += list((ROOT / 'apps/mobile_app/test').glob('*_workflow_test.dart'))
    paths += [ROOT / 'apps/mobile_app/test/support/functional_fakes.dart', ROOT / 'apps/ai_service/tests/test_workflow_gaps.py']
    manifest = [{'path_from_repo': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(set(paths))]
    (reports / 'Functional_Gap_Evidence_Manifest.json').write_text(json.dumps({'generated_at': stamp(), 'files': manifest}, indent=2), encoding='utf-8')
    print(json.dumps({'new': Counter(r['status'] for r in new), 'full': Counter(r['status'] for r in current), 'individual_attempts': len(attempts), 'nonzero_individual_attempts': len(failed_attempts), 'mapped_cases': len(rows), 'original_test_hashes_verified': len(integrity['existing_test_integrity'])}, indent=2))


if __name__ == '__main__':
    main()

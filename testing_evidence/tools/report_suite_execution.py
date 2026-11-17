"""Summarize already-executed suites; never modifies tests or application files."""
from collections import Counter, defaultdict
import csv
import hashlib
import json
from pathlib import Path
import socket
import subprocess

from build_report import flutter_results, python_results
from run_qa import ROOT, EVIDENCE, capture, stamp

LABEL = 'suite_20261116_run2'

# Concise coverage plus concrete work still needed for each original scenario.
MAPPING = [
('fyp_functional_gaps_test.dart: valid signup form submission', 'Live Firebase account/profile creation and destination routing.'),
('fyp_functional_gaps_test.dart: all four empty signup errors; no submission', 'Local validation passed; confirm layout on Android for device acceptance.'),
('fyp_functional_gaps_test.dart: controller handles fake email-already-in-use', 'Real existing-email rejection and unchanged Auth user count in test Firebase.'),
('fyp_functional_gaps_test.dart: valid login form submission; test_auth.py: mocked token claims', 'Live credential authentication and complete/incomplete profile routing.'),
('fyp_functional_gaps_test.dart: controller handles fake wrong-password', 'Real Firebase wrong-password response, signed-out state, no navigation.'),
('fyp_functional_gaps_test.dart: empty email/password errors; no submission', 'Local validation passed; confirm layout on Android for device acceptance.'),
('profile_validation_test.dart; test_pipeline_api.py: fake twin pipeline and temporary artifacts', 'Real model processing, photo upload, Firebase metrics/style/twin persistence.'),
('fyp_functional_gaps_test.dart: missing photo and empty height; profile_validation_test.dart', 'Local negative scope passed; add missing weight/style submission variants and Android confirmation.'),
('test_list_endpoints.py: owned twins, newest-first, authorization; ai_service_test.dart: timeout/recovery', 'Reopen saved twin on device, Firebase photo fallback, real account ownership.'),
('test_wardrobe_api.py: processing/persistence; wardrobe_recovery_test.dart: gallery link recovery', 'Actual gallery selection, processed image upload to Firebase, closet refresh.'),
('No direct automated camera capture assertion', 'Device camera permission, capture, accept, processing and closet persistence.'),
('No direct clothing-picker cancellation assertion', 'Mock or device gallery/camera cancellation; assert no API/Firestore/Storage writes.'),
('test_wardrobe_api.py: category/style assignment and invalid categories; test_fyp_functional_gaps.py: missing category', 'Category-first mobile selection and persisted matching Firebase/backend category.'),
('No automated change-category flow', 'Clarify saved-item editing versus choosing a different category before upload; saved category edit is absent.'),
('No direct category-sheet cancellation assertion', 'Dismiss category sheet and assert no uploads/documents; use widget or device test.'),
('test_tryon_api.py; test_generation_modes.py; test_max_quality.py; generation_confirmation_test.dart (6 shared failures)', 'Confirmation requirement resolution; real generated image, identity/clothes quality, device display.'),
('generation_confirmation_test.dart: fixed garment list forwarded once (passes)', 'Change A to B in UI; assert final IDs only and zero premature generation requests.'),
('test_tryon_api.py::test_unknown_twin_is_404', 'VTON screen with no twin: setup guidance, disabled Generate, zero provider requests.'),
('outfit_draft_test.dart: injected persist callback; test_tryon_api.py: temporary result store', 'Real likedOutfits document/image save and reopen in My Outfits.'),
('No save-cancel operation asserted; current Save is immediate', 'Clarify leave-unsaved interpretation; verify no likedOutfits write. Backend result already persists.'),
('outfit_draft_test.dart: repeated/concurrent save invokes persist once', 'Real per-draft Storage/document count; do not infer cross-session duplicate prevention.'),
('generation_confirmation_test.dart: mock multipart upload; test_inspo_api.py: fake generated result', 'Device preview and upload on confirmed Generate; there is no standalone upload request.'),
('test_fyp_functional_gaps.py: SVG -> 400, no provider call/save; test_inspo_api.py: malformed input', 'Actual picker format exclusion/error; distinguish extension from decodable file content.'),
('fyp_functional_gaps_test.dart: mocked null picker retains empty selection, no generation', 'Actual Android cancellation and cancellation after an existing reference is selected.'),
('test_inspo_api.py; test_fashn_api.py: fake result/identity prompt; test_max_quality.py', 'Real style/identity fidelity and final on-device image; shared confirmation failures remain.'),
('inspo_mirror_screen_test.dart: fake empty-twin guidance/disabled button; test_fyp_functional_gaps.py: absent twin -> 404', 'No-twin account with a selected reference on device; zero real provider requests.'),
('test_fyp_functional_gaps.py: tiny -> 400; valid-size blank -> 201 with fake provider call', 'Define semantic suitability acceptance; real non-person/unclear-image provider behavior. Characterization PASS does not mean unsuitable images are rejected.'),
('notification_service_test.dart: mocked timezone/permission/alarm payloads; outfit_plan_test.dart', 'Real Firestore save and Android reminder delivery at chosen local time.'),
('No direct date-picker change assertion', 'Select D then D+1 before confirmation and verify final date only; moving an existing plan is a separate unsupported action.'),
('No direct scheduling-cancel assertion', 'Cancel date/time/item selection independently; verify no plan/alarm creation.'),
('outfit_plan_test.dart: upcoming/expiry/gallery mapping; outfit_preview_test.dart: item previews', 'Real plan stream, correct dated card/items and past-plan gallery behavior.'),
('Unit empty-preview/invalid-date checks are related but do not test a selected-day empty state', 'Clarify empty Upcoming Outfits list as replacement; current planner has no daily-date viewer.'),
('No daily calendar navigation assertion or control', 'Clarify multiple dated cards/My Outfits browsing as replacement; verify date-item association.'),
('test_tryon_api.py: fake output; outfit_preview_test.dart: preview components', 'Display/reopen real generated result on twin; clarify if saved/planned outfit application is intended.'),
('No-twin generation guards in test_tryon_api.py and inspo_mirror_screen_test.dart', 'Virtual Twin empty state and navigation on device; distinguish independent saved-image viewing.'),
('fyp_functional_gaps_test.dart: missing URL icon/detail fallback; test_tryon_api.py: missing garment -> 404', 'Full viewer with missing remote object/document and offline failure; assert safe fallback/navigation.'),
]


def main():
    records = flutter_results(LABEL) + python_results(LABEL)
    cases = json.loads((EVIDENCE / 'reports/test_cases.json').read_text(encoding='utf-8'))
    assert len(cases) == len(MAPPING) == 36
    adb = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
    if adb.exists():
        capture(f'integration/{LABEL}_devices.log', [str(adb), 'devices', '-l'], ROOT, 30)
    ports = {}
    for port in (4000, 4400, 8000, 8002, 8080, 9099, 9199):
        with socket.socket() as sock:
            sock.settimeout(.3)
            ports[str(port)] = sock.connect_ex(('127.0.0.1', port)) == 0
    tracked_changes = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD'], cwd=ROOT, text=True).splitlines()
    assert not tracked_changes, tracked_changes
    summary = {'generated_at': stamp(), 'label': LABEL, 'tracked_application_or_test_changes': tracked_changes,
               'localhost_ports_open_at_followup_probe': ports, 'suites': {}, 'functional_statuses': dict(Counter(c['status'] for c in cases)),
               'results': records, 'coverage': []}
    for framework, folder in [('Flutter', 'flutter'), ('pytest', 'fastapi')]:
        rows = [r for r in records if r['framework'] == framework]
        meta = json.loads((EVIDENCE / f'logs/{folder}/{LABEL}.log.meta.json').read_text())
        summary['suites'][framework] = {'outcomes': dict(Counter(r['status'] for r in rows)), 'metadata': meta,
                                       'total': len(rows), 'blocked': 0, 'collection_errors': 0}
    for case, (coverage, remaining) in zip(cases, MAPPING):
        selectors = list(case['selectors'])
        if case['id'] == 'TC-016':
            selectors += ['cost confirmation remains usable', 'Inspo confirms exactly']
        if case['id'] == 'TC-025':
            selectors += ['Inspo confirms exactly']
        matches = [r for r in records if any(s in r['name'] for s in selectors)]
        summary['coverage'].append({'id': case['id'], 'scenario': case['scenario'], 'functional_status': case['status'],
                                    'existing_coverage': coverage, 'remaining_testing': remaining,
                                    'executed_related_checks': matches})
    summary_path = EVIDENCE / f'logs/integration/{LABEL}_summary.json'
    summary_path.write_text(json.dumps(summary, indent=2), encoding='utf-8')
    csv_path = EVIDENCE / f'reports/{LABEL}_coverage.csv'
    fields = ['id', 'scenario', 'functional_status', 'existing_coverage', 'remaining_testing']
    with csv_path.open('w', newline='', encoding='utf-8-sig') as file:
        writer = csv.DictWriter(file, fieldnames=fields)
        writer.writeheader()
        writer.writerows({k: row[k] for k in fields} for row in summary['coverage'])
    failures = [r for r in records if r['status'] == 'FAIL']
    failure_lines = '\n'.join(f"- `{r['name']}`" for r in failures)
    mapping = '\n'.join(f"| {row['id']} | {row['scenario']} | {row['existing_coverage']} | {row['functional_status']} | {row['remaining_testing']} |" for row in summary['coverage'])
    by_file = defaultdict(Counter)
    for row in records:
        by_file[row['name'].split('::')[0]][row['status']] += 1
    inventory = '\n'.join(f"| `{name}` | {count['PASS']} | {count['FAIL']} | {count['SKIP']} |" for name, count in sorted(by_file.items()))
    report = f'''# StyleSync current suite execution and functional coverage

Executed **16 November 2026, 22:29:26–22:29:46 (Asia/Kuala_Lumpur)**. This is a new full-suite run, not a reuse of historical results. No application functionality, dependencies, configuration, security rules or test source was modified. The current suites include the 17 FYP gap checks already present before this request; no tests were added this turn.

| Suite | Total | Passed | Failed | Skipped | Blocked during suite execution | Collection errors | Test exit code |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Flutter | 73 | 67 | 6 | 0 | 0 | 0 | 1 |
| FastAPI / pytest | 149 | 149 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **222** | **216** | **6** | **0** | **0** | **0** | — |

The original pre-FYP files account for Flutter 56 passed/6 failed and FastAPI 143 passed; the already-present FYP files contribute another 11 Flutter and 6 FastAPI passes. One Flutter pass is the existing `Placeholder test` (1 + 1 = 2), which supplies no functional coverage. Assertion pass percentage is 216/222 = **97.30%**; it is not an end-to-end application acceptance percentage.

## Complete terminal logs and commands

- [Flutter full stdout/stderr](../logs/flutter/{LABEL}.log), [structured JSONL](../logs/flutter/{LABEL}.jsonl), [command/working-directory/times/exit metadata](../logs/flutter/{LABEL}.log.meta.json).
- [FastAPI full stdout/stderr](../logs/fastapi/{LABEL}.log), [JUnit XML](../logs/fastapi/{LABEL}.xml), [command/working-directory/times/exit metadata](../logs/fastapi/{LABEL}.log.meta.json).
- [Fresh per-test outcomes, case mapping, device/port probe and summary](../logs/integration/{LABEL}_summary.json).
- [Spreadsheet-compatible coverage table]({LABEL}_coverage.csv).

Flutter was run from `apps/mobile_app` with `flutter test --no-pub --reporter expanded --file-reporter json:<evidence path>`. Python was run from `apps/ai_service` using its `.venv/Scripts/python.exe -m pytest -vv -ra --tb=short -p no:cacheprovider --junitxml=<evidence path>` and existing `pytest.ini`. Native structured results determine counts; loading/setup/teardown records are excluded. The log-capture wrapper itself exits zero after recording a failing child; the **actual Flutter test exit is 1**, as stored in metadata.

## Errors and their causes

All six failures are in `generation_confirmation_test.dart`:

{failure_lines}

Each failed at its first expected-title assertion: the test expected `Generate for 3/6/9/24 credits?`, but zero matching widgets were found. Current `lib/widgets/generation_confirmation.dart` renders `Generate outfit?` and a generic `Generate` button. Its source also omits the expected credit-bearing action label and earlier-steps credit notice; assertions after the first failure did not execute. This is a confirmed mismatch between the existing test contract and UI. It affects confidence in cost confirmation for TC-016/025; it does not establish that real AI generation failed. No assertion or widget was changed.

FastAPI emitted **one StarletteDeprecationWarning**: installed Starlette TestClient deprecates its HTTPX integration and suggests HTTPX2. This is a dependency warning; all 149 tests passed. No packages were installed or changed. No collection errors, missing dependencies, timeouts or test skips were observed.

## Existing coverage mapped to all 36 functional cases

“Coverage” below describes executed component checks, including fakes/mocks. “Functional status” describes completion of the original mobile scenario, not a pytest/Flutter assertion count. PASS is limited to three local negative-validation scenarios (TC-002/006/008). BLOCKED means full scenario acceptance remains outstanding. NOT RUN marks four interactions requiring clarification/revised interpretation because the literal UI action is unavailable. Test names/results for each row appear in the summary JSON, including supplemental shared-widget failures.

| ID | Functional scenario | Existing automated coverage | Functional status | Manual or additional automated testing still required |
| --- | --- | --- | --- | --- |
{mapping}

## Remaining testing and blockers

The 36-case matrix remains **3 local PASS, 0 scenario FAIL, 29 BLOCKED, 4 NOT RUN**. Six test assertion failures are reported separately above; they are not silently relabeled as failures of unexecuted end-to-end generation. Required-scenario local pass percentage is 3/36 = **8.33%**. No complete Android/Firebase/real-AI workflow has been certified.

Live Auth/Firestore/Storage persistence requires an approved isolated test environment and test accounts. Real AI quality requires the running model/extraction services and an approved hosted key/credit budget. Picker/camera permissions and notification delivery require Android interaction. The follow-up [device probe](../logs/integration/{LABEL}_devices.log) and localhost ports are in the fresh summary JSON. At probe time, the device list was empty and common AI/worker/Firebase ports 8000/8002/4000/4400/8080/9099/9199 were closed. This does not exclude custom remote services. No production service was used to mutate data.

The highest-priority isolated additions would exercise TC-012/015 picker/category cancellation, TC-017 changed garment selection, TC-018 VTON empty-twin UI, TC-029 date changes, TC-030 all scheduling cancellation points, and TC-036 remote-image failure. Integration/manual acceptance remains needed for TC-001/003/004/005/007/009/010/011/013/016/019/021/022/023/024/025/026/027/028/031/034/035/036. TC-014/020/032/033 require an agreed interpretation before acceptance; no functionality was added to fill these gaps. TC-002/006/008 passed locally but still benefit from on-device confirmation; TC-008 should gain explicit missing-weight/style submit variants.

Use the existing [Manual Testing Guide](Manual_Testing_Guide.md) for case-specific steps, data, screenshot filenames and supporting Firebase/FastAPI evidence. It contains planned procedures, not executed Android results. Mocked provider output and mocked Firebase errors do not prove real service integration. Existing tests may recapture their three widget PNGs as an execution side effect; no new device screenshots were fabricated.

## Per-file executed counts

| Test file | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
{inventory}
'''
    report_path = EVIDENCE / f'reports/{LABEL}_Results.md'
    report_path.write_text(report, encoding='utf-8')
    # A fresh manifest for this execution leaves the historical manifest intact.
    paths = [report_path, csv_path, summary_path]
    for folder, suffixes in [('flutter', ['log', 'jsonl', 'log.meta.json']), ('fastapi', ['log', 'xml', 'log.meta.json'])]:
        paths.extend(EVIDENCE / f'logs/{folder}/{LABEL}.{suffix}' for suffix in suffixes)
    paths.extend([EVIDENCE / f'logs/integration/{LABEL}_devices.log', EVIDENCE / f'logs/integration/{LABEL}_devices.log.meta.json'])
    manifest = [{'path': p.relative_to(EVIDENCE).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]
    (EVIDENCE / f'reports/{LABEL}_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    assert len(records) == 222
    assert Counter(r['status'] for r in records) == {'PASS': 216, 'FAIL': 6}
    print(json.dumps({'suites': {name: value['outcomes'] for name, value in summary['suites'].items()},
                      'functional_cases': summary['functional_statuses'], 'report': str(report_path)}, indent=2))


if __name__ == '__main__':
    main()

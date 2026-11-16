# Unit and regression test results

Executed 16 November 2026, 23:23:34-23:23:58 Asia/Kuala_Lumpur (UTC+08:00).
Revision: `9a4d157c7c5d547812cb0a1f1307a0b1bda74cde`. Existing cached dependencies were used.

**Result: 268 passed, 6 failed, 0 skipped across 274 tests.** The full Flutter, backend and worker suites were executed once. This includes existing unit, widget, API/component and mocked workflow regression checks; these categories overlap and are not additional test runs.

| Suite | Passed | Failed | Skipped | Exit code |
| --- | ---: | ---: | ---: | ---: |
| flutter | 104 | 6 | 0 | 1 |
| backend | 151 | 0 | 0 | 0 |
| worker | 13 | 0 | 0 | 0 |

## Failures

All six failures occur in `apps/mobile_app/test/generation_confirmation_test.dart`. Each assertion expects a credit total in the dialog title, but finds zero matching widgets. The implementation in `apps/mobile_app/lib/widgets/generation_confirmation.dart` displays `Generate outfit?` and a plain `Generate` button; it does not display the calculated credit total.

| Test | Expected title | Source assertion |
| --- | --- | --- |
| VTON shows the total and cancellation declines generation | Generate for 9 credits? | generation_confirmation_test.dart:42 |
| Inspo confirms exactly one three-credit generation | Generate for 3 credits? | generation_confirmation_test.dart:76 |
| cost confirmation remains usable in landscape | Generate for 24 credits? | generation_confirmation_test.dart:118 |
| Fast confirmation shows its own total | Generate for 3 credits? | generation_confirmation_test.dart:203 |
| Balanced confirmation shows its own total | Generate for 6 credits? | generation_confirmation_test.dart:203 |
| Quality confirmation shows its own total | Generate for 9 credits? | generation_confirmation_test.dart:203 |

These six failure names match the earlier [suite execution](../../reports/suite_20261116_run2_Results.md) and its native JSONL results. No additional failing test names were observed against that historical run. This comparison does not establish that the earlier run used identical source or coverage. Cancellation, approval and landscape usability assertions later in these six tests are not reached after the first failure.

## Coverage and limits

The run exercises authentication/profile validation, password reset, wardrobe upload/cancellation/category selection, twin workflows, try-on and inspiration request/confirmation behavior, outfit persistence/preview, planner dates/cancellation/reminders, image/pose/mask handling, API validation/ownership, provider payloads, and garment extraction/skirt retry behavior.

Firebase, image pickers, notification channels, provider HTTP and model engines are faked where applicable. No Android device interaction, real Firebase persistence, reminder delivery or live AI visual quality was executed. The manual/integration procedures in [Functional_Gap_Manual_Guide.md](../../reports/Functional_Gap_Manual_Guide.md) remain unexecuted by this run. A single passing Flutter `Placeholder test` checks `1 + 1 == 2` and supplies no functional coverage.

Both Python suites emit one Starlette deprecation warning about TestClient's use of HTTPX. These warnings do not fail the suites. The worker tests ran using the existing backend virtual environment because the worker has no installed virtual environment; mocked worker logic was tested without downloading models.

## Evidence and reproduction

[Machine-readable results](results.json) include every test outcome, failure details, commands, working directories, timestamps and exit codes. [SHA-256 manifest](manifest.json) records the artifacts.

- flutter: [terminal log](flutter.log), [native results](flutter.jsonl), [execution metadata](flutter.meta.json).
- backend: [terminal log](backend.log), [native results](backend.xml), [execution metadata](backend.meta.json).
- worker: [terminal log](worker.log), [native results](worker.xml), [execution metadata](worker.meta.json).

Commands were executed from each application's directory:

```powershell
# C:\Users\User\styleSync-app\apps\mobile_app
flutter test --no-pub --reporter expanded --file-reporter 'json:C:\Users\User\styleSync-app\testing_evidence\runs\regression_unit_20261116_232321\flutter.jsonl'
# C:\Users\User\styleSync-app\apps\ai_service
.\.venv\Scripts\python.exe -m pytest -vv -ra --tb=short -p no:cacheprovider --junitxml='C:\Users\User\styleSync-app\testing_evidence\runs\regression_unit_20261116_232321\backend.xml'
# C:\Users\User\styleSync-app\apps\fashn_vton_worker
..\ai_service\.venv\Scripts\python.exe -m pytest test_worker_extraction.py -vv -ra --tb=short -p no:cacheprovider --junitxml='C:\Users\User\styleSync-app\testing_evidence\runs\regression_unit_20261116_232321\worker.xml'
```

Existing tests regenerated three widget screenshots. New captures are preserved under `widget_screenshots/`; original images were backed up under `original_widget_screenshots/` and restored to their original paths. No application code, test source, dependencies or configuration was changed. The tracked diff after restoration is empty.

## Per-file outcomes

| Suite | File/class | Passed | Failed | Skipped |
| --- | --- | ---: | ---: | ---: |
| backend | tests.test_auth | 5 | 0 | 0 |
| backend | tests.test_enhance_quality | 5 | 0 | 0 |
| backend | tests.test_fashn_api | 9 | 0 | 0 |
| backend | tests.test_fyp_functional_gaps | 6 | 0 | 0 |
| backend | tests.test_fyp_workflow_gaps | 2 | 0 | 0 |
| backend | tests.test_garment_extraction | 6 | 0 | 0 |
| backend | tests.test_generation_modes | 21 | 0 | 0 |
| backend | tests.test_hijab_mediapipe | 5 | 0 | 0 |
| backend | tests.test_imaging | 1 | 0 | 0 |
| backend | tests.test_inspo_api | 6 | 0 | 0 |
| backend | tests.test_list_endpoints | 7 | 0 | 0 |
| backend | tests.test_max_quality | 10 | 0 | 0 |
| backend | tests.test_pipeline_api | 12 | 0 | 0 |
| backend | tests.test_pose | 8 | 0 | 0 |
| backend | tests.test_tryon_api | 23 | 0 | 0 |
| backend | tests.test_tryon_crop | 3 | 0 | 0 |
| backend | tests.test_tryon_engine_selection | 3 | 0 | 0 |
| backend | tests.test_tryon_mask | 4 | 0 | 0 |
| backend | tests.test_wardrobe_api | 15 | 0 | 0 |
| flutter | ai_service_test.dart | 7 | 0 | 0 |
| flutter | form_state_test.dart | 3 | 0 | 0 |
| flutter | fyp_auth_workflow_test.dart | 9 | 0 | 0 |
| flutter | fyp_functional_gaps_test.dart | 11 | 0 | 0 |
| flutter | fyp_inspo_workflow_test.dart | 5 | 0 | 0 |
| flutter | fyp_planner_workflow_test.dart | 7 | 0 | 0 |
| flutter | fyp_tryon_workflow_test.dart | 5 | 0 | 0 |
| flutter | fyp_twin_workflow_test.dart | 5 | 0 | 0 |
| flutter | fyp_wardrobe_workflow_test.dart | 6 | 0 | 0 |
| flutter | generation_confirmation_test.dart | 7 | 6 | 0 |
| flutter | inspo_mirror_screen_test.dart | 2 | 0 | 0 |
| flutter | notification_service_test.dart | 4 | 0 | 0 |
| flutter | outfit_draft_test.dart | 4 | 0 | 0 |
| flutter | outfit_plan_test.dart | 8 | 0 | 0 |
| flutter | outfit_preview_test.dart | 4 | 0 | 0 |
| flutter | password_reset_test.dart | 2 | 0 | 0 |
| flutter | profile_validation_test.dart | 11 | 0 | 0 |
| flutter | wardrobe_recovery_test.dart | 3 | 0 | 0 |
| flutter | widget_test.dart | 1 | 0 | 0 |
| worker | test_worker_extraction | 13 | 0 | 0 |

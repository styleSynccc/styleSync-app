# StyleSync current suite execution and functional coverage

Executed **16 November 2026, 22:29:26–22:29:46 (Asia/Kuala_Lumpur)**. This is a new full-suite run, not a reuse of historical results. No application functionality, dependencies, configuration, security rules or test source was modified. The current suites include the 17 FYP gap checks already present before this request; no tests were added this turn.

| Suite | Total | Passed | Failed | Skipped | Blocked during suite execution | Collection errors | Test exit code |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Flutter | 73 | 67 | 6 | 0 | 0 | 0 | 1 |
| FastAPI / pytest | 149 | 149 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **222** | **216** | **6** | **0** | **0** | **0** | — |

The original pre-FYP files account for Flutter 56 passed/6 failed and FastAPI 143 passed; the already-present FYP files contribute another 11 Flutter and 6 FastAPI passes. One Flutter pass is the existing `Placeholder test` (1 + 1 = 2), which supplies no functional coverage. Assertion pass percentage is 216/222 = **97.30%**; it is not an end-to-end application acceptance percentage.

## Complete terminal logs and commands

- [Flutter full stdout/stderr](../logs/flutter/suite_20261116_run2.log), [structured JSONL](../logs/flutter/suite_20261116_run2.jsonl), [command/working-directory/times/exit metadata](../logs/flutter/suite_20261116_run2.log.meta.json).
- [FastAPI full stdout/stderr](../logs/fastapi/suite_20261116_run2.log), [JUnit XML](../logs/fastapi/suite_20261116_run2.xml), [command/working-directory/times/exit metadata](../logs/fastapi/suite_20261116_run2.log.meta.json).
- [Fresh per-test outcomes, case mapping, device/port probe and summary](../logs/integration/suite_20261116_run2_summary.json).
- [Spreadsheet-compatible coverage table](suite_20261116_run2_coverage.csv).

Flutter was run from `apps/mobile_app` with `flutter test --no-pub --reporter expanded --file-reporter json:<evidence path>`. Python was run from `apps/ai_service` using its `.venv/Scripts/python.exe -m pytest -vv -ra --tb=short -p no:cacheprovider --junitxml=<evidence path>` and existing `pytest.ini`. Native structured results determine counts; loading/setup/teardown records are excluded. The log-capture wrapper itself exits zero after recording a failing child; the **actual Flutter test exit is 1**, as stored in metadata.

## Errors and their causes

All six failures are in `generation_confirmation_test.dart`:

- `generation_confirmation_test.dart::VTON shows the total and cancellation declines generation`
- `generation_confirmation_test.dart::Inspo confirms exactly one three-credit generation`
- `generation_confirmation_test.dart::cost confirmation remains usable in landscape`
- `generation_confirmation_test.dart::Fast confirmation shows its own total`
- `generation_confirmation_test.dart::Balanced confirmation shows its own total`
- `generation_confirmation_test.dart::Quality confirmation shows its own total`

Each failed at its first expected-title assertion: the test expected `Generate for 3/6/9/24 credits?`, but zero matching widgets were found. Current `lib/widgets/generation_confirmation.dart` renders `Generate outfit?` and a generic `Generate` button. Its source also omits the expected credit-bearing action label and earlier-steps credit notice; assertions after the first failure did not execute. This is a confirmed mismatch between the existing test contract and UI. It affects confidence in cost confirmation for TC-016/025; it does not establish that real AI generation failed. No assertion or widget was changed.

FastAPI emitted **one StarletteDeprecationWarning**: installed Starlette TestClient deprecates its HTTPX integration and suggests HTTPX2. This is a dependency warning; all 149 tests passed. No packages were installed or changed. No collection errors, missing dependencies, timeouts or test skips were observed.

## Existing coverage mapped to all 36 functional cases

“Coverage” below describes executed component checks, including fakes/mocks. “Functional status” describes completion of the original mobile scenario, not a pytest/Flutter assertion count. PASS is limited to three local negative-validation scenarios (TC-002/006/008). BLOCKED means full scenario acceptance remains outstanding. NOT RUN marks four interactions requiring clarification/revised interpretation because the literal UI action is unavailable. Test names/results for each row appear in the summary JSON, including supplemental shared-widget failures.

| ID | Functional scenario | Existing automated coverage | Functional status | Manual or additional automated testing still required |
| --- | --- | --- | --- | --- |
| TC-001 | Register with valid details | fyp_functional_gaps_test.dart: valid signup form submission | BLOCKED | Live Firebase account/profile creation and destination routing. |
| TC-002 | Submit empty required fields | fyp_functional_gaps_test.dart: all four empty signup errors; no submission | PASS | Local validation passed; confirm layout on Android for device acceptance. |
| TC-003 | Register using an existing email | fyp_functional_gaps_test.dart: controller handles fake email-already-in-use | BLOCKED | Real existing-email rejection and unchanged Auth user count in test Firebase. |
| TC-004 | Login using valid credentials | fyp_functional_gaps_test.dart: valid login form submission; test_auth.py: mocked token claims | BLOCKED | Live credential authentication and complete/incomplete profile routing. |
| TC-005 | Login using incorrect password | fyp_functional_gaps_test.dart: controller handles fake wrong-password | BLOCKED | Real Firebase wrong-password response, signed-out state, no navigation. |
| TC-006 | Login using empty fields | fyp_functional_gaps_test.dart: empty email/password errors; no submission | PASS | Local validation passed; confirm layout on Android for device acceptance. |
| TC-007 | Create Digital Twin with valid body details | profile_validation_test.dart; test_pipeline_api.py: fake twin pipeline and temporary artifacts | BLOCKED | Real model processing, photo upload, Firebase metrics/style/twin persistence. |
| TC-008 | Submit incomplete body details | fyp_functional_gaps_test.dart: missing photo and empty height; profile_validation_test.dart | PASS | Local negative scope passed; add missing weight/style submission variants and Android confirmation. |
| TC-009 | Retrieve saved Digital Twin | test_list_endpoints.py: owned twins, newest-first, authorization; ai_service_test.dart: timeout/recovery | BLOCKED | Reopen saved twin on device, Firebase photo fallback, real account ownership. |
| TC-010 | Upload clothing image from gallery | test_wardrobe_api.py: processing/persistence; wardrobe_recovery_test.dart: gallery link recovery | BLOCKED | Actual gallery selection, processed image upload to Firebase, closet refresh. |
| TC-011 | Capture clothing image using camera | No direct automated camera capture assertion | BLOCKED | Device camera permission, capture, accept, processing and closet persistence. |
| TC-012 | Cancel clothing image selection | No direct clothing-picker cancellation assertion | BLOCKED | Mock or device gallery/camera cancellation; assert no API/Firestore/Storage writes. |
| TC-013 | Assign clothing category | test_wardrobe_api.py: category/style assignment and invalid categories; test_fyp_functional_gaps.py: missing category | BLOCKED | Category-first mobile selection and persisted matching Firebase/backend category. |
| TC-014 | Change clothing category | No automated change-category flow | NOT RUN | Clarify saved-item editing versus choosing a different category before upload; saved category edit is absent. |
| TC-015 | Cancel categorization | No direct category-sheet cancellation assertion | BLOCKED | Dismiss category sheet and assert no uploads/documents; use widget or device test. |
| TC-016 | Generate Virtual Try-On image | test_tryon_api.py; test_generation_modes.py; test_max_quality.py; generation_confirmation_test.dart (6 shared failures) | BLOCKED | Confirmation requirement resolution; real generated image, identity/clothes quality, device display. |
| TC-017 | Change clothing selection before generation | generation_confirmation_test.dart: fixed garment list forwarded once (passes) | BLOCKED | Change A to B in UI; assert final IDs only and zero premature generation requests. |
| TC-018 | Attempt Virtual Try-On without Digital Twin | test_tryon_api.py::test_unknown_twin_is_404 | BLOCKED | VTON screen with no twin: setup guidance, disabled Generate, zero provider requests. |
| TC-019 | Save generated outfit | outfit_draft_test.dart: injected persist callback; test_tryon_api.py: temporary result store | BLOCKED | Real likedOutfits document/image save and reopen in My Outfits. |
| TC-020 | Cancel saving | No save-cancel operation asserted; current Save is immediate | NOT RUN | Clarify leave-unsaved interpretation; verify no likedOutfits write. Backend result already persists. |
| TC-021 | Save an already saved outfit | outfit_draft_test.dart: repeated/concurrent save invokes persist once | BLOCKED | Real per-draft Storage/document count; do not infer cross-session duplicate prevention. |
| TC-022 | Upload valid inspiration image | generation_confirmation_test.dart: mock multipart upload; test_inspo_api.py: fake generated result | BLOCKED | Device preview and upload on confirmed Generate; there is no standalone upload request. |
| TC-023 | Upload unsupported image format | test_fyp_functional_gaps.py: SVG -> 400, no provider call/save; test_inspo_api.py: malformed input | BLOCKED | Actual picker format exclusion/error; distinguish extension from decodable file content. |
| TC-024 | Cancel image selection | fyp_functional_gaps_test.dart: mocked null picker retains empty selection, no generation | BLOCKED | Actual Android cancellation and cancellation after an existing reference is selected. |
| TC-025 | Apply inspiration style to Digital Twin | test_inspo_api.py; test_fashn_api.py: fake result/identity prompt; test_max_quality.py | BLOCKED | Real style/identity fidelity and final on-device image; shared confirmation failures remain. |
| TC-026 | Apply style without Digital Twin | inspo_mirror_screen_test.dart: fake empty-twin guidance/disabled button; test_fyp_functional_gaps.py: absent twin -> 404 | BLOCKED | No-twin account with a selected reference on device; zero real provider requests. |
| TC-027 | Process an unsuitable inspiration image | test_fyp_functional_gaps.py: tiny -> 400; valid-size blank -> 201 with fake provider call | BLOCKED | Define semantic suitability acceptance; real non-person/unclear-image provider behavior. Characterization PASS does not mean unsuitable images are rejected. |
| TC-028 | Schedule outfit for selected date | notification_service_test.dart: mocked timezone/permission/alarm payloads; outfit_plan_test.dart | BLOCKED | Real Firestore save and Android reminder delivery at chosen local time. |
| TC-029 | Change selected date | No direct date-picker change assertion | BLOCKED | Select D then D+1 before confirmation and verify final date only; moving an existing plan is a separate unsupported action. |
| TC-030 | Cancel outfit scheduling | No direct scheduling-cancel assertion | BLOCKED | Cancel date/time/item selection independently; verify no plan/alarm creation. |
| TC-031 | View scheduled outfit | outfit_plan_test.dart: upcoming/expiry/gallery mapping; outfit_preview_test.dart: item previews | BLOCKED | Real plan stream, correct dated card/items and past-plan gallery behavior. |
| TC-032 | View date with no scheduled outfit | Unit empty-preview/invalid-date checks are related but do not test a selected-day empty state | NOT RUN | Clarify empty Upcoming Outfits list as replacement; current planner has no daily-date viewer. |
| TC-033 | Switch between planned dates | No daily calendar navigation assertion or control | NOT RUN | Clarify multiple dated cards/My Outfits browsing as replacement; verify date-item association. |
| TC-034 | Display outfit on Digital Twin | test_tryon_api.py: fake output; outfit_preview_test.dart: preview components | BLOCKED | Display/reopen real generated result on twin; clarify if saved/planned outfit application is intended. |
| TC-035 | Display outfit without Digital Twin | No-twin generation guards in test_tryon_api.py and inspo_mirror_screen_test.dart | BLOCKED | Virtual Twin empty state and navigation on device; distinguish independent saved-image viewing. |
| TC-036 | Display unavailable outfit | fyp_functional_gaps_test.dart: missing URL icon/detail fallback; test_tryon_api.py: missing garment -> 404 | BLOCKED | Full viewer with missing remote object/document and offline failure; assert safe fallback/navigation. |

## Remaining testing and blockers

The 36-case matrix remains **3 local PASS, 0 scenario FAIL, 29 BLOCKED, 4 NOT RUN**. Six test assertion failures are reported separately above; they are not silently relabeled as failures of unexecuted end-to-end generation. Required-scenario local pass percentage is 3/36 = **8.33%**. No complete Android/Firebase/real-AI workflow has been certified.

Live Auth/Firestore/Storage persistence requires an approved isolated test environment and test accounts. Real AI quality requires the running model/extraction services and an approved hosted key/credit budget. Picker/camera permissions and notification delivery require Android interaction. The follow-up [device probe](../logs/integration/suite_20261116_run2_devices.log) and localhost ports are in the fresh summary JSON. At probe time, the device list was empty and common AI/worker/Firebase ports 8000/8002/4000/4400/8080/9099/9199 were closed. This does not exclude custom remote services. No production service was used to mutate data.

The highest-priority isolated additions would exercise TC-012/015 picker/category cancellation, TC-017 changed garment selection, TC-018 VTON empty-twin UI, TC-029 date changes, TC-030 all scheduling cancellation points, and TC-036 remote-image failure. Integration/manual acceptance remains needed for TC-001/003/004/005/007/009/010/011/013/016/019/021/022/023/024/025/026/027/028/031/034/035/036. TC-014/020/032/033 require an agreed interpretation before acceptance; no functionality was added to fill these gaps. TC-002/006/008 passed locally but still benefit from on-device confirmation; TC-008 should gain explicit missing-weight/style submit variants.

Use the existing [Manual Testing Guide](Manual_Testing_Guide.md) for case-specific steps, data, screenshot filenames and supporting Firebase/FastAPI evidence. It contains planned procedures, not executed Android results. Mocked provider output and mocked Firebase errors do not prove real service integration. Existing tests may recapture their three widget PNGs as an execution side effect; no new device screenshots were fabricated.

## Per-file executed counts

| Test file | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| `ai_service_test.dart` | 7 | 0 | 0 |
| `form_state_test.dart` | 3 | 0 | 0 |
| `fyp_functional_gaps_test.dart` | 11 | 0 | 0 |
| `generation_confirmation_test.dart` | 7 | 6 | 0 |
| `inspo_mirror_screen_test.dart` | 2 | 0 | 0 |
| `notification_service_test.dart` | 4 | 0 | 0 |
| `outfit_draft_test.dart` | 4 | 0 | 0 |
| `outfit_plan_test.dart` | 8 | 0 | 0 |
| `outfit_preview_test.dart` | 4 | 0 | 0 |
| `password_reset_test.dart` | 2 | 0 | 0 |
| `profile_validation_test.dart` | 11 | 0 | 0 |
| `tests/test_auth.py` | 5 | 0 | 0 |
| `tests/test_enhance_quality.py` | 5 | 0 | 0 |
| `tests/test_fashn_api.py` | 9 | 0 | 0 |
| `tests/test_fyp_functional_gaps.py` | 6 | 0 | 0 |
| `tests/test_garment_extraction.py` | 6 | 0 | 0 |
| `tests/test_generation_modes.py` | 21 | 0 | 0 |
| `tests/test_hijab_mediapipe.py` | 5 | 0 | 0 |
| `tests/test_imaging.py` | 1 | 0 | 0 |
| `tests/test_inspo_api.py` | 6 | 0 | 0 |
| `tests/test_list_endpoints.py` | 7 | 0 | 0 |
| `tests/test_max_quality.py` | 10 | 0 | 0 |
| `tests/test_pipeline_api.py` | 12 | 0 | 0 |
| `tests/test_pose.py` | 8 | 0 | 0 |
| `tests/test_tryon_api.py` | 23 | 0 | 0 |
| `tests/test_tryon_crop.py` | 3 | 0 | 0 |
| `tests/test_tryon_engine_selection.py` | 3 | 0 | 0 |
| `tests/test_tryon_mask.py` | 4 | 0 | 0 |
| `tests/test_wardrobe_api.py` | 15 | 0 | 0 |
| `wardrobe_recovery_test.dart` | 3 | 0 | 0 |
| `widget_test.dart` | 1 | 0 | 0 |

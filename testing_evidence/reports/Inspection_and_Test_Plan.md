# StyleSync inspection and test plan

Prepared 16 November 2026 (Asia/Kuala_Lumpur), before test execution.

## Scope and safeguards

Preserve all 12 existing Dart test files and 17 Python test modules plus conftest.py. Preserve the pre-existing untracked `apps/mobile_app/flutter_test_results.txt`; it is historical output, not evidence for this run. No AGENTS.md was found by the repository file search. Do not change application code, dependency manifests, Firebase configuration/rules, accounts, or production data. No live generation requests. Capture complete stdout/stderr, exit codes, timestamps, and structured results under `testing_evidence/logs`. Existing tests were read, including assertions and fixtures; the placeholder Dart test provides no functional coverage.

## Implementation inspected

- Flutter/GetX UI; Firebase Auth, Firestore, Storage; image_picker; local notifications; HTTP AI client. Firebase is initialized using configured project options; no emulator routing was found. `firebase.json` contains rules/configuration but no emulator block. Rules restrict user documents and Storage paths to their authenticated owner; rules have not been executed in an emulator.
- `AuthController` creates accounts and user documents, routes login based on profile completion, and exposes Firebase errors. Sign-up requires username, email, gender, and a password of at least six characters with uppercase and special characters.
- Twin setup requires a photo, finite positive height/weight, and at least one style. Backend `/v1/twins` processes the photo; body measurements remain in Firebase. Twin view uses processed backend image with Firebase photo fallback.
- Clothing category is selected before gallery/camera upload; upload processes through `/v1/wardrobe` then stores processed image and a Firestore clothes document. No edit-category operation was found.
- Try-on selects twin plus garments, quotes credits, sends `/v1/tryon`, displays returned image, and saves explicitly. Generation results are already persisted by the backend; explicit Save adds a Firebase `likedOutfits` entry. In-memory guards prevent duplicate saving of the same current draft.
- Inspo Mirror selects a gallery reference locally; upload occurs when Generate is confirmed. `/v1/inspo` checks decoding/resolution but has no local semantic suitability classifier.
- Planner selects date, reminder time, then closet items; writes one `outfitPlans/YYYY-MM-DD` document per date. Replanning the same date replaces that date's plan. UI is an upcoming list, with past plans in My Outfits. There is no daily calendar selector.
- My Outfits displays saved generated images or planner item collages. Virtual Twin displays the original processed twin. There is no separate operation to dress a twin with an arbitrary saved/planned outfit.
- Backend uses per-user filesystem stores; tests use `tmp_path`. AI engines are injected fakes; provider HTTP and Firebase verification are mocked. These are isolated API/component checks, not live Firebase/AI integration.

## Initial mapping of existing coverage

“Partial” means the named test exercises a component of the scenario, not the complete mobile use case. “None” means no direct assertion was found. Source references below are relative to the corresponding test directory.

| ID | Existing test(s) | Initial coverage / remaining requirement |
| --- | --- | --- |
| TC-001 | form_state_test.dart | Partial typed-state retention only; actual account creation absent |
| TC-002 | None | Empty sign-up validation missing |
| TC-003 | None | Existing-email rejection missing |
| TC-004 | form_state_test.dart; test_auth.py | Partial state retention/token claims; no credential login |
| TC-005 | None | Wrong-password rejection missing |
| TC-006 | None | Empty login validation missing |
| TC-007 | profile_validation_test.dart; form_state_test.dart; test_pipeline_api.py::test_happy_path_saves_all_artifacts | Partial metrics/state and fake photo pipeline; no Firebase profile persistence |
| TC-008 | profile_validation_test.dart; test_pipeline_api.py negative image/pose tests | Partial metric/image rejection; setup submit guard missing |
| TC-009 | test_list_endpoints.py::test_list_twins_newest_first and ownership tests | Partial temporary local retrieval; mobile/Firebase retrieval untested |
| TC-010 | test_wardrobe_api.py; wardrobe_recovery_test.dart | Partial processing/link recovery; OS gallery/Firebase untested |
| TC-011 | None | Camera/permissions require device |
| TC-012 | None | Picker cancellation missing |
| TC-013 | test_wardrobe_api.py::test_garment_item_saved_without_mask, category/style validation | Partial assignment through API; category-first mobile flow untested |
| TC-014 | None | Saved category editing not implemented; propose choose different category before upload |
| TC-015 | None | Dismiss category sheet before upload; no standalone categorization transaction |
| TC-016 | test_tryon_api.py composition/result tests; generation_confirmation_test.dart; test_generation_modes.py; test_max_quality.py | Partial mocked generation/quote/persistence; real AI result untested |
| TC-017 | generation_confirmation_test.dart request payload tests | Partial fixed selection payload only; changing selection UI untested |
| TC-018 | test_tryon_api.py::test_unknown_twin_is_404 | Partial API rejection; VTON empty-twin UI untested |
| TC-019 | outfit_draft_test.dart; test_tryon_api.py::test_result_is_persisted | Partial injected persist callback/local store; Firebase save untested |
| TC-020 | None | No save-cancel dialog; propose leave generated result unsaved |
| TC-021 | outfit_draft_test.dart double-tap test | Partial per-draft deduplication; Firebase duplicate count untested |
| TC-022 | generation_confirmation_test.dart multipart check; test_inspo_api.py::test_inspo_returns_and_persists_result | Partial payload and fake processing; gallery upload is deferred until Generate |
| TC-023 | test_inspo_api.py::test_inspo_validates_before_paid_generation | Partial undecodable bytes rejection; explicit unsupported format missing |
| TC-024 | None | Inspiration picker cancellation missing |
| TC-025 | test_inspo_api.py positive result; test_fashn_api.py payload test | Partial fake result/identity prompt; actual visual quality untested |
| TC-026 | inspo_mirror_screen_test.dart empty twin; test_inspo_api.py other-user twin | Partial fake UI/ownership; absent-twin API case missing |
| TC-027 | test_inspo_api.py invalid bytes; test_pipeline_api.py pose tests concern twin only | Partial malformed input; valid but unsuitable reference has no semantic check |
| TC-028 | notification_service_test.dart; outfit_plan_test.dart | Partial mock alarm payload/model; Firestore scheduling UI untested |
| TC-029 | None | Date picker selection change missing; no edit/move existing-plan action |
| TC-030 | None | Date/time/sheet cancellation missing |
| TC-031 | outfit_plan_test.dart future/legacy plan; outfit_preview_test.dart | Partial model/preview; running upcoming list untested |
| TC-032 | outfit_preview_test.dart empty items; outfit_plan_test.dart invalid dates | Partial different empty states; no daily-date UI exists |
| TC-033 | None | No calendar switching; propose inspect multiple dated cards/My Outfits pages |
| TC-034 | test_tryon_api.py fake result; outfit_preview_test.dart planner collage | Partial generation response/preview only; separate saved outfit-to-twin operation absent |
| TC-035 | inspo_mirror_screen_test.dart empty twin; test_tryon_api.py unknown twin | Partial generation guards; saved result viewing does not require a current twin |
| TC-036 | test_tryon_api.py::test_unknown_garment_is_404; outfit_preview_test.dart empty preview | Partial missing input and empty collage; missing saved-image handling missing |

## Execution sequence

1. Record Flutter/Dart, project venv Python/package versions, Firebase CLI, connected Android devices/AVDs, and local service port availability. Windows sandbox startup failed with `helper_sandbox_lock_failed`; approved elevated read/test commands are required in this session.
2. Run existing Flutter suite from `apps/mobile_app` with `--no-pub` to avoid dependency resolution. Run project venv pytest from `apps/ai_service` using its existing `pytest.ini`, verbose output, and JUnit XML. Record collection failures before diagnosing; do not weaken assertions.
3. Add separate test files only for missing, isolated behavior: real form submission validation and Firebase exception handling using fakes; API missing/unsupported input guards with temporary storage; image preview fallback. Reuse existing fixtures where possible. Run added files separately, preserving baseline evidence.
4. Produce the 36-row final matrix with original requirement status, actual observations and evidence. A passing fake/component test cannot pass a whole live workflow. Use BLOCKED for unavailable integration prerequisites, NOT RUN for unsupported/unexecuted original flows, FAIL only for observed unmet executed assertions.
5. Provide per-case manual steps, synthetic data, screenshot timing/filenames, supporting service records, and safe dedicated-test-environment prerequisites. Do not create pretend screenshots.

## Required services and likely blockers

Android app/device with camera/gallery permissions; a dedicated Firebase project or isolated emulator setup for Auth/Firestore/Storage; local AI backend and extraction worker/models; authorized hosted FASHN key/credits for real generation. Integration-test dependency is absent from pubspec. Do not add dependencies or redirect production configuration without approval. Tool availability alone does not establish running services or valid test accounts.

# StyleSync added functional coverage and execution matrix

Generated 2026-11-16T23:18:07.482839+08:00 (Asia/Kuala_Lumpur). **39 new tests were created in seven separate test scripts: 37 Flutter widget/controller tests and 2 FastAPI workflow tests. All 39 ran individually and passed; all also passed in the combined suites after fixture isolation corrections.** No pre-existing test file, application code, dependency manifest, Firebase settings/rules or production data was modified. The test-only shared helper uses existing installed platform interfaces; no packages were added.

## Actual execution results

| Suite | Total | Passed | Failed | Skipped / collection errors | Evidence |
| --- | ---: | ---: | ---: | --- | --- |
| Current Flutter suite | 110 | 104 | 6 | 0 / 0 | [Full log](../logs/flutter/gap_expansion_full_03.log), [JSONL](../logs/flutter/gap_expansion_full_03.jsonl), [metadata](../logs/flutter/gap_expansion_full_03.log.meta.json) |
| Current FastAPI suite | 151 | 151 | 0 | 0 / 0 | [Full log](../logs/fastapi/gap_expansion_full_01.log), [JUnit](../logs/fastapi/gap_expansion_full_01.xml), [metadata](../logs/fastapi/gap_expansion_full_01.log.meta.json) |
| New tests only | 39 | 39 | 0 | 0 / 0 | Named individual runs below and combined native results |
| **Combined unique tests** | **261** | **255** | **6** | **0 / 0** | **97.70% assertion pass rate; not live functional acceptance** |

The previous suite had 222 tests (216 PASS / 6 FAIL). Exactly 39 were added; existing assertions were preserved. The original placeholder test remains nonfunctional coverage. Test exit codes are Flutter 1 and pytest 0; the older full-suite capture wrapper records the child's actual status in metadata even though the wrapper exits zero.

Each new test was selected with `flutter test --no-pub <new file> --plain-name <exact name>` or `python -m pytest <new module>::<node>` from the correct app directory. Full suites subsequently ran from `apps/mobile_app` and `apps/ai_service`. `testing_evidence/tools/run_functional_gap.py` preserves stdout/stderr, native results, exact command, cwd, timestamps and actual test exit code, and refuses to overwrite evidence.

Targeted static analysis of the six new Dart test scripts and shared helper completed with **No issues found**: [analyzer log](../logs/flutter/gap_expansion_analyze_final.log). Its initial ten style diagnostics were corrected in the new files before the final full-suite run; no existing file was edited.

## Why these tests were necessary

Tests were added for uncovered behaviors and boundary variants, not to duplicate the existing happy-path API, body-metric helper, empty-form, duplicate-save model or malformed-image assertions.

| New script | Coverage gap addressed |
| --- | --- |
| `fyp_auth_workflow_test.dart` | Existing valid-form tests stopped at a recording controller; these exercise the real AuthController success/profile-routing chain and previously untested malformed-email/password-strength variants. |
| `fyp_wardrobe_workflow_test.dart` | No real ClosetController upload/cancel or Home category-sheet interaction tests existed; these verify processed bytes, selected category, no-write cancellation and category dismissal. |
| `fyp_twin_workflow_test.dart` | Existing checks covered metric helpers and API processing separately; these cover completed merged profile persistence, missing-weight/style guards and the actual twin/empty-twin screen. |
| `fyp_tryon_workflow_test.dart` | Backend composition and OutfitDraft were covered, but changed UI selections, no-twin VTON UI, screen-to-save-to-view flow and remote-image failure in the full viewer were not. |
| `fyp_inspo_workflow_test.dart` | Existing UI tests covered an empty twin list and cancelling an empty picker; these add a real local preview, cancelling replacement, choosing another twin, selected-reference/no-twin guard and processing-error UI. |
| `fyp_planner_workflow_test.dart` | Only date models and mocked notification service payloads were covered; these exercise real date/time pickers, save/list rendering, date changes and cancellation at all three stages. |
| `tests/test_fyp_workflow_gaps.py` | Existing list tests seeded stores directly; these create through FastAPI, recreate the app/store and retrieve the actual persisted twin/garment with user isolation. |

## Coverage matrix TC-001 through TC-036

“PASS” in the automated outcome column means executed assertions at the stated isolated scope. It does not certify real Firebase, paid AI or Android plugin operation. Existing and new results below come from the latest combined native logs. The same check can support multiple cases; per-row counts must not be summed. Exact test names and individual evidence are retained in [the JSON matrix](Functional_Gap_Coverage_Matrix.json); [CSV matrix](Functional_Gap_Coverage_Matrix.csv) is also available.

Original full-scenario acceptance remains conservative: **TC-002/006/008 passed local validation; 29 cases require integration/manual acceptance; TC-014/020/032/033 retain NOT RUN for the literal original interaction.** New tests of the four proposed replacement interactions are labeled “revised”; they do not silently replace the FYP requirements. No complete Android/real-Firebase/real-AI acceptance is claimed.

| Case | Scenario | Test scripts and actual outcomes | Automated evidence outcome | Remaining manual/integration work |
| --- | --- | --- | --- | --- |
| TC-001 | Register with valid details | fyp_auth_workflow_test.dart: 1 PASS; fyp_functional_gaps_test.dart: 1 PASS | PASS: 2 isolated checks; live acceptance unverified | MANUAL / isolated integration: real Auth account creation, Firestore profile persistence and routing. |
| TC-002 | Submit empty required fields | fyp_auth_workflow_test.dart: 4 PASS; fyp_functional_gaps_test.dart: 1 PASS | PASS: 5 isolated checks; live acceptance unverified | Local validation automated; confirm small-screen/keyboard layout on Android. |
| TC-003 | Register using an existing email | fyp_functional_gaps_test.dart: 1 PASS | PASS: 1 isolated checks; live acceptance unverified | MANUAL / isolated integration: real duplicate email rejection and unchanged account count; existing fake-error test reused. |
| TC-004 | Login using valid credentials | fyp_auth_workflow_test.dart: 3 PASS; fyp_functional_gaps_test.dart: 1 PASS; tests/test_auth.py: 1 PASS | PASS: 5 isolated checks; live acceptance unverified | MANUAL / isolated integration: real credentials/session and completed/incomplete-profile destinations. |
| TC-005 | Login using incorrect password | fyp_functional_gaps_test.dart: 1 PASS | PASS: 1 isolated checks; live acceptance unverified | MANUAL / isolated integration: real wrong-password error and signed-out state; existing fake-error test reused. |
| TC-006 | Login using empty fields | fyp_auth_workflow_test.dart: 1 PASS; fyp_functional_gaps_test.dart: 1 PASS | PASS: 2 isolated checks; live acceptance unverified | Local validation automated; confirm keyboard/field behavior on Android. |
| TC-007 | Create Digital Twin with valid body details | fyp_twin_workflow_test.dart: 1 PASS; profile_validation_test.dart: 3 PASS; tests/test_fyp_workflow_gaps.py: 1 PASS; tests/test_pipeline_api.py: 1 PASS | PASS: 6 isolated checks; live acceptance unverified | MANUAL / isolated integration: real pose/background-removal models and Firebase uploads/profile. |
| TC-008 | Submit incomplete body details | fyp_functional_gaps_test.dart: 2 PASS; fyp_twin_workflow_test.dart: 2 PASS; profile_validation_test.dart: 8 PASS; tests/test_fyp_functional_gaps.py: 1 PASS | PASS: 13 isolated checks; live acceptance unverified | Missing photo/height/weight/styles and metric validation automated; confirm on-device notices. |
| TC-009 | Retrieve saved Digital Twin | fyp_twin_workflow_test.dart: 1 PASS; tests/test_fyp_workflow_gaps.py: 1 PASS; tests/test_list_endpoints.py: 4 PASS | PASS: 6 isolated checks; live acceptance unverified | MANUAL / isolated integration: real user session, device reopen/retrieval and backend-offline Firebase-photo fallback. |
| TC-010 | Upload clothing image from gallery | fyp_wardrobe_workflow_test.dart: 1 PASS; tests/test_fyp_workflow_gaps.py: 1 PASS; tests/test_wardrobe_api.py: 1 PASS; wardrobe_recovery_test.dart: 1 PASS | PASS: 4 isolated checks; live acceptance unverified | MANUAL: native gallery and real service upload; controller path and API restart persistence now automated. |
| TC-011 | Capture clothing image using camera | fyp_wardrobe_workflow_test.dart: 1 PASS | PASS: 1 isolated checks; live acceptance unverified | MANUAL: camera permission, physical capture and acceptance; source selection/controller upload now automated with picker mock. |
| TC-012 | Cancel clothing image selection | fyp_wardrobe_workflow_test.dart: 2 PASS | PASS: 2 isolated checks; live acceptance unverified | MANUAL: native gallery/camera Back gestures; null-picker no-write business behavior now automated. |
| TC-013 | Assign clothing category | fyp_wardrobe_workflow_test.dart: 2 PASS; tests/test_fyp_functional_gaps.py: 1 PASS; tests/test_fyp_workflow_gaps.py: 1 PASS; tests/test_wardrobe_api.py: 2 PASS | PASS: 6 isolated checks; live acceptance unverified | MANUAL / isolated integration: category-first upload across real Firebase/backend; controller category persistence automated. |
| TC-014 | Change clothing category | fyp_wardrobe_workflow_test.dart: 1 PASS | PASS for revised interaction only; original NOT RUN | REQUIREMENT GAP: no saved category editor. Only the explicitly revised pre-upload category-selection interaction is automated. |
| TC-015 | Cancel categorization | fyp_wardrobe_workflow_test.dart: 1 PASS | PASS: 1 isolated checks; live acceptance unverified | Category-sheet dismissal automated; native navigation/layout confirmation remains manual. |
| TC-016 | Generate Virtual Try-On image | fyp_tryon_workflow_test.dart: 1 PASS; generation_confirmation_test.dart: 6 FAIL; tests/test_generation_modes.py: 6 PASS; tests/test_max_quality.py: 1 PASS; tests/test_tryon_api.py: 2 PASS | MIXED: 10 PASS, 6 FAIL (isolated) | MANUAL: real AI image/identity/garment quality; existing six credit-confirmation assertions still fail and need approved resolution. |
| TC-017 | Change clothing selection before generation | fyp_tryon_workflow_test.dart: 1 PASS; generation_confirmation_test.dart: 1 PASS | PASS: 2 isolated checks; live acceptance unverified | Final garment request selection automated; real garment change in hosted AI output requires manual review. |
| TC-018 | Attempt Virtual Try-On without Digital Twin | fyp_tryon_workflow_test.dart: 1 PASS; tests/test_tryon_api.py: 1 PASS | PASS: 2 isolated checks; live acceptance unverified | No-twin disabled VTON UI and API rejection automated; verify approved no-twin Android test account. |
| TC-019 | Save generated outfit | fyp_tryon_workflow_test.dart: 1 PASS; outfit_draft_test.dart: 1 PASS; tests/test_tryon_api.py: 1 PASS | PASS: 3 isolated checks; live acceptance unverified | Screen-to-storage/document-to-viewer save automated with Firebase fakes; real persistence/reopen requires integration. |
| TC-020 | Cancel saving | fyp_tryon_workflow_test.dart: 1 PASS | PASS for revised interaction only; original NOT RUN | REQUIREMENT GAP: no cancel-save dialog. Revised leave-unsaved behavior is automated; backend result retention is separate. |
| TC-021 | Save an already saved outfit | fyp_tryon_workflow_test.dart: 1 PASS; outfit_draft_test.dart: 1 PASS | PASS: 2 isolated checks; live acceptance unverified | Current-draft save locking and disabled Saved UI automated; verify real document/object count. Cross-session deduplication is not implemented. |
| TC-022 | Upload valid inspiration image | fyp_inspo_workflow_test.dart: 1 PASS; generation_confirmation_test.dart: 1 PASS; tests/test_inspo_api.py: 1 PASS | PASS: 3 isolated checks; live acceptance unverified | Local preview/no-premature-upload automated; native picker and real multipart transfer require integration. |
| TC-023 | Upload unsupported image format | tests/test_fyp_functional_gaps.py: 1 PASS; tests/test_inspo_api.py: 1 PASS | PASS: 2 isolated checks; live acceptance unverified | Server SVG/malformed-input rejection already automated and reused; actual native picker format support/exclusion is manual. |
| TC-024 | Cancel image selection | fyp_functional_gaps_test.dart: 1 PASS; fyp_inspo_workflow_test.dart: 1 PASS | PASS: 2 isolated checks; live acceptance unverified | Both empty-selection and replacement cancellation automated at plugin boundary; native gallery Back is manual. |
| TC-025 | Apply inspiration style to Digital Twin | fyp_inspo_workflow_test.dart: 1 PASS; generation_confirmation_test.dart: 1 FAIL; tests/test_fashn_api.py: 1 PASS; tests/test_inspo_api.py: 1 PASS; tests/test_max_quality.py: 1 PASS | MIXED: 4 PASS, 1 FAIL (isolated) | Selected twin/reference/result UI automated with fake provider; real outfit/identity fidelity and shared credit-disclosure issue remain. |
| TC-026 | Apply style without Digital Twin | fyp_inspo_workflow_test.dart: 1 PASS; inspo_mirror_screen_test.dart: 1 PASS; tests/test_fyp_functional_gaps.py: 1 PASS; tests/test_inspo_api.py: 1 PASS | PASS: 4 isolated checks; live acceptance unverified | Selected reference without a twin now automated; real account/device setup guidance confirmation remains. |
| TC-027 | Process an unsuitable inspiration image | fyp_inspo_workflow_test.dart: 1 PASS; tests/test_fyp_functional_gaps.py: 2 PASS | PASS: 3 isolated checks; live acceptance unverified | Malformed/undersized checks and mocked provider-error UI automated. Valid-size blank image still reaches provider; semantic suitability and real AI behavior require criteria/manual review. |
| TC-028 | Schedule outfit for selected date | fyp_planner_workflow_test.dart: 1 PASS; notification_service_test.dart: 3 PASS; outfit_plan_test.dart: 1 PASS | PASS: 5 isolated checks; live acceptance unverified | Date/time/item selection, plan write, visible card and mocked alarm payload automated; real Firestore/Android alarm delivery remain manual. |
| TC-029 | Change selected date | fyp_planner_workflow_test.dart: 1 PASS | PASS: 1 isolated checks; live acceptance unverified | Changing date before commit automated; no dedicated move-existing-plan action exists. |
| TC-030 | Cancel outfit scheduling | fyp_planner_workflow_test.dart: 3 PASS | PASS: 3 isolated checks; live acceptance unverified | Date/time/item cancellation and no-write/no-alarm assertions automated; confirm OS navigation/permission interaction manually. |
| TC-031 | View scheduled outfit | fyp_planner_workflow_test.dart: 1 PASS; outfit_plan_test.dart: 3 PASS; outfit_preview_test.dart: 1 PASS | PASS: 5 isolated checks; live acceptance unverified | Upcoming plan cards/items now automated; real multi-session stream/reopen and actual reminder expiry require integration. |
| TC-032 | View date with no scheduled outfit | fyp_planner_workflow_test.dart: 1 PASS; outfit_plan_test.dart: 1 PASS; outfit_preview_test.dart: 1 PASS | PASS for revised interaction only; original NOT RUN | REQUIREMENT GAP: no daily selected-date viewer. Revised empty-upcoming-list behavior automated. |
| TC-033 | Switch between planned dates | fyp_planner_workflow_test.dart: 1 PASS | PASS for revised interaction only; original NOT RUN | REQUIREMENT GAP: no daily calendar navigation. Revised multiple dated list cards automated. |
| TC-034 | Display outfit on Digital Twin | fyp_tryon_workflow_test.dart: 1 PASS; outfit_preview_test.dart: 1 PASS; tests/test_tryon_api.py: 1 PASS | PASS: 3 isolated checks; live acceptance unverified | Generated-result display and saved full viewer automated; real visual correctness manual. Applying arbitrary saved/planned items to a twin is a separate absent operation. |
| TC-035 | Display outfit without Digital Twin | fyp_twin_workflow_test.dart: 1 PASS; inspo_mirror_screen_test.dart: 1 PASS; tests/test_tryon_api.py: 1 PASS | PASS: 3 isolated checks; live acceptance unverified | Empty Virtual Twin/Create Twin now automated; verify real no-twin account. Viewing an existing saved image is independent of a current twin. |
| TC-036 | Display unavailable outfit | fyp_functional_gaps_test.dart: 2 PASS; fyp_tryon_workflow_test.dart: 1 PASS; tests/test_tryon_api.py: 1 PASS | PASS: 4 isolated checks; live acceptance unverified | Missing URL component and simulated remote-image failure in full viewer automated; confirm real missing test object/offline Android navigation. |

## Individual new-test results

Every row below has both a successful individual execution and a successful result in the latest combined suite. Previously failed attempts are preserved in the attempt history, rather than overwritten. A compile error or earlier failed assertion was never recorded as a successful execution.

| New test | Final outcome | Successful individual terminal log |
| --- | --- | --- |
| `fyp_auth_workflow_test.dart::TC-001 registration persists profile for returned uid and routes to setup` | PASS | [gap_auth_register_02](../logs/flutter/gap_auth_register_02.log) |
| `fyp_auth_workflow_test.dart::TC-004 login routes complete profile after credential success` | PASS | [gap_auth_login_complete_01](../logs/flutter/gap_auth_login_complete_01.log) |
| `fyp_auth_workflow_test.dart::TC-004 login routes incomplete profile after credential success` | PASS | [gap_auth_login_incomplete_01](../logs/flutter/gap_auth_login_incomplete_01.log) |
| `fyp_auth_workflow_test.dart::TC-004 login routes missing profile after credential success` | PASS | [gap_auth_login_missing_01](../logs/flutter/gap_auth_login_missing_01.log) |
| `fyp_auth_workflow_test.dart::TC-002 malformed email cannot reach Firebase` | PASS | [gap_auth_email_signup_01](../logs/flutter/gap_auth_email_signup_01.log) |
| `fyp_inspo_workflow_test.dart::TC-022 selecting reference previews locally without uploading or generating` | PASS | [gap_inspo_preview_01](../logs/flutter/gap_inspo_preview_01.log) |
| `fyp_auth_workflow_test.dart::TC-006 malformed email cannot reach Firebase` | PASS | [gap_auth_email_login_01](../logs/flutter/gap_auth_email_login_01.log) |
| `fyp_inspo_workflow_test.dart::TC-024 cancelling replacement picker preserves previously selected reference` | PASS | [gap_inspo_cancel_existing_01](../logs/flutter/gap_inspo_cancel_existing_01.log) |
| `fyp_auth_workflow_test.dart::TC-002 short password cannot reach Firebase` | PASS | [gap_auth_password_short_01](../logs/flutter/gap_auth_password_short_01.log) |
| `fyp_tryon_workflow_test.dart::TC-017 changing top before confirmation sends only final selection once` | PASS | [gap_vton_selection_02](../logs/flutter/gap_vton_selection_02.log) |
| `fyp_auth_workflow_test.dart::TC-002 no_uppercase password cannot reach Firebase` | PASS | [gap_auth_password_upper_01](../logs/flutter/gap_auth_password_upper_01.log) |
| `fyp_planner_workflow_test.dart::TC-028 TC-031 selected future date stores plan and displays items with reminder` | PASS | [gap_planner_save_02](../logs/flutter/gap_planner_save_02.log) |
| `fyp_tryon_workflow_test.dart::TC-018 try-on without twin disables Generate and shows setup guidance` | PASS | [gap_vton_no_twin_01](../logs/flutter/gap_vton_no_twin_01.log) |
| `fyp_auth_workflow_test.dart::TC-002 no_special password cannot reach Firebase` | PASS | [gap_auth_password_special_01](../logs/flutter/gap_auth_password_special_01.log) |
| `fyp_twin_workflow_test.dart::TC-007 accepted twin photo persists processed image and completed merged profile` | PASS | [gap_twin_create_01](../logs/flutter/gap_twin_create_01.log) |
| `fyp_inspo_workflow_test.dart::TC-025 selected twin and reference generate one visible inspired result` | PASS | [gap_inspo_generate_04](../logs/flutter/gap_inspo_generate_04.log) |
| `fyp_twin_workflow_test.dart::TC-008 missing weight blocks profile creation before API and storage` | PASS | [gap_twin_weight_01](../logs/flutter/gap_twin_weight_01.log) |
| `fyp_twin_workflow_test.dart::TC-008 missing styles blocks profile creation before API and storage` | PASS | [gap_twin_styles_01](../logs/flutter/gap_twin_styles_01.log) |
| `fyp_planner_workflow_test.dart::TC-029 changing selected date before commit writes only final date` | PASS | [gap_planner_date_02](../logs/flutter/gap_planner_date_02.log) |
| `fyp_inspo_workflow_test.dart::TC-026 selected reference without twin cannot generate` | PASS | [gap_inspo_no_twin_01](../logs/flutter/gap_inspo_no_twin_01.log) |
| `fyp_twin_workflow_test.dart::TC-009 twin screen retrieves processed saved twin rather than fallback URL` | PASS | [gap_twin_retrieve_01](../logs/flutter/gap_twin_retrieve_01.log) |
| `fyp_twin_workflow_test.dart::TC-035 missing twin screen offers Create Twin without a broken image` | PASS | [gap_twin_empty_01](../logs/flutter/gap_twin_empty_01.log) |
| `fyp_tryon_workflow_test.dart::TC-019 TC-021 TC-034 generated result saves once and reopens in full viewer` | PASS | [gap_vton_save_view_02](../logs/flutter/gap_vton_save_view_02.log) |
| `fyp_planner_workflow_test.dart::TC-030 cancelling date selection creates no plan or alarm` | PASS | [gap_planner_cancel_date_02](../logs/flutter/gap_planner_cancel_date_02.log) |
| `fyp_inspo_workflow_test.dart::TC-027 mocked processing rejection is readable and retains reference for retry` | PASS | [gap_inspo_rejection_01](../logs/flutter/gap_inspo_rejection_01.log) |
| `fyp_planner_workflow_test.dart::TC-030 cancelling time selection creates no plan or alarm` | PASS | [gap_planner_cancel_time_02](../logs/flutter/gap_planner_cancel_time_02.log) |
| `fyp_tryon_workflow_test.dart::TC-020 revised leave-generated-result-unsaved creates no liked outfit` | PASS | [gap_vton_leave_01](../logs/flutter/gap_vton_leave_01.log) |
| `fyp_tryon_workflow_test.dart::TC-036 unavailable remote outfit image keeps full gallery viewer usable` | PASS | [gap_view_unavailable_01](../logs/flutter/gap_view_unavailable_01.log) |
| `fyp_planner_workflow_test.dart::TC-030 cancelling items selection creates no plan or alarm` | PASS | [gap_planner_cancel_items_02](../logs/flutter/gap_planner_cancel_items_02.log) |
| `fyp_planner_workflow_test.dart::TC-032 revised empty upcoming list explains how to create a plan` | PASS | [gap_planner_empty_02](../logs/flutter/gap_planner_empty_02.log) |
| `fyp_wardrobe_workflow_test.dart::TC-010 TC-013 gallery clothing upload stores processed bytes and category` | PASS | [gap_closet_gallery_02](../logs/flutter/gap_closet_gallery_02.log) |
| `fyp_planner_workflow_test.dart::TC-033 revised multiple dated cards preserve chronological date and item pairing` | PASS | [gap_planner_cards_02](../logs/flutter/gap_planner_cards_02.log) |
| `fyp_wardrobe_workflow_test.dart::TC-011 TC-013 camera clothing upload stores processed bytes and category` | PASS | [gap_closet_camera_02](../logs/flutter/gap_closet_camera_02.log) |
| `fyp_wardrobe_workflow_test.dart::TC-012 cancelling gallery clothing picker performs no IO writes` | PASS | [gap_closet_cancel_gallery_01](../logs/flutter/gap_closet_cancel_gallery_01.log) |
| `fyp_wardrobe_workflow_test.dart::TC-012 cancelling camera clothing picker performs no IO writes` | PASS | [gap_closet_cancel_camera_01](../logs/flutter/gap_closet_cancel_camera_01.log) |
| `fyp_wardrobe_workflow_test.dart::TC-015 dismissing category sheet leaves closet and services unchanged` | PASS | [gap_category_cancel_01](../logs/flutter/gap_category_cancel_01.log) |
| `fyp_wardrobe_workflow_test.dart::TC-014 revised pre-upload category choice uses the newly selected category` | PASS | [gap_category_change_01](../logs/flutter/gap_category_change_01.log) |
| `tests/test_fyp_workflow_gaps.py::test_TC007_TC009_created_twin_survives_app_restart_and_stays_user_scoped` | PASS | [gap_api_twin_restart_01](../logs/fastapi/gap_api_twin_restart_01.log) |
| `tests/test_fyp_workflow_gaps.py::test_TC010_TC013_uploaded_category_and_processed_image_survive_app_restart` | PASS | [gap_api_wardrobe_restart_01](../logs/fastapi/gap_api_wardrobe_restart_01.log) |

## Remaining failures and observed limitations

The six **pre-existing** failures remain in `generation_confirmation_test.dart`:

- `generation_confirmation_test.dart::VTON shows the total and cancellation declines generation`
- `generation_confirmation_test.dart::Inspo confirms exactly one three-credit generation`
- `generation_confirmation_test.dart::cost confirmation remains usable in landscape`
- `generation_confirmation_test.dart::Fast confirmation shows its own total`
- `generation_confirmation_test.dart::Balanced confirmation shows its own total`
- `generation_confirmation_test.dart::Quality confirmation shows its own total`

They expect credit-total titles/action text while production `confirmGeneration` displays `Generate outfit?` and a generic Generate action. No application fix or assertion weakening was performed. The new workflow tests exercise selected-request/result/save behavior and do not bypass or relabel those failing cost-disclosure assertions. They are supplemental checks with a different scope.

FastAPI still emits one Starlette TestClient/HTTPX deprecation warning. The two new backend tests use real FastAPI decoding and temporary filesystem persistence with fake authentication/model engines; they do not test a live AI model. Semantic suitability remains undefined: the existing blank-reference characterization still calls the fake provider and returns 201. New TC-027 checks error presentation when a processing rejection is returned, not semantic rejection accuracy.

## Test fixture corrections and complete attempt history

There were 54 individual execution attempts; 15 returned nonzero before correction. All logs remain. Issues were in the new fixtures/tests: awaiting Get.reset despite its void return, missing HTTP redirects in the fake client, Windows stdout encoding of failure diagnostics, lazy-list finder positioning, waiting for native image decoding, binary multipart decoding, mixed path separators in a test-created image filename, and cleanup of the test Android platform override. None required application changes or weaker expectations.

The first combined Flutter run ([log](../logs/flutter/gap_expansion_full_01.log)) had 87 PASS / 23 FAIL: six known application/test-contract failures and seventeen new shared-fixture failures. Root cause was firebase_core caching its core delegate independently of the platform singleton; later tests reused earlier fake Auth/Firestore/Storage clients. The helper now resets and restores Firebase's documented `delegatePackingProperty` testing hook and uses a unique fake app name. Latest combined run is 104 PASS / 6 known FAIL, with all additions passing. HTTP/image test clients are restored after each scoped operation.

| Attempt | Actual test/capture exit | Terminal evidence |
| --- | ---: | --- |
| gap_auth_email_login_01 | 0 | [gap_auth_email_login_01.log](../logs/flutter/gap_auth_email_login_01.log) |
| gap_auth_email_signup_01 | 0 | [gap_auth_email_signup_01.log](../logs/flutter/gap_auth_email_signup_01.log) |
| gap_auth_login_complete_01 | 0 | [gap_auth_login_complete_01.log](../logs/flutter/gap_auth_login_complete_01.log) |
| gap_auth_login_incomplete_01 | 0 | [gap_auth_login_incomplete_01.log](../logs/flutter/gap_auth_login_incomplete_01.log) |
| gap_auth_login_missing_01 | 0 | [gap_auth_login_missing_01.log](../logs/flutter/gap_auth_login_missing_01.log) |
| gap_auth_password_short_01 | 0 | [gap_auth_password_short_01.log](../logs/flutter/gap_auth_password_short_01.log) |
| gap_auth_password_special_01 | 0 | [gap_auth_password_special_01.log](../logs/flutter/gap_auth_password_special_01.log) |
| gap_auth_password_upper_01 | 0 | [gap_auth_password_upper_01.log](../logs/flutter/gap_auth_password_upper_01.log) |
| gap_auth_register_01 | 1 | [gap_auth_register_01.log](../logs/flutter/gap_auth_register_01.log) |
| gap_auth_register_02 | 0 | [gap_auth_register_02.log](../logs/flutter/gap_auth_register_02.log) |
| gap_category_cancel_01 | 0 | [gap_category_cancel_01.log](../logs/flutter/gap_category_cancel_01.log) |
| gap_category_change_01 | 0 | [gap_category_change_01.log](../logs/flutter/gap_category_change_01.log) |
| gap_closet_camera_01 | 1 | [gap_closet_camera_01.log](../logs/flutter/gap_closet_camera_01.log) |
| gap_closet_camera_02 | 0 | [gap_closet_camera_02.log](../logs/flutter/gap_closet_camera_02.log) |
| gap_closet_cancel_camera_01 | 0 | [gap_closet_cancel_camera_01.log](../logs/flutter/gap_closet_cancel_camera_01.log) |
| gap_closet_cancel_gallery_01 | 0 | [gap_closet_cancel_gallery_01.log](../logs/flutter/gap_closet_cancel_gallery_01.log) |
| gap_closet_gallery_01 | 1 | [gap_closet_gallery_01.log](../logs/flutter/gap_closet_gallery_01.log) |
| gap_closet_gallery_02 | 0 | [gap_closet_gallery_02.log](../logs/flutter/gap_closet_gallery_02.log) |
| gap_inspo_cancel_existing_01 | 0 | [gap_inspo_cancel_existing_01.log](../logs/flutter/gap_inspo_cancel_existing_01.log) |
| gap_inspo_generate_01 | 1 | [gap_inspo_generate_01.log](../logs/flutter/gap_inspo_generate_01.log) |
| gap_inspo_generate_02 | 1 | [gap_inspo_generate_02.log](../logs/flutter/gap_inspo_generate_02.log) |
| gap_inspo_generate_03 | 1 | [gap_inspo_generate_03.log](../logs/flutter/gap_inspo_generate_03.log) |
| gap_inspo_generate_04 | 0 | [gap_inspo_generate_04.log](../logs/flutter/gap_inspo_generate_04.log) |
| gap_inspo_no_twin_01 | 0 | [gap_inspo_no_twin_01.log](../logs/flutter/gap_inspo_no_twin_01.log) |
| gap_inspo_preview_01 | 0 | [gap_inspo_preview_01.log](../logs/flutter/gap_inspo_preview_01.log) |
| gap_inspo_rejection_01 | 0 | [gap_inspo_rejection_01.log](../logs/flutter/gap_inspo_rejection_01.log) |
| gap_planner_cancel_date_01 | 1 | [gap_planner_cancel_date_01.log](../logs/flutter/gap_planner_cancel_date_01.log) |
| gap_planner_cancel_date_02 | 0 | [gap_planner_cancel_date_02.log](../logs/flutter/gap_planner_cancel_date_02.log) |
| gap_planner_cancel_items_01 | 1 | [gap_planner_cancel_items_01.log](../logs/flutter/gap_planner_cancel_items_01.log) |
| gap_planner_cancel_items_02 | 0 | [gap_planner_cancel_items_02.log](../logs/flutter/gap_planner_cancel_items_02.log) |
| gap_planner_cancel_time_01 | 1 | [gap_planner_cancel_time_01.log](../logs/flutter/gap_planner_cancel_time_01.log) |
| gap_planner_cancel_time_02 | 0 | [gap_planner_cancel_time_02.log](../logs/flutter/gap_planner_cancel_time_02.log) |
| gap_planner_cards_01 | 1 | [gap_planner_cards_01.log](../logs/flutter/gap_planner_cards_01.log) |
| gap_planner_cards_02 | 0 | [gap_planner_cards_02.log](../logs/flutter/gap_planner_cards_02.log) |
| gap_planner_date_01 | 1 | [gap_planner_date_01.log](../logs/flutter/gap_planner_date_01.log) |
| gap_planner_date_02 | 0 | [gap_planner_date_02.log](../logs/flutter/gap_planner_date_02.log) |
| gap_planner_empty_01 | 1 | [gap_planner_empty_01.log](../logs/flutter/gap_planner_empty_01.log) |
| gap_planner_empty_02 | 0 | [gap_planner_empty_02.log](../logs/flutter/gap_planner_empty_02.log) |
| gap_planner_save_01 | 1 | [gap_planner_save_01.log](../logs/flutter/gap_planner_save_01.log) |
| gap_planner_save_02 | 0 | [gap_planner_save_02.log](../logs/flutter/gap_planner_save_02.log) |
| gap_twin_create_01 | 0 | [gap_twin_create_01.log](../logs/flutter/gap_twin_create_01.log) |
| gap_twin_empty_01 | 0 | [gap_twin_empty_01.log](../logs/flutter/gap_twin_empty_01.log) |
| gap_twin_retrieve_01 | 0 | [gap_twin_retrieve_01.log](../logs/flutter/gap_twin_retrieve_01.log) |
| gap_twin_styles_01 | 0 | [gap_twin_styles_01.log](../logs/flutter/gap_twin_styles_01.log) |
| gap_twin_weight_01 | 0 | [gap_twin_weight_01.log](../logs/flutter/gap_twin_weight_01.log) |
| gap_view_unavailable_01 | 0 | [gap_view_unavailable_01.log](../logs/flutter/gap_view_unavailable_01.log) |
| gap_vton_leave_01 | 0 | [gap_vton_leave_01.log](../logs/flutter/gap_vton_leave_01.log) |
| gap_vton_no_twin_01 | 0 | [gap_vton_no_twin_01.log](../logs/flutter/gap_vton_no_twin_01.log) |
| gap_vton_save_view_01 | 1 | [gap_vton_save_view_01.log](../logs/flutter/gap_vton_save_view_01.log) |
| gap_vton_save_view_02 | 0 | [gap_vton_save_view_02.log](../logs/flutter/gap_vton_save_view_02.log) |
| gap_vton_selection_01 | 1 | [gap_vton_selection_01.log](../logs/flutter/gap_vton_selection_01.log) |
| gap_vton_selection_02 | 0 | [gap_vton_selection_02.log](../logs/flutter/gap_vton_selection_02.log) |
| gap_api_twin_restart_01 | 0 | [gap_api_twin_restart_01.log](../logs/fastapi/gap_api_twin_restart_01.log) |
| gap_api_wardrobe_restart_01 | 0 | [gap_api_wardrobe_restart_01.log](../logs/fastapi/gap_api_wardrobe_restart_01.log) |

## Manual instructions and preservation

[Functional_Gap_Manual_Guide.md](Functional_Gap_Manual_Guide.md) provides all 36 cases with exact steps, data, expected behavior, screenshot timing/names and Firebase/FastAPI evidence inspection. Rows that need device/service interaction are explicitly marked. For an unavailable literal feature, first record the absence and resolve the requirement; do not claim a manual PASS for an unimplemented action.

SDK adapters, picker, HTTP provider and notification channels are test fakes. Their data stays in memory except synthetic image files in a newly created temporary directory, which each test cleans up. API persistence uses pytest tmp_path, not existing AI_DATA_DIR. No production credentials or data were read or changed. All 30 original tracked test/fixture files were hash-checked against the earlier integrity snapshot and remain identical; no tracked source changes are present. Historical reports remain unchanged and are superseded for current coverage by this matrix.

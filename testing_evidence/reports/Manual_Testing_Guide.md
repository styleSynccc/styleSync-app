# StyleSync manual functional testing guide

Prepared 16 November 2026 (Asia/Kuala_Lumpur). These are pending instructions, not executed results. Recheck current report status before recording evidence. Widget-only passes should also be confirmed on Android for final device acceptance.

## Preconditions

Use only a dedicated Firebase test project or properly isolated Auth/Firestore/Storage emulators, test accounts and consented/synthetic images. The current application uses configured Firebase project options and no emulator routing; changing that wiring, application code, dependencies, settings or rules requires the user's approval. Do not run registration/upload/planning against the configured project until it is explicitly identified as the approved test environment. Never delete existing production data to construct a negative case.

Connect an Android emulator or phone and verify `adb devices -l`. Three AVDs are installed but none were connected during this run. Use a test build pointed to the isolated AI service (AI_DATA_DIR must be separate from existing data); keep Firebase authentication enabled for integration checks. For an Android emulator the host service is commonly reached through 10.0.2.2; a physical device needs the approved host routing. Override AI_SERVICE_BASE_URL at build time using the actual isolated service address; the code's LAN default is not verified for this session. Start models/worker through the project's normal setup only after confirming their dependencies and data isolation. No installation/configuration change is authorized by this guide alone.

Use distinct test-user aliases: QA-New (new email), QA-Ready (completed profile/twin), QA-Incomplete, QA-NoTwin. Reserve their real test addresses/passwords privately; never put passwords, bearer tokens or full tokenized Storage URLs in evidence. A suitable synthetic password satisfies the code's >=6 characters, uppercase and special-character rules. Use clearly different top A/top B images, body photo >=320x640, garment >=256x256, inspiration >=320x640, tiny 120x160 JPEG and safe SVG. Backend limits are 25*1024*1024 bytes and 100,000,000 pixels; keep test inputs comfortably below limits except explicit negative cases.

Hosted generation may consume credits. Before a live request, use only the approved test key/budget and check the confirmation requirement discrepancy D-001. Submit once, preserve the result/error and avoid blind retries. Actual identity, clothes, modesty/hijab preservation and visual artifacts require human review; a successful HTTP response alone is insufficient.

## Recording each result

Keep screenshots under `testing_evidence/screenshots/UC-xx/`; filenames below are planned and do not yet exist unless explicitly identified in the report as widget captures. Append variant suffixes where indicated. Record date/time (UTC+08:00), build/hash, device model/Android version, test-data alias, exact steps, actual response/visible text, status and evidence paths in `testing_evidence/logs/integration/TC-NNN_manual.md`. Use PASS only after all stated acceptance checks are observed; FAIL for an observed unmet condition; BLOCKED for a missing prerequisite; NOT RUN when no execution occurred. Never infer Firebase persistence from a snackbar alone.

For Firebase evidence, open only the approved emulator UI or dedicated test console and record relevant field names/counts with UID/email anonymized. For FastAPI, record method/path/status, anonymized IDs and nonsecret metadata; do not log Authorization headers, API keys, full image base64 or private download URLs. For no-write/cancel cases compare before/after counts and request logs. The proposed replacements for unavailable features require agreement before substituting them for original FYP requirements.

## TC-001 — Register with valid details (UC-01)

**Current original-scenario status:** BLOCKED. **Test data:** New unique test email, username QA Student, permitted gender, strong synthetic password.

**Steps:** Open Sign Up; enter username/email; choose gender; enter password; tap Sign Up; verify setup page and one matching Auth user/profile.

**Expected behavior:** Create an Auth user, save profile, and route to setup.

**Screenshot timing:** After setup opens and the account-created notice appears. **Save as:** `testing_evidence/screenshots/UC-01/TC-001_registration_success.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Valid form forwarded all four details to a fake controller. No real account/profile creation was executed. See [TC-001 automated evidence](../logs/integration/TC-001_evidence.json).

## TC-002 — Submit empty required fields (UC-01)

**Current original-scenario status:** PASS. **Test data:** Leave username, email, gender and password unset.

**Steps:** Open Sign Up; leave all inputs blank; tap Sign Up; inspect all four validation messages.

**Expected behavior:** Show all required field errors and send no registration call.

**Screenshot timing:** With all validation errors visible. **Save as:** `testing_evidence/screenshots/UC-01/TC-002_empty_signup.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Widget submission showed name/email/gender/password errors; fake controller received no registration. Actual widget screenshot captured. See [TC-002 automated evidence](../logs/integration/TC-002_evidence.json).

## TC-003 — Register using an existing email (UC-01)

**Current original-scenario status:** BLOCKED. **Test data:** Email already present in the dedicated test Auth project; synthetic signup details.

**Steps:** Record initial test Auth user count; submit Sign Up using the existing email and otherwise valid fields; verify error and unchanged count.

**Expected behavior:** Show existing-email error and create no duplicate account.

**Screenshot timing:** While the Firebase error notice is visible. **Save as:** `testing_evidence/screenshots/UC-01/TC-003_existing_email.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Real controller displayed a fake Firebase email-already-in-use error and reset loading. Live duplicate-account handling remains unverified. See [TC-003 automated evidence](../logs/integration/TC-003_evidence.json).

## TC-004 — Login using valid credentials (UC-02)

**Current original-scenario status:** BLOCKED. **Test data:** Dedicated test account with known credentials and completed profile; repeat with incomplete profile.

**Steps:** Log out of the test app; open Login; enter valid test credentials; tap Login; verify correct destination for each profile state.

**Expected behavior:** Authenticate and route to Home for a completed profile, otherwise setup.

**Screenshot timing:** After the expected destination loads. **Save as:** `testing_evidence/screenshots/UC-02/TC-004_login_success.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Valid form forwarded credentials to a fake controller. No live Firebase login or profile-based routing executed. See [TC-004 automated evidence](../logs/integration/TC-004_evidence.json).

## TC-005 — Login using incorrect password (UC-02)

**Current original-scenario status:** BLOCKED. **Test data:** Known test account email; deliberately wrong synthetic password.

**Steps:** Start signed out; enter the test email and wrong password; tap Login; verify error, no destination change, and no active session.

**Expected behavior:** Show authentication error, stop loading, and stay signed out.

**Screenshot timing:** While the error notice is visible; keep the password obscured. **Save as:** `testing_evidence/screenshots/UC-02/TC-005_invalid_password.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Real controller handled a fake wrong-password exception, retained the original screen, and stopped loading. Live Firebase behavior unverified. See [TC-005 automated evidence](../logs/integration/TC-005_evidence.json).

## TC-006 — Login using empty fields (UC-02)

**Current original-scenario status:** PASS. **Test data:** Empty email and password.

**Steps:** Open Login; leave both fields blank; tap Login; verify both required messages.

**Expected behavior:** Show email/password required errors and send no login call.

**Screenshot timing:** With both required messages visible. **Save as:** `testing_evidence/screenshots/UC-02/TC-006_empty_login.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Both field errors appeared on submit and the isolated controller received no credentials. Actual widget screenshot captured. See [TC-006 automated evidence](../logs/integration/TC-006_evidence.json).

## TC-007 — Create Digital Twin with valid body details (UC-03)

**Current original-scenario status:** BLOCKED. **Test data:** Consented synthetic/test full-body JPEG >=320x640; height 170, weight 65.5, Casual.

**Steps:** Open twin setup; choose clear standing full-body photo; enter height/weight and select a style; Save & Continue; verify processed twin and Home.

**Expected behavior:** Process body photo, save positive metrics/style/twin references, then open Home.

**Screenshot timing:** After successful creation and when the processed twin is visible. **Save as:** `testing_evidence/screenshots/UC-03/TC-007_digital_twin_created.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>` fields height, weight, stylePreferences, twinId, isProfileComplete; Storage `users/<testUid>/digital_twin_processed.jpg`; authorized `/v1/twins` response and isolated AI_DATA_DIR twins/<testUid>/<twinId>. Save redacted metadata/status only in `logs/firebase` and `logs/fastapi`.

**Existing evidence/remaining gap:** Existing fake photo pipeline saved four temporary artifacts at 768x1024; metric helpers pass. No real models/Firebase profile save executed. See [TC-007 automated evidence](../logs/integration/TC-007_evidence.json).

## TC-008 — Submit incomplete body details (UC-03)

**Current original-scenario status:** PASS. **Test data:** First no photo; then valid test photo with height blank; repeat missing weight/style manually.

**Steps:** Tap Save & Continue without photo; then select valid photo and clear height; repeat with missing weight and no styles; verify notices and no profile completion.

**Expected behavior:** Reject missing photo or incomplete metrics before file, API, or Firebase work.

**Screenshot timing:** At each validation notice; append _missing_weight/_missing_style for further variants. **Save as:** `testing_evidence/screenshots/UC-03/TC-008_incomplete_twin.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>` fields height, weight, stylePreferences, twinId, isProfileComplete; Storage `users/<testUid>/digital_twin_processed.jpg`; authorized `/v1/twins` response and isolated AI_DATA_DIR twins/<testUid>/<twinId>. Save redacted metadata/status only in `logs/firebase` and `logs/fastapi`.

**Existing evidence/remaining gap:** Widget rejected absent photo; controller rejected empty height even with an image reference. Existing helper tests reject empty/nonfinite/nonpositive values. Local negative scope only. See [TC-008 automated evidence](../logs/integration/TC-008_evidence.json).

## TC-009 — Retrieve saved Digital Twin (UC-03)

**Current original-scenario status:** BLOCKED. **Test data:** Dedicated test user with saved twin and another test user for isolation.

**Steps:** Create a twin in test environment; close/reopen app; open Virtual Twin from Profile; verify correct processed photo; compare a second test account.

**Expected behavior:** Retrieve the signed-in user's saved processed twin or documented Firebase photo fallback.

**Screenshot timing:** When the reopened twin is visible. **Save as:** `testing_evidence/screenshots/UC-03/TC-009_saved_twin_retrieved.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>` fields height, weight, stylePreferences, twinId, isProfileComplete; Storage `users/<testUid>/digital_twin_processed.jpg`; authorized `/v1/twins` response and isolated AI_DATA_DIR twins/<testUid>/<twinId>. Save redacted metadata/status only in `logs/firebase` and `logs/fastapi`.

**Existing evidence/remaining gap:** Temporary-store list tests returned newest-first owned twins; no mobile retrieval or persisted Firebase photo fallback was executed. See [TC-009 automated evidence](../logs/integration/TC-009_evidence.json).

## TC-010 — Upload clothing image from gallery (UC-04)

**Current original-scenario status:** BLOCKED. **Test data:** Test garment photo >=256 pixels on each side; signed-in test user.

**Steps:** On Home expand add categories; choose Tops; choose the custom photo tile; Choose from gallery; select garment; wait for closet refresh.

**Expected behavior:** Process selected clothing, store image and clothes record, and refresh closet.

**Screenshot timing:** When the processed item appears in the correct closet category. **Save as:** `testing_evidence/screenshots/UC-04/TC-010_gallery_clothing_uploaded.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Wardrobe API processed synthetic image using FakeEngine; link recovery tests pass. OS gallery and Firebase upload were not exercised. See [TC-010 automated evidence](../logs/integration/TC-010_evidence.json).

## TC-011 — Capture clothing image using camera (UC-04)

**Current original-scenario status:** BLOCKED. **Test data:** Android camera/emulator camera input; well-lit test garment.

**Steps:** Choose a closet category; open custom photo source; Take a photo; allow camera access; capture and accept garment photo; wait for added item.

**Expected behavior:** Open permitted camera, accept captured photo, and add processed item.

**Screenshot timing:** After capture acceptance and after item appears; use _camera for the capture screen. **Save as:** `testing_evidence/screenshots/UC-04/TC-011_camera_clothing_uploaded.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Camera source wiring was found in code; no connected Android device and no camera capture executed. See [TC-011 automated evidence](../logs/integration/TC-011_evidence.json).

## TC-012 — Cancel clothing image selection (UC-04)

**Current original-scenario status:** BLOCKED. **Test data:** Existing test closet; record initial count.

**Steps:** Choose category/custom photo; open gallery then press Android Back; repeat camera cancellation; verify closet count and service records unchanged.

**Expected behavior:** Return safely without new clothing, storage object, or processing request.

**Screenshot timing:** After returning to unchanged closet. **Save as:** `testing_evidence/screenshots/UC-04/TC-012_clothing_selection_cancelled.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Code returns when picker result is null; clothing cancellation was not executed because ClosetController initializes live Firebase singletons. See [TC-012 automated evidence](../logs/integration/TC-012_evidence.json).

## TC-013 — Assign clothing category (UC-05)

**Current original-scenario status:** BLOCKED. **Test data:** Distinct Tops/Pants/Skirts test images; same test user.

**Steps:** Select Tops before custom upload; choose top image; verify stored category. Repeat Pants/Skirts with matching images; inspect metadata.

**Expected behavior:** Use category chosen before upload and persist matching category/item reference.

**Screenshot timing:** When each processed garment is shown under its category. **Save as:** `testing_evidence/screenshots/UC-05/TC-013_category_assigned.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** API category assignment/style checks pass; missing category returns 422 and saves nothing. Mobile category-first flow and Firebase persistence unverified. See [TC-013 automated evidence](../logs/integration/TC-013_evidence.json).

## TC-014 — Change clothing category (UC-05)

**Current original-scenario status:** NOT RUN. **Test data:** Existing test item; alternate category.

**Steps:** Inspect existing item actions for category edit and record absence. For proposed case, open Tops sheet, dismiss, open Pants sheet, then upload a Pants test image.

**Expected behavior:** Original: edit saved item category. Proposed: dismiss and choose another category before upload.

**Screenshot timing:** Capture available actions for original; for revised flow capture the final chosen category. **Save as:** `testing_evidence/screenshots/UC-05/TC-014_category_change_scope_gap.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** No saved-item category editing operation was found in UI/controller or FastAPI routes. Proposed pre-upload replacement was not executed. See [TC-014 automated evidence](../logs/integration/TC-014_evidence.json).

## TC-015 — Cancel categorization (UC-05)

**Current original-scenario status:** BLOCKED. **Test data:** Unchanged test closet; starting document count.

**Steps:** Expand add categories; open Tops sheet; dismiss using Back/outside tap before selecting an item; verify count and service writes unchanged.

**Expected behavior:** Dismiss category selection without saving or processing an item.

**Screenshot timing:** After dismissal with the unchanged closet visible. **Save as:** `testing_evidence/screenshots/UC-05/TC-015_categorization_cancelled.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Category selection is a bottom sheet before upload; no separate categorization transaction. Dismissal behavior was not executed. See [TC-015 automated evidence](../logs/integration/TC-015_evidence.json).

## TC-016 — Generate Virtual Try-On image (UC-06)

**Current original-scenario status:** BLOCKED. **Test data:** Saved test twin; linked top and pants; authorized hosted AI key/credits.

**Steps:** Open Virtual Try-On; select twin and test garments; choose mode; inspect confirmation including cost requirement; confirm once; wait for result; assess identity, garment fidelity and errors.

**Expected behavior:** Confirm mode/cost, generate selected outfit on owned twin, display resulting image.

**Screenshot timing:** Capture confirmation as _confirmation, then final result without personal data. **Save as:** `testing_evidence/screenshots/UC-06/TC-016_virtual_tryon_success.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Fake API generation/composition and provider payload tests pass. Six existing confirmation-widget tests fail because credit totals are absent. No live AI generation executed. See [TC-016 automated evidence](../logs/integration/TC-016_evidence.json).

## TC-017 — Change clothing selection before generation (UC-06)

**Current original-scenario status:** BLOCKED. **Test data:** Two visibly different linked test tops and one twin.

**Steps:** Open try-on; select top A then top B before Generate; verify highlight; confirm once; inspect request IDs and result for B only.

**Expected behavior:** Generate only the final selected item IDs, without an earlier unconfirmed request.

**Screenshot timing:** After changing selection and after result; append _result. **Save as:** `testing_evidence/screenshots/UC-06/TC-017_tryon_selection_changed.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Existing HTTP mock asserts a fixed item list, not UI selection changes. No running selection flow executed. See [TC-017 automated evidence](../logs/integration/TC-017_evidence.json).

## TC-018 — Attempt Virtual Try-On without Digital Twin (UC-06)

**Current original-scenario status:** BLOCKED. **Test data:** Dedicated test user with clothes but no saved twin.

**Steps:** Open Virtual Try-On as no-twin test user; verify Create digital twin prompt and disabled Generate; do not delete an existing production twin to create this condition.

**Expected behavior:** Disable generation with setup guidance; reject unknown twin in API.

**Screenshot timing:** With setup guidance and disabled Generate visible. **Save as:** `testing_evidence/screenshots/UC-06/TC-018_tryon_without_twin.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** API returned 404 TWIN_NOT_FOUND for an unknown twin with a fake engine. VTON empty-twin UI was not executed. See [TC-018 automated evidence](../logs/integration/TC-018_evidence.json).

## TC-019 — Save generated outfit (UC-07)

**Current original-scenario status:** BLOCKED. **Test data:** Unsaved generated result in test account.

**Steps:** Generate test result; record likedOutfits count; Save Outfit once; open My Outfits; reopen saved image and verify source/title and count +1.

**Expected behavior:** Upload generated image and add exactly one likedOutfits record, visible in My Outfits.

**Screenshot timing:** After Save changes to Saved and in My Outfits; append _gallery. **Save as:** `testing_evidence/screenshots/UC-07/TC-019_outfit_saved.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** OutfitDraft injected persistence callback and backend temporary result persistence passed. Neither proves actual Firebase saving. See [TC-019 automated evidence](../logs/integration/TC-019_evidence.json).

## TC-020 — Cancel saving (UC-07)

**Current original-scenario status:** NOT RUN. **Test data:** Fresh generated result not yet saved; record likedOutfits count.

**Steps:** Record absence of a cancel-save dialog. For revised case, generate result, navigate Back without tapping Save, then inspect My Outfits and Firebase count.

**Expected behavior:** Original: cancel save dialog. Proposed: leave without tapping Save, with no likedOutfits write.

**Screenshot timing:** Before leaving and after returning to My Outfits; append _gallery. **Save as:** `testing_evidence/screenshots/UC-07/TC-020_outfit_left_unsaved.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Save acts immediately; no cancel-save dialog exists. Leaving unsaved does not remove the backend generation result already persisted. See [TC-020 automated evidence](../logs/integration/TC-020_evidence.json).

## TC-021 — Save an already saved outfit (UC-07)

**Current original-scenario status:** BLOCKED. **Test data:** One unsaved result; initial test likedOutfits count.

**Steps:** Rapidly double-tap Save Outfit once; wait for Saved; try tapping again; compare likedOutfits count and matching storage object count; expect +1 for this draft.

**Expected behavior:** Repeated taps on the current saved draft do not create duplicate uploads/documents.

**Screenshot timing:** With Saved button disabled and one gallery entry. **Save as:** `testing_evidence/screenshots/UC-07/TC-021_duplicate_save_prevented.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Draft test proves one injected persist call across concurrent and repeated saves. Cross-session/content-hash deduplication is not implemented or claimed. See [TC-021 automated evidence](../logs/integration/TC-021_evidence.json).

## TC-022 — Upload valid inspiration image (UC-08)

**Current original-scenario status:** BLOCKED. **Test data:** Consented fully clothed full-body reference JPEG >=320x640; saved twin.

**Steps:** Open AI Inspo Mirror; Upload inspiration photo; select test image; verify preview and no generation; then confirm Generate on my twin to test actual upload.

**Expected behavior:** Preview selected image locally; upload only on confirmed generation with a saved twin.

**Screenshot timing:** At local preview; capture generated result separately under TC-025. **Save as:** `testing_evidence/screenshots/UC-08/TC-022_inspiration_uploaded.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Multipart mock and fake inspo endpoint pass. Selection is local; standalone upload is not an API operation. See [TC-022 automated evidence](../logs/integration/TC-022_evidence.json).

## TC-023 — Upload unsupported image format (UC-08)

**Current original-scenario status:** BLOCKED. **Test data:** Safe reference.svg containing only a rectangle, plus test twin.

**Steps:** Try selecting SVG through gallery if visible; record picker exclusion if applicable. Use isolated test API SVG case for server rejection; do not relabel a JPEG extension as proof of format rejection.

**Expected behavior:** Reject undecodable/unsupported reference before provider call or result persistence.

**Screenshot timing:** At picker exclusion/error notice; record API-only evidence if OS excludes SVG. **Save as:** `testing_evidence/screenshots/UC-08/TC-023_unsupported_inspiration.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Real in-process API rejected SVG with 400 INVALID_IMAGE and zero fake-provider calls. Device picker support/rejection remains unexecuted; no strict extension allowlist exists. See [TC-023 automated evidence](../logs/integration/TC-023_evidence.json).

## TC-024 — Cancel image selection (UC-08)

**Current original-scenario status:** BLOCKED. **Test data:** Inspo screen with no reference; optionally repeat with an existing reference.

**Steps:** Tap Upload inspiration photo; cancel Android gallery; verify empty preview. Repeat Change inspiration photo then cancel and verify old preview remains.

**Expected behavior:** Cancel OS gallery without changing reference or starting generation.

**Screenshot timing:** After gallery closes and prior selection remains unchanged. **Save as:** `testing_evidence/screenshots/UC-08/TC-024_inspiration_selection_cancelled.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Mocked picker returned null; widget retained empty selection and issued no generation. Actual Android picker cancellation was not executed. See [TC-024 automated evidence](../logs/integration/TC-024_evidence.json).

## TC-025 — Apply inspiration style to Digital Twin (UC-09)

**Current original-scenario status:** BLOCKED. **Test data:** Saved test twin and clear reference; authorized AI service/credits.

**Steps:** Choose reference and twin; inspect mode/confirmation; generate once; compare outfit and identity with permitted source images; record visual defects and returned metadata.

**Expected behavior:** Transfer visible reference outfit to selected twin, preserving expected identity and returning a usable image.

**Screenshot timing:** When final image and selected twin/reference context are visible. **Save as:** `testing_evidence/screenshots/UC-09/TC-025_inspiration_style_applied.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Fake provider returned JPEG and metadata; mocked hosted payload contains identity prompt. Real style/identity/garment quality was not measured. See [TC-025 automated evidence](../logs/integration/TC-025_evidence.json).

## TC-026 — Apply style without Digital Twin (UC-09)

**Current original-scenario status:** BLOCKED. **Test data:** Dedicated no-twin test user and valid inspiration image.

**Steps:** Open Inspo Mirror as no-twin user; select valid image; verify Create or edit twin guidance and disabled Generate; inspect zero generation requests.

**Expected behavior:** Show setup guidance/disabled Generate; API rejects absent or other-user twin before provider.

**Screenshot timing:** With selected reference, setup guidance and disabled Generate. **Save as:** `testing_evidence/screenshots/UC-09/TC-026_inspiration_without_twin.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Existing fake UI disabled Generate for empty twins; added API test returned 404 for absent twin, zero provider calls and no result directory. Real account flow unverified. See [TC-026 automated evidence](../logs/integration/TC-026_evidence.json).

## TC-027 — Process an unsuitable inspiration image (UC-09)

**Current original-scenario status:** BLOCKED. **Test data:** Tiny 120x160 JPEG; blank 600x800 JPEG; safe non-person scene.

**Steps:** Run isolated tiny/blank tests first. For real non-person image, agree rejection/quality criteria before any paid request; then submit once in approved test environment and record actual provider behavior.

**Expected behavior:** Reject malformed/undersized inputs locally; define desired handling for valid-sized non-outfit scenes.

**Screenshot timing:** At the actual rejection or returned result; never label blank fake output as real AI evidence. **Save as:** `testing_evidence/screenshots/UC-09/TC-027_unsuitable_inspiration.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Tiny reference returned 400 before provider. Valid-sized flat blank JPEG returned 201 and called fake provider once. Semantic suitability is not checked locally; real provider response and acceptance criteria remain unresolved. See [TC-027 automated evidence](../logs/integration/TC-027_evidence.json).

## TC-028 — Schedule outfit for selected date (UC-10)

**Current original-scenario status:** BLOCKED. **Test data:** Two closet items; future date D = tomorrow, time 08:00; notifications allowed.

**Steps:** Open Outfit Planner; Select a date to plan an outfit; choose D; choose 08:00; select two items; Save Outfit; verify upcoming card and notification schedule status.

**Expected behavior:** Save closet items for a future local date/time and report actual reminder scheduling status.

**Screenshot timing:** After Outfit planned notice and dated card appear. **Save as:** `testing_evidence/screenshots/UC-10/TC-028_outfit_scheduled.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Model and mocked notification tests pass, including Kuala Lumpur time and permission fallbacks. No Firestore plan save or Android alarm delivery executed. See [TC-028 automated evidence](../logs/integration/TC-028_evidence.json).

## TC-029 — Change selected date (UC-10)

**Current original-scenario status:** BLOCKED. **Test data:** Future dates D and D+1; two different test closet items.

**Steps:** Open date picker; tap D then D+1 before OK; choose future time/items; Save; verify only D+1 gained a plan. Do not interpret replanning as moving an existing record.

**Expected behavior:** Use final chosen date before commit. Moving an already saved plan has no dedicated action.

**Screenshot timing:** At final highlighted date and saved dated card; append _saved. **Save as:** `testing_evidence/screenshots/UC-10/TC-029_schedule_date_changed.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Date/time picker and one-document-per-date save inspected; no date-change interaction executed. See [TC-029 automated evidence](../logs/integration/TC-029_evidence.json).

## TC-030 — Cancel outfit scheduling (UC-10)

**Current original-scenario status:** BLOCKED. **Test data:** Baseline test plan document count and pending alarm list.

**Steps:** Open planning then cancel date picker; repeat choosing date then cancel time picker; repeat date/time then dismiss item sheet; verify no added plan/alarm after each variant.

**Expected behavior:** Cancel date picker, time picker, or item sheet without saving a plan or alarm.

**Screenshot timing:** After each cancellation returns to unchanged Upcoming Outfits; suffix _date/_time/_items. **Save as:** `testing_evidence/screenshots/UC-10/TC-030_scheduling_cancelled.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Null date/time returns and sheet-before-save sequence inspected; no UI cancellation was executed. See [TC-030 automated evidence](../logs/integration/TC-030_evidence.json).

## TC-031 — View scheduled outfit (UC-11)

**Current original-scenario status:** BLOCKED. **Test data:** Previously scheduled future D plan and permitted past test plan.

**Steps:** Open Outfit Planner; locate D card; verify date, time and selected thumbnails; open My Outfits to inspect past planner record after expiry.

**Expected behavior:** Show upcoming dated card and its closet-item thumbnails; past plan remains in My Outfits.

**Screenshot timing:** With date/time and all intended item thumbnails visible. **Save as:** `testing_evidence/screenshots/UC-11/TC-031_planned_outfit_viewed.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Upcoming/legacy expiry and gallery conversion unit checks pass; preview renders item collage. No real plan stream displayed. See [TC-031 automated evidence](../logs/integration/TC-031_evidence.json).

## TC-032 — View date with no scheduled outfit (UC-11)

**Current original-scenario status:** NOT RUN. **Test data:** Dedicated account with no upcoming test plans; avoid deleting production plans.

**Steps:** Record that daily-date selection is unavailable. For revised case, open Outfit Planner with no upcoming plans and verify No upcoming outfits message.

**Expected behavior:** Original: daily-date empty state. Proposed: empty Upcoming Outfits list.

**Screenshot timing:** With the actual empty upcoming-list message visible. **Save as:** `testing_evidence/screenshots/UC-11/TC-032_no_planned_outfit.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Planner has no selected-day viewing/calendar control. Empty-list text is implemented, but original daily-date flow is unavailable and not executed. See [TC-032 automated evidence](../logs/integration/TC-032_evidence.json).

## TC-033 — Switch between planned dates (UC-11)

**Current original-scenario status:** NOT RUN. **Test data:** Two scheduled test plans on D and D+1 with visibly different items.

**Steps:** Record absence of daily navigation; for revised case, scroll dated upcoming cards then use Previous/Next outfit in My Outfits detail; verify date/items remain paired.

**Expected behavior:** Original: daily calendar navigation. Proposed: inspect multiple dated upcoming cards or browse saved planner pages.

**Screenshot timing:** Capture each dated card or detail page with date/source visible; suffix _D/_Dplus1. **Save as:** `testing_evidence/screenshots/UC-11/TC-033_planned_dates_browsed.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** No daily calendar selector exists. Multiple list cards and My Outfits page browsing are available; revised behavior not executed. See [TC-033 automated evidence](../logs/integration/TC-033_evidence.json).

## TC-034 — Display outfit on Digital Twin (UC-12)

**Current original-scenario status:** BLOCKED. **Test data:** One generated result, one saved result, one planner collage and a test twin.

**Steps:** Generate an outfit on the test twin; inspect the result; Save Outfit; reopen the image in My Outfits and compare it with the result. View a planner collage separately. If the requirement means applying a planner outfit to a twin, record absence of that action and clarify scope.

**Expected behavior:** Display the generated outfit-on-twin image and reopen its saved result; planner item collage remains distinct.

**Screenshot timing:** Capture generated result and reopened saved result; append _saved. **Save as:** `testing_evidence/screenshots/UC-12/TC-034_outfit_on_twin_displayed.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** VTON/Inspo result display and saved-image viewer exist in source; fake try-on returns image data. No complete result display executed. If this means dressing a twin from a saved planner outfit, that separate operation is absent and needs clarification. See [TC-034 automated evidence](../logs/integration/TC-034_evidence.json).

## TC-035 — Display outfit without Digital Twin (UC-12)

**Current original-scenario status:** BLOCKED. **Test data:** No-twin test account for generation guard; approved pre-existing saved image for independent viewing.

**Steps:** Open Virtual Twin as a no-twin test user and verify No virtual twin yet/Create Twin; inspect VTON/Inspo setup guidance. If testing independent saved-image viewing, use an approved seeded image in the no-twin account and open My Outfits; record the entry point. Do not delete a production twin.

**Expected behavior:** Show create-twin guidance before generation; viewing an existing saved image can remain independent of a current twin.

**Screenshot timing:** Capture actual empty-twin/setup state and, if required, independent saved-image view. **Save as:** `testing_evidence/screenshots/UC-12/TC-035_display_without_twin.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Isolated no-twin generation guards pass; Virtual Twin empty state exists in source. Full no-twin viewer/navigation behavior was not executed. The intended display entry point needs confirmation before accepting this scenario. See [TC-035 automated evidence](../logs/integration/TC-035_evidence.json).

## TC-036 — Display unavailable outfit (UC-12)

**Current original-scenario status:** BLOCKED. **Test data:** Dedicated test fixture with missing image URL and a separate safe nonexistent storage object.

**Steps:** Open approved missing-image test outfit in My Outfits thumbnail/detail; verify fallback and navigation remain usable; repeat offline/missing remote object without deleting real media.

**Expected behavior:** Show a safe missing-image state for absent/unavailable saved outfit image, with no crash.

**Screenshot timing:** At thumbnail fallback and detail error message; suffix _detail. **Save as:** `testing_evidence/screenshots/UC-12/TC-036_unavailable_outfit.png`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

**Existing evidence/remaining gap:** Two added widget tests passed for missing generated-image URL: thumbnail icon and readable detail message. Missing remote object/document and Android full viewer not exercised. See [TC-036 automated evidence](../logs/integration/TC-036_evidence.json).


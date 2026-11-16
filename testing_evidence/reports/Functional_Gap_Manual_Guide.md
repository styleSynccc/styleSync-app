# StyleSync remaining manual and integration execution guide

These procedures are not executed test results. The 39 newly added isolated tests passed; the native Android and live-service behaviors below still require evidence. See the coverage matrix for the current automated outcomes and the exact passing test nodes.

## Prepare the environment

Use an approved dedicated Firebase test project or isolated Auth/Firestore/Storage emulators and synthetic/consented images. Existing Firebase wiring uses configured project options; changes to application code, dependencies, settings or security rules still need explicit approval. This work made none. Never create/delete production accounts, photos or plans to construct test conditions.

Connect an Android emulator/phone and run `adb devices -l`. Record device model, Android version, build revision and local time in Asia/Kuala_Lumpur. Configure the approved test build to reach the isolated AI service via its actual address; Android emulator host access commonly uses 10.0.2.2. Keep AI_DATA_DIR separate from existing data. Real models/extraction services and approved hosted AI credentials/credits are necessary only for live processing/generation cases. Do not log or screenshot passwords, bearer tokens, API keys, full image base64 or private tokenized image URLs.

Create test-user aliases QA-New, QA-Ready, QA-Incomplete and QA-NoTwin only in the dedicated environment. Keep their actual credentials privately. Use a clear full-body photo at least 320x640, clothing images at least 256x256, two distinct test tops, a clear fully clothed inspiration subject, tiny 120x160 JPEG, safe SVG and a valid-sized blank/non-person reference. Select future local reminder dates; recalculate them when the guide is executed. For real AI requests, confirm the approved budget, submit once and preserve the response rather than blindly retrying.

## Record each outcome

Save redacted execution notes under `testing_evidence/logs/integration/TC-NNN_manual.md`. Include test data alias, setup, exact steps, expected and observed behavior, PASS/FAIL/BLOCKED/NOT RUN, local timestamp and screenshot/log paths. For cancellation, compare before/after document/object counts and API requests. A success snackbar alone is not evidence of persistence. Use the planned screenshot filenames below; they are not proof of execution until the files are captured. Existing `_widget.png` files are earlier widget captures, not Android screenshots.

## TC-001 — Register with valid details

**Manual/integration requirement:** MANUAL / isolated integration: real Auth account creation, Firestore profile persistence and routing.

**Test data:** New unique test email, username QA Student, permitted gender, strong synthetic password.

**Execution:**

1. Open Sign Up
2. enter username/email
3. choose gender
4. enter password
5. tap Sign Up
6. verify setup page and one matching Auth user/profile.

**Expected behavior:** Create an Auth user, save profile, and route to setup.

**Capture:** After setup opens and the account-created notice appears. Save under `testing_evidence/screenshots/UC-01/TC-001_registration_success.png`; suffix additional variants.

**Supporting service evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

## TC-002 — Submit empty required fields

**Manual/integration requirement:** Local validation automated; confirm small-screen/keyboard layout on Android.

**Test data:** Leave username, email, gender and password unset.

**Execution:**

1. Open Sign Up
2. leave all inputs blank
3. tap Sign Up
4. inspect all four validation messages.

**Expected behavior:** Show all required field errors and send no registration call.

**Capture:** With all validation errors visible. Save under `testing_evidence/screenshots/UC-01/TC-002_empty_signup.png`; suffix additional variants.

**Supporting service evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

## TC-003 — Register using an existing email

**Manual/integration requirement:** MANUAL / isolated integration: real duplicate email rejection and unchanged account count; existing fake-error test reused.

**Test data:** Email already present in the dedicated test Auth project; synthetic signup details.

**Execution:**

1. Record initial test Auth user count
2. submit Sign Up using the existing email and otherwise valid fields
3. verify error and unchanged count.

**Expected behavior:** Show existing-email error and create no duplicate account.

**Capture:** While the Firebase error notice is visible. Save under `testing_evidence/screenshots/UC-01/TC-003_existing_email.png`; suffix additional variants.

**Supporting service evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

## TC-004 — Login using valid credentials

**Manual/integration requirement:** MANUAL / isolated integration: real credentials/session and completed/incomplete-profile destinations.

**Test data:** Dedicated test account with known credentials and completed profile; repeat with incomplete profile.

**Execution:**

1. Log out of the test app
2. open Login
3. enter valid test credentials
4. tap Login
5. verify correct destination for each profile state.

**Expected behavior:** Authenticate and route to Home for a completed profile, otherwise setup.

**Capture:** After the expected destination loads. Save under `testing_evidence/screenshots/UC-02/TC-004_login_success.png`; suffix additional variants.

**Supporting service evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

## TC-005 — Login using incorrect password

**Manual/integration requirement:** MANUAL / isolated integration: real wrong-password error and signed-out state; existing fake-error test reused.

**Test data:** Known test account email; deliberately wrong synthetic password.

**Execution:**

1. Start signed out
2. enter the test email and wrong password
3. tap Login
4. verify error, no destination change, and no active session.

**Expected behavior:** Show authentication error, stop loading, and stay signed out.

**Capture:** While the error notice is visible; keep the password obscured. Save under `testing_evidence/screenshots/UC-02/TC-005_invalid_password.png`; suffix additional variants.

**Supporting service evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

## TC-006 — Login using empty fields

**Manual/integration requirement:** Local validation automated; confirm keyboard/field behavior on Android.

**Test data:** Empty email and password.

**Execution:**

1. Open Login
2. leave both fields blank
3. tap Login
4. verify both required messages.

**Expected behavior:** Show email/password required errors and send no login call.

**Capture:** With both required messages visible. Save under `testing_evidence/screenshots/UC-02/TC-006_empty_login.png`; suffix additional variants.

**Supporting service evidence:** Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.

## TC-007 — Create Digital Twin with valid body details

**Manual/integration requirement:** MANUAL / isolated integration: real pose/background-removal models and Firebase uploads/profile.

**Test data:** Consented synthetic/test full-body JPEG >=320x640; height 170, weight 65.5, Casual.

**Execution:**

1. Open twin setup
2. choose clear standing full-body photo
3. enter height/weight and select a style
4. Save & Continue
5. verify processed twin and Home.

**Expected behavior:** Process body photo, save positive metrics/style/twin references, then open Home.

**Capture:** After successful creation and when the processed twin is visible. Save under `testing_evidence/screenshots/UC-03/TC-007_digital_twin_created.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>` fields height, weight, stylePreferences, twinId, isProfileComplete; Storage `users/<testUid>/digital_twin_processed.jpg`; authorized `/v1/twins` response and isolated AI_DATA_DIR twins/<testUid>/<twinId>. Save redacted metadata/status only in `logs/firebase` and `logs/fastapi`.

## TC-008 — Submit incomplete body details

**Manual/integration requirement:** Missing photo/height/weight/styles and metric validation automated; confirm on-device notices.

**Test data:** First no photo; then valid test photo with height blank; repeat missing weight/style manually.

**Execution:**

1. Tap Save & Continue without photo
2. then select valid photo and clear height
3. repeat with missing weight and no styles
4. verify notices and no profile completion.

**Expected behavior:** Reject missing photo or incomplete metrics before file, API, or Firebase work.

**Capture:** At each validation notice; append _missing_weight/_missing_style for further variants. Save under `testing_evidence/screenshots/UC-03/TC-008_incomplete_twin.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>` fields height, weight, stylePreferences, twinId, isProfileComplete; Storage `users/<testUid>/digital_twin_processed.jpg`; authorized `/v1/twins` response and isolated AI_DATA_DIR twins/<testUid>/<twinId>. Save redacted metadata/status only in `logs/firebase` and `logs/fastapi`.

## TC-009 — Retrieve saved Digital Twin

**Manual/integration requirement:** MANUAL / isolated integration: real user session, device reopen/retrieval and backend-offline Firebase-photo fallback.

**Test data:** Dedicated test user with saved twin and another test user for isolation.

**Execution:**

1. Create a twin in test environment
2. close/reopen app
3. open Virtual Twin from Profile
4. verify correct processed photo
5. compare a second test account.

**Expected behavior:** Retrieve the signed-in user's saved processed twin or documented Firebase photo fallback.

**Capture:** When the reopened twin is visible. Save under `testing_evidence/screenshots/UC-03/TC-009_saved_twin_retrieved.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>` fields height, weight, stylePreferences, twinId, isProfileComplete; Storage `users/<testUid>/digital_twin_processed.jpg`; authorized `/v1/twins` response and isolated AI_DATA_DIR twins/<testUid>/<twinId>. Save redacted metadata/status only in `logs/firebase` and `logs/fastapi`.

## TC-010 — Upload clothing image from gallery

**Manual/integration requirement:** MANUAL: native gallery and real service upload; controller path and API restart persistence now automated.

**Test data:** Test garment photo >=256 pixels on each side; signed-in test user.

**Execution:**

1. On Home expand add categories
2. choose Tops
3. choose the custom photo tile
4. Choose from gallery
5. select garment
6. wait for closet refresh.

**Expected behavior:** Process selected clothing, store image and clothes record, and refresh closet.

**Capture:** When the processed item appears in the correct closet category. Save under `testing_evidence/screenshots/UC-04/TC-010_gallery_clothing_uploaded.png`; suffix additional variants.

**Supporting service evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

## TC-011 — Capture clothing image using camera

**Manual/integration requirement:** MANUAL: camera permission, physical capture and acceptance; source selection/controller upload now automated with picker mock.

**Test data:** Android camera/emulator camera input; well-lit test garment.

**Execution:**

1. Choose a closet category
2. open custom photo source
3. Take a photo
4. allow camera access
5. capture and accept garment photo
6. wait for added item.

**Expected behavior:** Open permitted camera, accept captured photo, and add processed item.

**Capture:** After capture acceptance and after item appears; use _camera for the capture screen. Save under `testing_evidence/screenshots/UC-04/TC-011_camera_clothing_uploaded.png`; suffix additional variants.

**Supporting service evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

## TC-012 — Cancel clothing image selection

**Manual/integration requirement:** MANUAL: native gallery/camera Back gestures; null-picker no-write business behavior now automated.

**Test data:** Existing test closet; record initial count.

**Execution:**

1. Choose category/custom photo
2. open gallery then press Android Back
3. repeat camera cancellation
4. verify closet count and service records unchanged.

**Expected behavior:** Return safely without new clothing, storage object, or processing request.

**Capture:** After returning to unchanged closet. Save under `testing_evidence/screenshots/UC-04/TC-012_clothing_selection_cancelled.png`; suffix additional variants.

**Supporting service evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

## TC-013 — Assign clothing category

**Manual/integration requirement:** MANUAL / isolated integration: category-first upload across real Firebase/backend; controller category persistence automated.

**Test data:** Distinct Tops/Pants/Skirts test images; same test user.

**Execution:**

1. Select Tops before custom upload
2. choose top image
3. verify stored category. Repeat Pants/Skirts with matching images
4. inspect metadata.

**Expected behavior:** Use category chosen before upload and persist matching category/item reference.

**Capture:** When each processed garment is shown under its category. Save under `testing_evidence/screenshots/UC-05/TC-013_category_assigned.png`; suffix additional variants.

**Supporting service evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

## TC-014 — Change clothing category

**Manual/integration requirement:** REQUIREMENT GAP: no saved category editor. Only the explicitly revised pre-upload category-selection interaction is automated.

**Test data:** Existing test item; alternate category.

**Execution:**

1. Inspect existing item actions for category edit and record absence. For proposed case, open Tops sheet, dismiss, open Pants sheet, then upload a Pants test image.

**Expected behavior:** Original: edit saved item category. Proposed: dismiss and choose another category before upload.

**Capture:** Capture available actions for original; for revised flow capture the final chosen category. Save under `testing_evidence/screenshots/UC-05/TC-014_category_change_scope_gap.png`; suffix additional variants.

**Supporting service evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

**Literal original scenario:** NOT RUN / requirement gap. Inspect available actions and record the absence. The revised local interaction has automated evidence but does not establish acceptance of the original requirement.

## TC-015 — Cancel categorization

**Manual/integration requirement:** Category-sheet dismissal automated; native navigation/layout confirmation remains manual.

**Test data:** Unchanged test closet; starting document count.

**Execution:**

1. Expand add categories
2. open Tops sheet
3. dismiss using Back/outside tap before selecting an item
4. verify count and service writes unchanged.

**Expected behavior:** Dismiss category selection without saving or processing an item.

**Capture:** After dismissal with the unchanged closet visible. Save under `testing_evidence/screenshots/UC-05/TC-015_categorization_cancelled.png`; suffix additional variants.

**Supporting service evidence:** Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.

## TC-016 — Generate Virtual Try-On image

**Manual/integration requirement:** MANUAL: real AI image/identity/garment quality; existing six credit-confirmation assertions still fail and need approved resolution.

**Test data:** Saved test twin; linked top and pants; authorized hosted AI key/credits.

**Execution:**

1. Open Virtual Try-On
2. select twin and test garments
3. choose mode
4. inspect confirmation including cost requirement
5. confirm once
6. wait for result
7. assess identity, garment fidelity and errors.

**Expected behavior:** Confirm mode/cost, generate selected outfit on owned twin, display resulting image.

**Capture:** Capture confirmation as _confirmation, then final result without personal data. Save under `testing_evidence/screenshots/UC-06/TC-016_virtual_tryon_success.png`; suffix additional variants.

**Supporting service evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

## TC-017 — Change clothing selection before generation

**Manual/integration requirement:** Final garment request selection automated; real garment change in hosted AI output requires manual review.

**Test data:** Two visibly different linked test tops and one twin.

**Execution:**

1. Open try-on
2. select top A then top B before Generate
3. verify highlight
4. confirm once
5. inspect request IDs and result for B only.

**Expected behavior:** Generate only the final selected item IDs, without an earlier unconfirmed request.

**Capture:** After changing selection and after result; append _result. Save under `testing_evidence/screenshots/UC-06/TC-017_tryon_selection_changed.png`; suffix additional variants.

**Supporting service evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

## TC-018 — Attempt Virtual Try-On without Digital Twin

**Manual/integration requirement:** No-twin disabled VTON UI and API rejection automated; verify approved no-twin Android test account.

**Test data:** Dedicated test user with clothes but no saved twin.

**Execution:**

1. Open Virtual Try-On as no-twin test user
2. verify Create digital twin prompt and disabled Generate
3. do not delete an existing production twin to create this condition.

**Expected behavior:** Disable generation with setup guidance; reject unknown twin in API.

**Capture:** With setup guidance and disabled Generate visible. Save under `testing_evidence/screenshots/UC-06/TC-018_tryon_without_twin.png`; suffix additional variants.

**Supporting service evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

## TC-019 — Save generated outfit

**Manual/integration requirement:** Screen-to-storage/document-to-viewer save automated with Firebase fakes; real persistence/reopen requires integration.

**Test data:** Unsaved generated result in test account.

**Execution:**

1. Generate test result
2. record likedOutfits count
3. Save Outfit once
4. open My Outfits
5. reopen saved image and verify source/title and count +1.

**Expected behavior:** Upload generated image and add exactly one likedOutfits record, visible in My Outfits.

**Capture:** After Save changes to Saved and in My Outfits; append _gallery. Save under `testing_evidence/screenshots/UC-07/TC-019_outfit_saved.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

## TC-020 — Cancel saving

**Manual/integration requirement:** REQUIREMENT GAP: no cancel-save dialog. Revised leave-unsaved behavior is automated; backend result retention is separate.

**Test data:** Fresh generated result not yet saved; record likedOutfits count.

**Execution:**

1. Record absence of a cancel-save dialog. For revised case, generate result, navigate Back without tapping Save, then inspect My Outfits and Firebase count.

**Expected behavior:** Original: cancel save dialog. Proposed: leave without tapping Save, with no likedOutfits write.

**Capture:** Before leaving and after returning to My Outfits; append _gallery. Save under `testing_evidence/screenshots/UC-07/TC-020_outfit_left_unsaved.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

**Literal original scenario:** NOT RUN / requirement gap. Inspect available actions and record the absence. The revised local interaction has automated evidence but does not establish acceptance of the original requirement.

## TC-021 — Save an already saved outfit

**Manual/integration requirement:** Current-draft save locking and disabled Saved UI automated; verify real document/object count. Cross-session deduplication is not implemented.

**Test data:** One unsaved result; initial test likedOutfits count.

**Execution:**

1. Rapidly double-tap Save Outfit once
2. wait for Saved
3. try tapping again
4. compare likedOutfits count and matching storage object count
5. expect +1 for this draft.

**Expected behavior:** Repeated taps on the current saved draft do not create duplicate uploads/documents.

**Capture:** With Saved button disabled and one gallery entry. Save under `testing_evidence/screenshots/UC-07/TC-021_duplicate_save_prevented.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

## TC-022 — Upload valid inspiration image

**Manual/integration requirement:** Local preview/no-premature-upload automated; native picker and real multipart transfer require integration.

**Test data:** Consented fully clothed full-body reference JPEG >=320x640; saved twin.

**Execution:**

1. Open AI Inspo Mirror
2. Upload inspiration photo
3. select test image
4. verify preview and no generation
5. then confirm Generate on my twin to test actual upload.

**Expected behavior:** Preview selected image locally; upload only on confirmed generation with a saved twin.

**Capture:** At local preview; capture generated result separately under TC-025. Save under `testing_evidence/screenshots/UC-08/TC-022_inspiration_uploaded.png`; suffix additional variants.

**Supporting service evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

## TC-023 — Upload unsupported image format

**Manual/integration requirement:** Server SVG/malformed-input rejection already automated and reused; actual native picker format support/exclusion is manual.

**Test data:** Safe reference.svg containing only a rectangle, plus test twin.

**Execution:**

1. Try selecting SVG through gallery if visible
2. record picker exclusion if applicable. Use isolated test API SVG case for server rejection
3. do not relabel a JPEG extension as proof of format rejection.

**Expected behavior:** Reject undecodable/unsupported reference before provider call or result persistence.

**Capture:** At picker exclusion/error notice; record API-only evidence if OS excludes SVG. Save under `testing_evidence/screenshots/UC-08/TC-023_unsupported_inspiration.png`; suffix additional variants.

**Supporting service evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

## TC-024 — Cancel image selection

**Manual/integration requirement:** Both empty-selection and replacement cancellation automated at plugin boundary; native gallery Back is manual.

**Test data:** Inspo screen with no reference; optionally repeat with an existing reference.

**Execution:**

1. Tap Upload inspiration photo
2. cancel Android gallery
3. verify empty preview. Repeat Change inspiration photo then cancel and verify old preview remains.

**Expected behavior:** Cancel OS gallery without changing reference or starting generation.

**Capture:** After gallery closes and prior selection remains unchanged. Save under `testing_evidence/screenshots/UC-08/TC-024_inspiration_selection_cancelled.png`; suffix additional variants.

**Supporting service evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

## TC-025 — Apply inspiration style to Digital Twin

**Manual/integration requirement:** Selected twin/reference/result UI automated with fake provider; real outfit/identity fidelity and shared credit-disclosure issue remain.

**Test data:** Saved test twin and clear reference; authorized AI service/credits.

**Execution:**

1. Choose reference and twin
2. inspect mode/confirmation
3. generate once
4. compare outfit and identity with permitted source images
5. record visual defects and returned metadata.

**Expected behavior:** Transfer visible reference outfit to selected twin, preserving expected identity and returning a usable image.

**Capture:** When final image and selected twin/reference context are visible. Save under `testing_evidence/screenshots/UC-09/TC-025_inspiration_style_applied.png`; suffix additional variants.

**Supporting service evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

## TC-026 — Apply style without Digital Twin

**Manual/integration requirement:** Selected reference without a twin now automated; real account/device setup guidance confirmation remains.

**Test data:** Dedicated no-twin test user and valid inspiration image.

**Execution:**

1. Open Inspo Mirror as no-twin user
2. select valid image
3. verify Create or edit twin guidance and disabled Generate
4. inspect zero generation requests.

**Expected behavior:** Show setup guidance/disabled Generate; API rejects absent or other-user twin before provider.

**Capture:** With selected reference, setup guidance and disabled Generate. Save under `testing_evidence/screenshots/UC-09/TC-026_inspiration_without_twin.png`; suffix additional variants.

**Supporting service evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

## TC-027 — Process an unsuitable inspiration image

**Manual/integration requirement:** Malformed/undersized checks and mocked provider-error UI automated. Valid-size blank image still reaches provider; semantic suitability and real AI behavior require criteria/manual review.

**Test data:** Tiny 120x160 JPEG; blank 600x800 JPEG; safe non-person scene.

**Execution:**

1. Run isolated tiny/blank tests first. For real non-person image, agree rejection/quality criteria before any paid request
2. then submit once in approved test environment and record actual provider behavior.

**Expected behavior:** Reject malformed/undersized inputs locally; define desired handling for valid-sized non-outfit scenes.

**Capture:** At the actual rejection or returned result; never label blank fake output as real AI evidence. Save under `testing_evidence/screenshots/UC-09/TC-027_unsuitable_inspiration.png`; suffix additional variants.

**Supporting service evidence:** Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.

## TC-028 — Schedule outfit for selected date

**Manual/integration requirement:** Date/time/item selection, plan write, visible card and mocked alarm payload automated; real Firestore/Android alarm delivery remain manual.

**Test data:** Two closet items; future date D = tomorrow, time 08:00; notifications allowed.

**Execution:**

1. Open Outfit Planner
2. Select a date to plan an outfit
3. choose D
4. choose 08:00
5. select two items
6. Save Outfit
7. verify upcoming card and notification schedule status.

**Expected behavior:** Save closet items for a future local date/time and report actual reminder scheduling status.

**Capture:** After Outfit planned notice and dated card appear. Save under `testing_evidence/screenshots/UC-10/TC-028_outfit_scheduled.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

## TC-029 — Change selected date

**Manual/integration requirement:** Changing date before commit automated; no dedicated move-existing-plan action exists.

**Test data:** Future dates D and D+1; two different test closet items.

**Execution:**

1. Open date picker
2. tap D then D+1 before OK
3. choose future time/items
4. Save
5. verify only D+1 gained a plan. Do not interpret replanning as moving an existing record.

**Expected behavior:** Use final chosen date before commit. Moving an already saved plan has no dedicated action.

**Capture:** At final highlighted date and saved dated card; append _saved. Save under `testing_evidence/screenshots/UC-10/TC-029_schedule_date_changed.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

## TC-030 — Cancel outfit scheduling

**Manual/integration requirement:** Date/time/item cancellation and no-write/no-alarm assertions automated; confirm OS navigation/permission interaction manually.

**Test data:** Baseline test plan document count and pending alarm list.

**Execution:**

1. Open planning then cancel date picker
2. repeat choosing date then cancel time picker
3. repeat date/time then dismiss item sheet
4. verify no added plan/alarm after each variant.

**Expected behavior:** Cancel date picker, time picker, or item sheet without saving a plan or alarm.

**Capture:** After each cancellation returns to unchanged Upcoming Outfits; suffix _date/_time/_items. Save under `testing_evidence/screenshots/UC-10/TC-030_scheduling_cancelled.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

## TC-031 — View scheduled outfit

**Manual/integration requirement:** Upcoming plan cards/items now automated; real multi-session stream/reopen and actual reminder expiry require integration.

**Test data:** Previously scheduled future D plan and permitted past test plan.

**Execution:**

1. Open Outfit Planner
2. locate D card
3. verify date, time and selected thumbnails
4. open My Outfits to inspect past planner record after expiry.

**Expected behavior:** Show upcoming dated card and its closet-item thumbnails; past plan remains in My Outfits.

**Capture:** With date/time and all intended item thumbnails visible. Save under `testing_evidence/screenshots/UC-11/TC-031_planned_outfit_viewed.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

## TC-032 — View date with no scheduled outfit

**Manual/integration requirement:** REQUIREMENT GAP: no daily selected-date viewer. Revised empty-upcoming-list behavior automated.

**Test data:** Dedicated account with no upcoming test plans; avoid deleting production plans.

**Execution:**

1. Record that daily-date selection is unavailable. For revised case, open Outfit Planner with no upcoming plans and verify No upcoming outfits message.

**Expected behavior:** Original: daily-date empty state. Proposed: empty Upcoming Outfits list.

**Capture:** With the actual empty upcoming-list message visible. Save under `testing_evidence/screenshots/UC-11/TC-032_no_planned_outfit.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

**Literal original scenario:** NOT RUN / requirement gap. Inspect available actions and record the absence. The revised local interaction has automated evidence but does not establish acceptance of the original requirement.

## TC-033 — Switch between planned dates

**Manual/integration requirement:** REQUIREMENT GAP: no daily calendar navigation. Revised multiple dated list cards automated.

**Test data:** Two scheduled test plans on D and D+1 with visibly different items.

**Execution:**

1. Record absence of daily navigation
2. for revised case, scroll dated upcoming cards then use Previous/Next outfit in My Outfits detail
3. verify date/items remain paired.

**Expected behavior:** Original: daily calendar navigation. Proposed: inspect multiple dated upcoming cards or browse saved planner pages.

**Capture:** Capture each dated card or detail page with date/source visible; suffix _D/_Dplus1. Save under `testing_evidence/screenshots/UC-11/TC-033_planned_dates_browsed.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.

**Literal original scenario:** NOT RUN / requirement gap. Inspect available actions and record the absence. The revised local interaction has automated evidence but does not establish acceptance of the original requirement.

## TC-034 — Display outfit on Digital Twin

**Manual/integration requirement:** Generated-result display and saved full viewer automated; real visual correctness manual. Applying arbitrary saved/planned items to a twin is a separate absent operation.

**Test data:** One generated result, one saved result, one planner collage and a test twin.

**Execution:**

1. Generate an outfit on the test twin
2. inspect the result
3. Save Outfit
4. reopen the image in My Outfits and compare it with the result. View a planner collage separately. If the requirement means applying a planner outfit to a twin, record absence of that action and clarify scope.

**Expected behavior:** Display the generated outfit-on-twin image and reopen its saved result; planner item collage remains distinct.

**Capture:** Capture generated result and reopened saved result; append _saved. Save under `testing_evidence/screenshots/UC-12/TC-034_outfit_on_twin_displayed.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

## TC-035 — Display outfit without Digital Twin

**Manual/integration requirement:** Empty Virtual Twin/Create Twin now automated; verify real no-twin account. Viewing an existing saved image is independent of a current twin.

**Test data:** No-twin test account for generation guard; approved pre-existing saved image for independent viewing.

**Execution:**

1. Open Virtual Twin as a no-twin test user and verify No virtual twin yet/Create Twin
2. inspect VTON/Inspo setup guidance. If testing independent saved-image viewing, use an approved seeded image in the no-twin account and open My Outfits
3. record the entry point. Do not delete a production twin.

**Expected behavior:** Show create-twin guidance before generation; viewing an existing saved image can remain independent of a current twin.

**Capture:** Capture actual empty-twin/setup state and, if required, independent saved-image view. Save under `testing_evidence/screenshots/UC-12/TC-035_display_without_twin.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.

## TC-036 — Display unavailable outfit

**Manual/integration requirement:** Missing URL component and simulated remote-image failure in full viewer automated; confirm real missing test object/offline Android navigation.

**Test data:** Dedicated test fixture with missing image URL and a separate safe nonexistent storage object.

**Execution:**

1. Open approved missing-image test outfit in My Outfits thumbnail/detail
2. verify fallback and navigation remain usable
3. repeat offline/missing remote object without deleting real media.

**Expected behavior:** Show a safe missing-image state for absent/unavailable saved outfit image, with no crash.

**Capture:** At thumbnail fallback and detail error message; suffix _detail. Save under `testing_evidence/screenshots/UC-12/TC-036_unavailable_outfit.png`; suffix additional variants.

**Supporting service evidence:** Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.


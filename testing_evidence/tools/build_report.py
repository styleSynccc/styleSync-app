"""Build the FYP report from actual structured runs and explicit scenario mappings."""
from __future__ import annotations

from collections import Counter
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

from run_qa import ROOT, EVIDENCE, stamp, clean


def python_results(label):
    relative = f'logs/fastapi/{label}.xml'
    root = ET.parse(EVIDENCE / relative).getroot()
    results = []
    for case in root.iter('testcase'):
        status = 'FAIL' if case.find('failure') is not None else 'ERROR' if case.find('error') is not None else 'SKIP' if case.find('skipped') is not None else 'PASS'
        results.append({'name': case.attrib['classname'].replace('.', '/') + '.py::' + case.attrib['name'],
                        'status': status, 'evidence': relative, 'run': label, 'framework': 'pytest'})
    return results


def flutter_results(label):
    relative = f'logs/flutter/{label}.jsonl'
    tests, suites, results, messages = {}, {}, [], {}
    for line in (EVIDENCE / relative).read_text(encoding='utf-8').splitlines():
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
            results.append({'name': suites[test['suiteID']].split('/test/')[-1] + '::' + test['name'],
                            'status': 'SKIP' if event.get('skipped') else 'PASS' if event['result'] == 'success' else 'FAIL',
                            'messages': messages.get(event['testID'], []), 'evidence': relative, 'run': label, 'framework': 'Flutter'})
    return results


# Original scenario status stays separate from outcomes of partial component checks.
# Only three local negative form cases are accepted as fully executed at widget scope.
CASES = [
('Sign Up', 'Register with valid details', 'Create an Auth user, save profile, and route to setup.', 'BLOCKED', 'Valid form forwarded all four details to a fake controller. No real account/profile creation was executed.', ['TC-001'], 'New unique test email, username QA Student, permitted gender, strong synthetic password.', 'Open Sign Up; enter username/email; choose gender; enter password; tap Sign Up; verify setup page and one matching Auth user/profile.', 'registration_success', 'After setup opens and the account-created notice appears.', 'F-AUTH'),
('Sign Up', 'Submit empty required fields', 'Show all required field errors and send no registration call.', 'PASS', 'Widget submission showed name/email/gender/password errors; fake controller received no registration. Actual widget screenshot captured.', ['TC-002'], 'Leave username, email, gender and password unset.', 'Open Sign Up; leave all inputs blank; tap Sign Up; inspect all four validation messages.', 'empty_signup', 'With all validation errors visible.', 'F-AUTH'),
('Sign Up', 'Register using an existing email', 'Show existing-email error and create no duplicate account.', 'BLOCKED', 'Real controller displayed a fake Firebase email-already-in-use error and reset loading. Live duplicate-account handling remains unverified.', ['TC-003'], 'Email already present in the dedicated test Auth project; synthetic signup details.', 'Record initial test Auth user count; submit Sign Up using the existing email and otherwise valid fields; verify error and unchanged count.', 'existing_email', 'While the Firebase error notice is visible.', 'F-AUTH'),
('Login', 'Login using valid credentials', 'Authenticate and route to Home for a completed profile, otherwise setup.', 'BLOCKED', 'Valid form forwarded credentials to a fake controller. No live Firebase login or profile-based routing executed.', ['TC-004', 'test_verify_returns_firebase_uid'], 'Dedicated test account with known credentials and completed profile; repeat with incomplete profile.', 'Log out of the test app; open Login; enter valid test credentials; tap Login; verify correct destination for each profile state.', 'login_success', 'After the expected destination loads.', 'F-AUTH'),
('Login', 'Login using incorrect password', 'Show authentication error, stop loading, and stay signed out.', 'BLOCKED', 'Real controller handled a fake wrong-password exception, retained the original screen, and stopped loading. Live Firebase behavior unverified.', ['TC-005'], 'Known test account email; deliberately wrong synthetic password.', 'Start signed out; enter the test email and wrong password; tap Login; verify error, no destination change, and no active session.', 'invalid_password', 'While the error notice is visible; keep the password obscured.', 'F-AUTH'),
('Login', 'Login using empty fields', 'Show email/password required errors and send no login call.', 'PASS', 'Both field errors appeared on submit and the isolated controller received no credentials. Actual widget screenshot captured.', ['TC-006'], 'Empty email and password.', 'Open Login; leave both fields blank; tap Login; verify both required messages.', 'empty_login', 'With both required messages visible.', 'F-AUTH'),
('Create Digital Twin', 'Create Digital Twin with valid body details', 'Process body photo, save positive metrics/style/twin references, then open Home.', 'BLOCKED', 'Existing fake photo pipeline saved four temporary artifacts at 768x1024; metric helpers pass. No real models/Firebase profile save executed.', ['TC-007', 'TC007', 'test_happy_path_saves_all_artifacts', 'valid body metric'], 'Consented synthetic/test full-body JPEG >=320x640; height 170, weight 65.5, Casual.', 'Open twin setup; choose clear standing full-body photo; enter height/weight and select a style; Save & Continue; verify processed twin and Home.', 'digital_twin_created', 'After successful creation and when the processed twin is visible.', 'F-TWIN'),
('Create Digital Twin', 'Submit incomplete body details', 'Reject missing photo or incomplete metrics before file, API, or Firebase work.', 'PASS', 'Widget rejected absent photo; controller rejected empty height even with an image reference. Existing helper tests reject empty/nonfinite/nonpositive values. Local negative scope only.', ['TC-008', 'invalid body metric'], 'First no photo; then valid test photo with height blank; repeat missing weight/style manually.', 'Tap Save & Continue without photo; then select valid photo and clear height; repeat with missing weight and no styles; verify notices and no profile completion.', 'incomplete_twin', 'At each validation notice; append _missing_weight/_missing_style for further variants.', 'F-TWIN'),
('Create Digital Twin', 'Retrieve saved Digital Twin', 'Retrieve the signed-in user\'s saved processed twin or documented Firebase photo fallback.', 'BLOCKED', 'Temporary-store list tests returned newest-first owned twins; no mobile retrieval or persisted Firebase photo fallback was executed.', ['test_list_twins', 'test_twins_list_requires_auth'], 'Dedicated test user with saved twin and another test user for isolation.', 'Create a twin in test environment; close/reopen app; open Virtual Twin from Profile; verify correct processed photo; compare a second test account.', 'saved_twin_retrieved', 'When the reopened twin is visible.', 'F-TWIN'),
('Capture Clothing Photo', 'Upload clothing image from gallery', 'Process selected clothing, store image and clothes record, and refresh closet.', 'BLOCKED', 'Wardrobe API processed synthetic image using FakeEngine; link recovery tests pass. OS gallery and Firebase upload were not exercised.', ['test_garment_item_saved_without_mask', 'recovers missing gallery'], 'Test garment photo >=256 pixels on each side; signed-in test user.', 'On Home expand add categories; choose Tops; choose the custom photo tile; Choose from gallery; select garment; wait for closet refresh.', 'gallery_clothing_uploaded', 'When the processed item appears in the correct closet category.', 'F-CLOTHES'),
('Capture Clothing Photo', 'Capture clothing image using camera', 'Open permitted camera, accept captured photo, and add processed item.', 'BLOCKED', 'Camera source wiring was found in code; no connected Android device and no camera capture executed.', [], 'Android camera/emulator camera input; well-lit test garment.', 'Choose a closet category; open custom photo source; Take a photo; allow camera access; capture and accept garment photo; wait for added item.', 'camera_clothing_uploaded', 'After capture acceptance and after item appears; use _camera for the capture screen.', 'F-CLOTHES'),
('Capture Clothing Photo', 'Cancel clothing image selection', 'Return safely without new clothing, storage object, or processing request.', 'BLOCKED', 'Code returns when picker result is null; clothing cancellation was not executed because ClosetController initializes live Firebase singletons.', [], 'Existing test closet; record initial count.', 'Choose category/custom photo; open gallery then press Android Back; repeat camera cancellation; verify closet count and service records unchanged.', 'clothing_selection_cancelled', 'After returning to unchanged closet.', 'F-CLOTHES'),
('Categorize Clothes', 'Assign clothing category', 'Use category chosen before upload and persist matching category/item reference.', 'BLOCKED', 'API category assignment/style checks pass; missing category returns 422 and saves nothing. Mobile category-first flow and Firebase persistence unverified.', ['test_garment_item_saved_without_mask', 'test_unknown_category', 'TC013'], 'Distinct Tops/Pants/Skirts test images; same test user.', 'Select Tops before custom upload; choose top image; verify stored category. Repeat Pants/Skirts with matching images; inspect metadata.', 'category_assigned', 'When each processed garment is shown under its category.', 'F-CLOTHES'),
('Categorize Clothes', 'Change clothing category', 'Original: edit saved item category. Proposed: dismiss and choose another category before upload.', 'NOT RUN', 'No saved-item category editing operation was found in UI/controller or FastAPI routes. Proposed pre-upload replacement was not executed.', [], 'Existing test item; alternate category.', 'Inspect existing item actions for category edit and record absence. For proposed case, open Tops sheet, dismiss, open Pants sheet, then upload a Pants test image.', 'category_change_scope_gap', 'Capture available actions for original; for revised flow capture the final chosen category.', 'F-CLOTHES'),
('Categorize Clothes', 'Cancel categorization', 'Dismiss category selection without saving or processing an item.', 'BLOCKED', 'Category selection is a bottom sheet before upload; no separate categorization transaction. Dismissal behavior was not executed.', [], 'Unchanged test closet; starting document count.', 'Expand add categories; open Tops sheet; dismiss using Back/outside tap before selecting an item; verify count and service writes unchanged.', 'categorization_cancelled', 'After dismissal with the unchanged closet visible.', 'F-CLOTHES'),
('Generate Virtual Try-On', 'Generate Virtual Try-On image', 'Confirm mode/cost, generate selected outfit on owned twin, display resulting image.', 'BLOCKED', 'Fake API generation/composition and provider payload tests pass. Six existing confirmation-widget tests fail because credit totals are absent. No live AI generation executed.', ['test_top_and_pants', 'test_result_is_persisted', 'test_mode_controls', 'test_two_paid_passes', 'VTON shows', 'confirmation shows its own total'], 'Saved test twin; linked top and pants; authorized hosted AI key/credits.', 'Open Virtual Try-On; select twin and test garments; choose mode; inspect confirmation including cost requirement; confirm once; wait for result; assess identity, garment fidelity and errors.', 'virtual_tryon_success', 'Capture confirmation as _confirmation, then final result without personal data.', 'F-GENERATION'),
('Generate Virtual Try-On', 'Change clothing selection before generation', 'Generate only the final selected item IDs, without an earlier unconfirmed request.', 'BLOCKED', 'Existing HTTP mock asserts a fixed item list, not UI selection changes. No running selection flow executed.', ['VTON sends its confirmed total once'], 'Two visibly different linked test tops and one twin.', 'Open try-on; select top A then top B before Generate; verify highlight; confirm once; inspect request IDs and result for B only.', 'tryon_selection_changed', 'After changing selection and after result; append _result.', 'F-GENERATION'),
('Generate Virtual Try-On', 'Attempt Virtual Try-On without Digital Twin', 'Disable generation with setup guidance; reject unknown twin in API.', 'BLOCKED', 'API returned 404 TWIN_NOT_FOUND for an unknown twin with a fake engine. VTON empty-twin UI was not executed.', ['test_unknown_twin_is_404'], 'Dedicated test user with clothes but no saved twin.', 'Open Virtual Try-On as no-twin test user; verify Create digital twin prompt and disabled Generate; do not delete an existing production twin to create this condition.', 'tryon_without_twin', 'With setup guidance and disabled Generate visible.', 'F-GENERATION'),
('Save Outfit to Wardrobe', 'Save generated outfit', 'Upload generated image and add exactly one likedOutfits record, visible in My Outfits.', 'BLOCKED', 'OutfitDraft injected persistence callback and backend temporary result persistence passed. Neither proves actual Firebase saving.', ['double tapping save', 'test_result_is_persisted'], 'Unsaved generated result in test account.', 'Generate test result; record likedOutfits count; Save Outfit once; open My Outfits; reopen saved image and verify source/title and count +1.', 'outfit_saved', 'After Save changes to Saved and in My Outfits; append _gallery.', 'F-SAVE'),
('Save Outfit to Wardrobe', 'Cancel saving', 'Original: cancel save dialog. Proposed: leave without tapping Save, with no likedOutfits write.', 'NOT RUN', 'Save acts immediately; no cancel-save dialog exists. Leaving unsaved does not remove the backend generation result already persisted.', [], 'Fresh generated result not yet saved; record likedOutfits count.', 'Record absence of a cancel-save dialog. For revised case, generate result, navigate Back without tapping Save, then inspect My Outfits and Firebase count.', 'outfit_left_unsaved', 'Before leaving and after returning to My Outfits; append _gallery.', 'F-SAVE'),
('Save Outfit to Wardrobe', 'Save an already saved outfit', 'Repeated taps on the current saved draft do not create duplicate uploads/documents.', 'BLOCKED', 'Draft test proves one injected persist call across concurrent and repeated saves. Cross-session/content-hash deduplication is not implemented or claimed.', ['double tapping save'], 'One unsaved result; initial test likedOutfits count.', 'Rapidly double-tap Save Outfit once; wait for Saved; try tapping again; compare likedOutfits count and matching storage object count; expect +1 for this draft.', 'duplicate_save_prevented', 'With Saved button disabled and one gallery entry.', 'F-SAVE'),
('Upload Inspiration Photo', 'Upload valid inspiration image', 'Preview selected image locally; upload only on confirmed generation with a saved twin.', 'BLOCKED', 'Multipart mock and fake inspo endpoint pass. Selection is local; standalone upload is not an API operation.', ['Inspo sends the three-credit', 'test_inspo_returns_and_persists_result'], 'Consented fully clothed full-body reference JPEG >=320x640; saved twin.', 'Open AI Inspo Mirror; Upload inspiration photo; select test image; verify preview and no generation; then confirm Generate on my twin to test actual upload.', 'inspiration_uploaded', 'At local preview; capture generated result separately under TC-025.', 'F-GENERATION'),
('Upload Inspiration Photo', 'Upload unsupported image format', 'Reject undecodable/unsupported reference before provider call or result persistence.', 'BLOCKED', 'Real in-process API rejected SVG with 400 INVALID_IMAGE and zero fake-provider calls. Device picker support/rejection remains unexecuted; no strict extension allowlist exists.', ['TC023', 'test_inspo_validates_before_paid_generation'], 'Safe reference.svg containing only a rectangle, plus test twin.', 'Try selecting SVG through gallery if visible; record picker exclusion if applicable. Use isolated test API SVG case for server rejection; do not relabel a JPEG extension as proof of format rejection.', 'unsupported_inspiration', 'At picker exclusion/error notice; record API-only evidence if OS excludes SVG.', 'F-GENERATION'),
('Upload Inspiration Photo', 'Cancel image selection', 'Cancel OS gallery without changing reference or starting generation.', 'BLOCKED', 'Mocked picker returned null; widget retained empty selection and issued no generation. Actual Android picker cancellation was not executed.', ['TC-024'], 'Inspo screen with no reference; optionally repeat with an existing reference.', 'Tap Upload inspiration photo; cancel Android gallery; verify empty preview. Repeat Change inspiration photo then cancel and verify old preview remains.', 'inspiration_selection_cancelled', 'After gallery closes and prior selection remains unchanged.', 'F-GENERATION'),
('Adjust Style to Digital Twin', 'Apply inspiration style to Digital Twin', 'Transfer visible reference outfit to selected twin, preserving expected identity and returning a usable image.', 'BLOCKED', 'Fake provider returned JPEG and metadata; mocked hosted payload contains identity prompt. Real style/identity/garment quality was not measured.', ['test_inspo_returns_and_persists_result', 'test_inspo_uses_one_quality', 'test_inspo_single_three_credit'], 'Saved test twin and clear reference; authorized AI service/credits.', 'Choose reference and twin; inspect mode/confirmation; generate once; compare outfit and identity with permitted source images; record visual defects and returned metadata.', 'inspiration_style_applied', 'When final image and selected twin/reference context are visible.', 'F-GENERATION'),
('Adjust Style to Digital Twin', 'Apply style without Digital Twin', 'Show setup guidance/disabled Generate; API rejects absent or other-user twin before provider.', 'BLOCKED', 'Existing fake UI disabled Generate for empty twins; added API test returned 404 for absent twin, zero provider calls and no result directory. Real account flow unverified.', ['empty twin list explains', 'TC026', 'test_inspo_rejects_other_users'], 'Dedicated no-twin test user and valid inspiration image.', 'Open Inspo Mirror as no-twin user; select valid image; verify Create or edit twin guidance and disabled Generate; inspect zero generation requests.', 'inspiration_without_twin', 'With selected reference, setup guidance and disabled Generate.', 'F-GENERATION'),
('Adjust Style to Digital Twin', 'Process an unsuitable inspiration image', 'Reject malformed/undersized inputs locally; define desired handling for valid-sized non-outfit scenes.', 'BLOCKED', 'Tiny reference returned 400 before provider. Valid-sized flat blank JPEG returned 201 and called fake provider once. Semantic suitability is not checked locally; real provider response and acceptance criteria remain unresolved.', ['TC027'], 'Tiny 120x160 JPEG; blank 600x800 JPEG; safe non-person scene.', 'Run isolated tiny/blank tests first. For real non-person image, agree rejection/quality criteria before any paid request; then submit once in approved test environment and record actual provider behavior.', 'unsuitable_inspiration', 'At the actual rejection or returned result; never label blank fake output as real AI evidence.', 'F-GENERATION'),
('Schedule Outfit', 'Schedule outfit for selected date', 'Save closet items for a future local date/time and report actual reminder scheduling status.', 'BLOCKED', 'Model and mocked notification tests pass, including Kuala Lumpur time and permission fallbacks. No Firestore plan save or Android alarm delivery executed.', ['Malaysian 10:11', 'denied exact access', 'disabled notifications', 'future reminder is upcoming'], 'Two closet items; future date D = tomorrow, time 08:00; notifications allowed.', 'Open Outfit Planner; Select a date to plan an outfit; choose D; choose 08:00; select two items; Save Outfit; verify upcoming card and notification schedule status.', 'outfit_scheduled', 'After Outfit planned notice and dated card appear.', 'F-PLAN'),
('Schedule Outfit', 'Change selected date', 'Use final chosen date before commit. Moving an already saved plan has no dedicated action.', 'BLOCKED', 'Date/time picker and one-document-per-date save inspected; no date-change interaction executed.', [], 'Future dates D and D+1; two different test closet items.', 'Open date picker; tap D then D+1 before OK; choose future time/items; Save; verify only D+1 gained a plan. Do not interpret replanning as moving an existing record.', 'schedule_date_changed', 'At final highlighted date and saved dated card; append _saved.', 'F-PLAN'),
('Schedule Outfit', 'Cancel outfit scheduling', 'Cancel date picker, time picker, or item sheet without saving a plan or alarm.', 'BLOCKED', 'Null date/time returns and sheet-before-save sequence inspected; no UI cancellation was executed.', [], 'Baseline test plan document count and pending alarm list.', 'Open planning then cancel date picker; repeat choosing date then cancel time picker; repeat date/time then dismiss item sheet; verify no added plan/alarm after each variant.', 'scheduling_cancelled', 'After each cancellation returns to unchanged Upcoming Outfits; suffix _date/_time/_items.', 'F-PLAN'),
('View Daily Planned Outfit', 'View scheduled outfit', 'Show upcoming dated card and its closet-item thumbnails; past plan remains in My Outfits.', 'BLOCKED', 'Upcoming/legacy expiry and gallery conversion unit checks pass; preview renders item collage. No real plan stream displayed.', ['future reminder is upcoming', 'legacy date-only', 'existing planner records', 'planner thumbnail'], 'Previously scheduled future D plan and permitted past test plan.', 'Open Outfit Planner; locate D card; verify date, time and selected thumbnails; open My Outfits to inspect past planner record after expiry.', 'planned_outfit_viewed', 'With date/time and all intended item thumbnails visible.', 'F-PLAN'),
('View Daily Planned Outfit', 'View date with no scheduled outfit', 'Original: daily-date empty state. Proposed: empty Upcoming Outfits list.', 'NOT RUN', 'Planner has no selected-day viewing/calendar control. Empty-list text is implemented, but original daily-date flow is unavailable and not executed.', ['missing or invalid dates', 'empty planner outfit'], 'Dedicated account with no upcoming test plans; avoid deleting production plans.', 'Record that daily-date selection is unavailable. For revised case, open Outfit Planner with no upcoming plans and verify No upcoming outfits message.', 'no_planned_outfit', 'With the actual empty upcoming-list message visible.', 'F-PLAN'),
('View Daily Planned Outfit', 'Switch between planned dates', 'Original: daily calendar navigation. Proposed: inspect multiple dated upcoming cards or browse saved planner pages.', 'NOT RUN', 'No daily calendar selector exists. Multiple list cards and My Outfits page browsing are available; revised behavior not executed.', [], 'Two scheduled test plans on D and D+1 with visibly different items.', 'Record absence of daily navigation; for revised case, scroll dated upcoming cards then use Previous/Next outfit in My Outfits detail; verify date/items remain paired.', 'planned_dates_browsed', 'Capture each dated card or detail page with date/source visible; suffix _D/_Dplus1.', 'F-PLAN'),
('Display Outfit on Digital Twin', 'Display outfit on Digital Twin', 'Display the generated outfit-on-twin image and reopen its saved result; planner item collage remains distinct.', 'BLOCKED', 'VTON/Inspo result display and saved-image viewer exist in source; fake try-on returns image data. No complete result display executed. If this means dressing a twin from a saved planner outfit, that separate operation is absent and needs clarification.', ['test_top_and_pants', 'planner detail shows'], 'One generated result, one saved result, one planner collage and a test twin.', 'Generate an outfit on the test twin; inspect the result; Save Outfit; reopen the image in My Outfits and compare it with the result. View a planner collage separately. If the requirement means applying a planner outfit to a twin, record absence of that action and clarify scope.', 'outfit_on_twin_displayed', 'Capture generated result and reopened saved result; append _saved.', 'F-SAVE'),
('Display Outfit on Digital Twin', 'Display outfit without Digital Twin', 'Show create-twin guidance before generation; viewing an existing saved image can remain independent of a current twin.', 'BLOCKED', 'Isolated no-twin generation guards pass; Virtual Twin empty state exists in source. Full no-twin viewer/navigation behavior was not executed. The intended display entry point needs confirmation before accepting this scenario.', ['test_unknown_twin', 'empty twin list explains'], 'No-twin test account for generation guard; approved pre-existing saved image for independent viewing.', 'Open Virtual Twin as a no-twin test user and verify No virtual twin yet/Create Twin; inspect VTON/Inspo setup guidance. If testing independent saved-image viewing, use an approved seeded image in the no-twin account and open My Outfits; record the entry point. Do not delete a production twin.', 'display_without_twin', 'Capture actual empty-twin/setup state and, if required, independent saved-image view.', 'F-SAVE'),
('Display Outfit on Digital Twin', 'Display unavailable outfit', 'Show a safe missing-image state for absent/unavailable saved outfit image, with no crash.', 'BLOCKED', 'Two added widget tests passed for missing generated-image URL: thumbnail icon and readable detail message. Missing remote object/document and Android full viewer not exercised.', ['TC-036', 'test_unknown_garment_is_404'], 'Dedicated test fixture with missing image URL and a separate safe nonexistent storage object.', 'Open approved missing-image test outfit in My Outfits thumbnail/detail; verify fallback and navigation remain usable; repeat offline/missing remote object without deleting real media.', 'unavailable_outfit', 'At thumbnail fallback and detail error message; suffix _detail.', 'F-SAVE'),
]

SUPPORT = {
    'F-AUTH': 'Inspect the dedicated Auth emulator/project for account count and session outcome; inspect `users/<testUid>` for profile creation/completion. FastAPI token tests are separate from Firebase credential authentication. Save redacted console observations under `logs/firebase/TC-NNN_manual.md`.',
    'F-TWIN': 'Inspect test `users/<testUid>` fields height, weight, stylePreferences, twinId, isProfileComplete; Storage `users/<testUid>/digital_twin_processed.jpg`; authorized `/v1/twins` response and isolated AI_DATA_DIR twins/<testUid>/<twinId>. Save redacted metadata/status only in `logs/firebase` and `logs/fastapi`.',
    'F-CLOTHES': 'Compare test `users/<testUid>/clothes` count/category/itemId and Storage users/<testUid>/clothes/<itemId>.jpg; match `/v1/wardrobe` status/category to isolated backend wardrobe metadata. Cancellation requires unchanged counts and no new processing request. Save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/fastapi/TC-NNN_manual.md`.',
    'F-GENERATION': 'Correlate test `/v1/tryon` or `/v1/inspo` status, selected IDs, generationMode and confirmedCredits with isolated results/<testUid>/<resultId>/metadata.json. Check estimatedCredits/generationPasses/source and zero provider calls for preflight rejection. Auth/Storage only supply test twin/reference context. Do not record bearer headers, keys, base64 photos or tokenized URLs; save redacted notes in `logs/fastapi/TC-NNN_manual.md`.',
    'F-SAVE': 'Inspect test `users/<testUid>/likedOutfits` count/source/title and Storage users/<testUid>/liked_outfits/<docId>.jpg/png. Match rendered saved image to result. Backend results persist independently of Firebase explicit saving; planner records live in outfitPlans. Save redacted count/metadata observations in `logs/firebase/TC-NNN_manual.md`.',
    'F-PLAN': 'Inspect test `users/<testUid>/outfitPlans/YYYY-MM-DD` date, reminderAt, notificationId and item IDs. Same-date saves replace the date document. Capture permitted Android pending-alarm/notification evidence with device timezone Asia/Kuala_Lumpur. Planner does not invoke FastAPI; save redacted notes in `logs/firebase/TC-NNN_manual.md` and `logs/integration/TC-NNN_manual.md`.',
}


def link(path, label=None):
    return f'[{label or path}](../{path})'


def main():
    reports = EVIDENCE / 'reports'
    results = python_results('baseline') + flutter_results('baseline') + python_results('added') + flutter_results('added-readable')
    assert len(CASES) == 36
    counts = Counter(r['status'] for r in results)
    assert counts == {'PASS': 216, 'FAIL': 6}, counts
    cases = []
    for i, row in enumerate(CASES, 1):
        use_case, scenario, expected, status, actual, selectors, data, steps, shot, moment, support = row
        tc, uc = f'TC-{i:03d}', f'UC-{(i-1)//3+1:02d}'
        matched = [r for r in results if any(selector in r['name'] for selector in selectors)]
        screenshots = list((EVIDENCE / 'screenshots' / uc).glob(f'{tc}_*.png'))
        evidence = {'test_case': tc, 'use_case': uc, 'original_scenario': scenario, 'status': status,
                    'expected': expected, 'actual': actual, 'execution_scope': 'isolated automated components only; no Android/live Firebase/real AI execution',
                    'automated_checks': matched, 'screenshots': [p.relative_to(EVIDENCE).as_posix() for p in screenshots],
                    'no_match_note': None if matched else 'No automated execution directly mapped; implementation inspected, original scenario unexecuted.'}
        evidence_path = f'logs/integration/{tc}_evidence.json'
        (EVIDENCE / evidence_path).write_text(clean(json.dumps(evidence, indent=2)), encoding='utf-8')
        cases.append(dict(id=tc, uc=uc, use_case=use_case, scenario=scenario, expected=expected, actual=actual,
                          status=status, evidence=evidence_path, screenshots=evidence['screenshots'], selectors=selectors,
                          data=data, steps=steps, proposed_screenshot=f'screenshots/{uc}/{tc}_{shot}.png', moment=moment, support=support))
    (reports / 'test_cases.json').write_text(json.dumps(cases, indent=2), encoding='utf-8')
    (reports / 'automated_results.json').write_text(clean(json.dumps(results, indent=2)), encoding='utf-8')
    with (reports / 'Coverage_Mapping.csv').open('w', newline='', encoding='utf-8-sig') as file:
        writer = csv.DictWriter(file, fieldnames=['id','uc','use_case','scenario','expected','actual','status','evidence','selectors'])
        writer.writeheader()
        for case in cases:
            writer.writerow({key: '; '.join(case[key]) if key == 'selectors' else case[key] for key in writer.fieldnames})

    # Git-backed integrity evidence: all tracked application/test/config files stay untouched.
    tracked_changes = subprocess.check_output(['git','diff','--name-only','HEAD'], cwd=ROOT, text=True).splitlines()
    tracked = subprocess.check_output(['git','ls-files','apps/mobile_app/test','apps/ai_service/tests'], cwd=ROOT, text=True).splitlines()
    preserved = []
    for name in tracked:
        path = ROOT / name
        committed = subprocess.check_output(['git','show',f'HEAD:{name}'], cwd=ROOT)
        # Git may normalize LF while the Windows working tree uses CRLF.
        current = path.read_bytes()
        preserved.append({'path': name, 'sha256': hashlib.sha256(current).hexdigest(),
                          'same_as_HEAD_normalized': current.replace(b'\r\n', b'\n') == committed.replace(b'\r\n', b'\n')})
    historical = ROOT / 'apps/mobile_app/flutter_test_results.txt'
    audit = {'captured_at': stamp(), 'head': subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
             'tracked_changes': tracked_changes, 'existing_test_integrity': preserved,
             'preserved_untracked_historical_result_sha256': hashlib.sha256(historical.read_bytes()).hexdigest(),
             'new_test_files': ['apps/mobile_app/test/fyp_functional_gaps_test.dart','apps/ai_service/tests/test_fyp_functional_gaps.py']}
    assert not tracked_changes, tracked_changes
    assert all(item['same_as_HEAD_normalized'] for item in preserved)
    (EVIDENCE / 'logs/integration/repository_integrity.json').write_text(json.dumps(audit, indent=2), encoding='utf-8')

    summary = Counter(c['status'] for c in cases)
    table = '\n'.join(f"| {c['id']} / {c['uc']} | {c['scenario']} | {c['expected']} | {c['actual']} | **{c['status']}** | {link(c['evidence'], c['id'] + ' evidence')}" + ''.join(' · ' + link(p, 'widget PNG') for p in c['screenshots']) + ' |' for c in cases)
    failing = '\n'.join(f"- `{r['name']}`" for r in results if r['status'] == 'FAIL')
    env = json.loads((EVIDENCE / 'logs/integration/environment.json').read_text())
    report = f'''# StyleSync Functional Testing Report

**Execution date:** 16 November 2026, Asia/Kuala_Lumpur (UTC+08:00). **Build:** working tree at `{audit['head']}`; see {link('logs/integration/repository_integrity.json', 'integrity audit')}. No tracked application, dependency, configuration, rules, or existing test files changed.

## Objectives

Assess the 12 use cases and 36 supplied scenarios against implemented behavior; run and preserve existing tests; add necessary isolated gap checks; collect real evidence; identify remaining manual/integration work. This report does not certify live Firebase or AI integration or Android operation.

## Environment

| Item | Observed |
| --- | --- |
| Host | Windows x64; PowerShell; repository C:/Users/User/styleSync-app |
| Flutter / Dart | 3.44.6 stable / 3.12.2; existing cached dependencies; --no-pub |
| Python / pytest / HTTPX | Project .venv: 3.12.10 / {env['packages']['pytest']} / {env['packages']['httpx']} |
| Backend packages | FastAPI {env['packages']['fastapi']}; NumPy {env['packages']['numpy']}; OpenCV headless {env['packages']['opencv-python-headless']}; Pillow {env['packages']['pillow']}; MediaPipe {env['packages']['mediapipe']}; rembg {env['packages']['rembg']} |
| Firebase CLI | 15.24.0 installed; version check only, no account/project mutation |
| Android | adb installed at SDK path; `adb devices -l` returned an empty list; AVDs Medium_Phone, Pixel_10_Pro_XL, Pixel_7 installed but none connected |
| Local services | 127.0.0.1 ports 8000/8002 closed; common Firebase ports 4000/4400/8080/9099/9199 closed at probe time; emulator routing variables unset |
| Credentials/test project | No dedicated integration account/project/AI credit authorization supplied or used; no credential values inspected |
| Test isolation | FakeEngine, FakeTryOnEngine and fake provider HTTP; mocked token verification; tmp_path backend stores; Firebase fakes and picker/notification method-channel mocks |
| Execution restriction | Windows sandbox startup failed with helper_sandbox_lock_failed; approved elevated read/test commands used |

Evidence: {link('logs/integration/environment.json', 'package/port snapshot')}, {link('logs/flutter/version.log', 'Flutter version')}, {link('logs/firebase/version.log', 'Firebase CLI')}, {link('logs/integration/adb_devices.log', 'devices')}, {link('logs/integration/android_avds.log', 'installed AVDs')}. Closed common ports do not prove no service exists at a custom remote endpoint. No remote production endpoint was probed.

## Methodology and status rules

The initial source/test audit and 36-case existing coverage mapping are in [Inspection_and_Test_Plan.md](Inspection_and_Test_Plan.md). All existing Dart and Python tests were read; placeholder assertions were identified. Tests were run from their application roots using existing configuration, then new test files were run separately. Test logs combine full stdout/stderr, with exit code/command/cwd/time stored in adjacent `.meta.json` files. Native JSONL/JUnit results provide per-test outcomes. No assertions were weakened to obtain passes.

**PASS** in the scenario matrix means its stated local negative behavior was actually executed and asserted; only TC-002, TC-006 and TC-008 qualify, at isolated widget/controller scope. **FAIL** would mean an executed original scenario failed its acceptance condition. **BLOCKED** means original mobile/integration acceptance remains incomplete because required device/services/data or agreed behavior are unavailable, even if component checks passed. **NOT RUN** means the original interaction has no matching implemented flow and its proposed replacement was not executed. Partial mocked results are recorded alongside this status and never promoted to an end-to-end PASS. No rows are marked FAIL from inference alone.

Three actual widget PNGs were captured after assertions and visually inspected. They use installed SDK Roboto/Material fonts and an 800x1000 widget surface; they are **not Android screenshots**. The first added run passed but its default Ahem-font captures were unreadable; the `added-readable` rerun supplies the delivered PNGs. Both execution logs remain. The three screenshots show empty/synthetic data only. No manually collected device screenshots exist.

## Automated execution summary

| Run | Passed | Failed | Skipped | Collection errors | Exit | Evidence |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Existing FastAPI tests | 143 | 0 | 0 | 0 | 0 | {link('logs/fastapi/baseline.log', 'full log')} · {link('logs/fastapi/baseline.xml', 'JUnit')} |
| Existing Flutter tests | 56 | 6 | 0 | 0 | 1 | {link('logs/flutter/baseline.log', 'full log')} · {link('logs/flutter/baseline.jsonl', 'JSONL')} |
| Added FastAPI gap tests | 6 | 0 | 0 | 0 | 0 | {link('logs/fastapi/added.log', 'full log')} · {link('logs/fastapi/added.xml', 'JUnit')} |
| Added Flutter gap tests, readable-font run | 11 | 0 | 0 | 0 | 0 | {link('logs/flutter/added-readable.log', 'full log')} · {link('logs/flutter/added-readable.jsonl', 'JSONL')} |
| **Unique checks across these four runs** | **216** | **6** | **0** | **0** | — | [Automated test inventory](Automated_Test_Inventory.md) |

Automated assertion pass percentage = 216 / 222 × 100 = **97.30%**. This includes the existing nonfunctional `Placeholder test` (1 + 1 = 2); excluding it gives 215 / 221 = **97.29%**. The font rerun repeats the same 11 new Flutter checks and is counted once. The added backend blank-reference characterization passes because it records current behavior; it does not establish suitability rejection. No all-suite rerun was needed: original suites were preserved and additions ran in separate files/processes. The current full Flutter suite remains known failing.

No missing dependencies, skipped tests, or collection errors were observed in these runs. The backend emitted one Starlette TestClient/HTTPX deprecation warning per pytest invocation; dependencies were left unchanged. Global pytest is absent from PATH; `.venv/Scripts/python.exe -m pytest` worked. Flutter dependencies were already cached. `integration_test` is not declared, and no live integration harness was added.

## Scenario acceptance summary

| PASS | FAIL | BLOCKED | NOT RUN | Total |
| ---: | ---: | ---: | ---: | ---: |
| {summary['PASS']} | {summary['FAIL']} | {summary['BLOCKED']} | {summary['NOT RUN']} | 36 |

Required-scenario pass percentage = {summary['PASS']} / 36 × 100 = **{summary['PASS']/36*100:.2f}%**, limited to isolated local validation. **No complete Android/Firebase/real-AI workflow has been accepted.** A pass rate over only the few completed scenarios would hide the outstanding scope and is not used as overall success.

## Test case results and evidence

Each per-case evidence JSON links the exact executed checks that contribute partial coverage, their outcome, and structured log filename. Empty matches explicitly mean no direct automated execution. Source-only findings do not become test passes. Revised expectations in rows with implementation differences are proposals, not silent replacements of the original scenarios.

| Case / use case | Scenario | Expected result / implementation adjustment | Actual observation | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
{table}

Machine-readable mapping: [Coverage_Mapping.csv](Coverage_Mapping.csv), [test_cases.json](test_cases.json). Initial existing-test mapping remains in the inspection plan; final added-test mapping and full node names are in each case evidence file and the inventory.

## Findings and differences from requirements

**D-001 — generation confirmation regression/test-contract mismatch.** Six existing tests fail in `test/generation_confirmation_test.dart`. The actual `confirmGeneration` widget uses title `Generate outfit?`, a generic `Generate` button, and no displayed total. Tests expect `Generate for N credits?`, credit-bearing button text, and the earlier-steps credit notice. The first failing assertion is the missing title in all six cases; later assertions in those tests did not execute. Source confirms the additional missing text. This affects confidence in cost disclosure before TC-016/025 generation, but does not prove live generation itself fails. The API still receives/checks confirmed credits and those mocked tests pass. Resolve the intended cost-disclosure requirement and, if retained, restore the display after approval; do not weaken the existing tests merely to turn them green.

Failing test names:

{failing}

**G-002 — inspiration suitability limitation.** Added TC027 probe sent an actual flat 600x800 JPEG to the in-process API. It returned 201 and invoked the fake provider once; a 120x160 JPEG returned 400 without a call. There is no local person/outfit suitability classifier. This is an observed API behavior and a requirement gap, not proof of what the real hosted provider would return. Agree acceptable behavior for non-person scenes, multiple people, occlusion and unclear outfits before accepting TC-027.

**G-003 — four interactions require a revised interpretation.** TC-014 has no saved category edit; TC-020 has no save-cancel dialog; TC-032/033 have no daily calendar. Proposed replacements are explicitly shown in the matrix and manual guide. TC-034/035 are treated as blocked display scenarios, since generated-result viewing and empty-twin guidance exist; if the intended requirement is applying a saved/planned outfit to a twin, that separate operation is absent. TC-029 supports changing a date before commit, not moving an existing plan. Categories precede upload (TC-013/015); inspiration selection is local until Generate (TC-022). Saved generated images can be viewed independently of a current twin.

**G-004 — save and schedule scope.** Draft guards deduplicate the current result in memory, not across sessions or identical image content. Backend generation results persist before explicit Firebase Save; leaving unsaved only avoids `likedOutfits`. Planner stores one document per local date, so a later same-day save replaces that date's plan; it displays upcoming cards and archives past plans in My Outfits. Notification mocks verify payloads, not actual Android delivery.

**E-001 — integration prerequisites unavailable.** No connected device; default local AI/worker/emulator ports closed; no supplied dedicated test Firebase environment or live AI authorization. Although Firebase project configuration exists, it was not used to mutate accounts/data. The mobile API URL defaults to a particular LAN address; an approved test build must override it for the actual host/device arrangement. Source security rules were read, not deployed or behavior-tested.

## Added tests

- `apps/mobile_app/test/fyp_functional_gaps_test.dart`: 11 distinct checks covering empty/valid form submission, mocked Firebase failures, missing/incomplete setup, picker-null cancellation, missing-image fallback; three widget captures. Existing tests left untouched.
- `apps/ai_service/tests/test_fyp_functional_gaps.py`: 6 checks covering missing file/category fields, absent inspiration twin, SVG rejection, low-resolution rejection, and blank-image characterization; temporary data and fake provider only.

## Reproduction and evidence handling

From repository root, use the project venv to run `testing_evidence/tools/run_qa.py`. Actions are `environment`, `python-baseline`, `flutter-baseline`, `python-added`, and `flutter-added`. Use `--label rerun_YYYYMMDD` for new run filenames; existing baseline log files must be preserved. `flutter test` runs inside `apps/mobile_app` with `--no-pub`; pytest inside `apps/ai_service` reads `pytest.ini`. The runner's own shell exit is not the test exit: consult `.meta.json` and structured results (Flutter baseline test exit 1).

Reports and evidence can be packaged without Firebase credentials. Logs redact bearer values, JWTs, tokenized URLs and matching sensitive environment values. All tests use synthetic data, fake credentials and temporary stores. No passwords/tokens/keys were copied from user configuration. Do not commit future manual screenshots containing personal accounts or full Firebase download URLs. [Evidence manifest](Evidence_Manifest.json) records SHA-256 hashes; `.gitignore` inside the evidence folder keeps sanitized `.log` files from being lost to the root ignore rule.

## Limitations and conclusion

Android camera/gallery/permission interaction, live registration/login/profile/Storage persistence, deployed Firebase rules, real MediaPipe/background removal/extraction models, hosted AI quality and failure behavior, and delivered reminders remain unverified. Mocked images/provider responses are not AI output evidence. No UI image was fabricated; empty screenshot folders for other use cases are intentional. Exact manual procedures and proposed replacements are in [Manual_Testing_Guide.md](Manual_Testing_Guide.md).

Automated testing found six real failing test assertions, all around missing confirmation cost text, while the isolated backend suite passed. Only three of 36 original scenarios have completed local acceptance checks. Complete functional acceptance requires resolving the stated requirement differences and executing the blocked scenarios in an approved dedicated test environment. **100% functional success is not claimed.**
'''
    (reports / 'StyleSync_Functional_Test_Report.md').write_text(report, encoding='utf-8')

    inventory = ['# Automated test inventory', '', 'Generated from executed JUnit/JSONL results. Full parameterized node names appear below; loading/setup/teardown records are excluded. Existing placeholder test is nonfunctional. Font rerun replaces the same added Flutter check results for counting purposes.', '', '| Framework | Run | Test | Outcome | Evidence |', '| --- | --- | --- | --- | --- |']
    for result in results:
        inventory.append(f"| {result['framework']} | {result['run']} | `{result['name'].replace('|', '/').replace(chr(10), ' ')}` | {result['status']} | {link(result['evidence'], 'structured result')} |")
    (reports / 'Automated_Test_Inventory.md').write_text('\n'.join(inventory) + '\n', encoding='utf-8')

    manual = '''# StyleSync manual functional testing guide

Prepared 16 November 2026 (Asia/Kuala_Lumpur). These are pending instructions, not executed results. Recheck current report status before recording evidence. Widget-only passes should also be confirmed on Android for final device acceptance.

## Preconditions

Use only a dedicated Firebase test project or properly isolated Auth/Firestore/Storage emulators, test accounts and consented/synthetic images. The current application uses configured Firebase project options and no emulator routing; changing that wiring, application code, dependencies, settings or rules requires the user's approval. Do not run registration/upload/planning against the configured project until it is explicitly identified as the approved test environment. Never delete existing production data to construct a negative case.

Connect an Android emulator or phone and verify `adb devices -l`. Three AVDs are installed but none were connected during this run. Use a test build pointed to the isolated AI service (AI_DATA_DIR must be separate from existing data); keep Firebase authentication enabled for integration checks. For an Android emulator the host service is commonly reached through 10.0.2.2; a physical device needs the approved host routing. Override AI_SERVICE_BASE_URL at build time using the actual isolated service address; the code's LAN default is not verified for this session. Start models/worker through the project's normal setup only after confirming their dependencies and data isolation. No installation/configuration change is authorized by this guide alone.

Use distinct test-user aliases: QA-New (new email), QA-Ready (completed profile/twin), QA-Incomplete, QA-NoTwin. Reserve their real test addresses/passwords privately; never put passwords, bearer tokens or full tokenized Storage URLs in evidence. A suitable synthetic password satisfies the code's >=6 characters, uppercase and special-character rules. Use clearly different top A/top B images, body photo >=320x640, garment >=256x256, inspiration >=320x640, tiny 120x160 JPEG and safe SVG. Backend limits are 25*1024*1024 bytes and 100,000,000 pixels; keep test inputs comfortably below limits except explicit negative cases.

Hosted generation may consume credits. Before a live request, use only the approved test key/budget and check the confirmation requirement discrepancy D-001. Submit once, preserve the result/error and avoid blind retries. Actual identity, clothes, modesty/hijab preservation and visual artifacts require human review; a successful HTTP response alone is insufficient.

## Recording each result

Keep screenshots under `testing_evidence/screenshots/UC-xx/`; filenames below are planned and do not yet exist unless explicitly identified in the report as widget captures. Append variant suffixes where indicated. Record date/time (UTC+08:00), build/hash, device model/Android version, test-data alias, exact steps, actual response/visible text, status and evidence paths in `testing_evidence/logs/integration/TC-NNN_manual.md`. Use PASS only after all stated acceptance checks are observed; FAIL for an observed unmet condition; BLOCKED for a missing prerequisite; NOT RUN when no execution occurred. Never infer Firebase persistence from a snackbar alone.

For Firebase evidence, open only the approved emulator UI or dedicated test console and record relevant field names/counts with UID/email anonymized. For FastAPI, record method/path/status, anonymized IDs and nonsecret metadata; do not log Authorization headers, API keys, full image base64 or private download URLs. For no-write/cancel cases compare before/after counts and request logs. The proposed replacements for unavailable features require agreement before substituting them for original FYP requirements.

'''
    for case in cases:
        manual += f"""## {case['id']} — {case['scenario']} ({case['uc']})

**Current original-scenario status:** {case['status']}. **Test data:** {case['data']}

**Steps:** {case['steps']}

**Expected behavior:** {case['expected']}

**Screenshot timing:** {case['moment']} **Save as:** `testing_evidence/{case['proposed_screenshot']}`. This is a planned Android/manual filename, not the existing widget PNG filename.

**Supporting Firebase/FastAPI evidence:** {SUPPORT[case['support']]}

**Existing evidence/remaining gap:** {case['actual']} See {link(case['evidence'], case['id'] + ' automated evidence')}.

"""
    (reports / 'Manual_Testing_Guide.md').write_text(manual, encoding='utf-8')
    (EVIDENCE / 'screenshots/README.md').write_text('''# Screenshot evidence

Only three actual widget-render captures currently exist, under UC-01/02/03 with `_widget.png` suffixes. They use synthetic/empty data and an 800x1000 Flutter test surface, not an Android device. Captures were visually inspected after loading installed SDK fonts; underlying semantic assertions are in the added-readable Flutter log. Other UC folders are intentionally empty because no device screenshots were collected. Follow the manual guide for planned filenames; do not treat planned filenames as evidence.
''', encoding='utf-8')
    (EVIDENCE / 'logs/firebase/integration_status.md').write_text('''# Firebase integration status

NOT EXECUTED. Firebase CLI 15.24.0 is installed. No configured emulator routing variables or emulator block in application firebase.json; common localhost emulator ports were closed at probe time. No dedicated test account/project was supplied or used. Existing app initializes Firebase from its configured options. No Firebase accounts, data, settings, dependencies or security rules were changed. Unit tests inject Firebase fakes; backend token verification tests mock Google verification. Version-command output is tool evidence only.
''', encoding='utf-8')
    (EVIDENCE / 'README.md').write_text('''# StyleSync QA evidence

Start with [Functional Test Report](reports/StyleSync_Functional_Test_Report.md), [initial audit/coverage plan](reports/Inspection_and_Test_Plan.md), and [manual testing guide](reports/Manual_Testing_Guide.md). The report distinguishes 222 unique automated checks from 36 original scenarios; mocked checks do not establish live AI/Firebase integration. Existing tests and production source/configuration were preserved. Logs, per-case evidence JSON, actual widget PNGs and a SHA-256 manifest are included. Empty screenshot folders indicate no captured evidence. Dates/times use Asia/Kuala_Lumpur.
''', encoding='utf-8')
    manifest = []
    for path in sorted(EVIDENCE.rglob('*')):
        if path.is_file() and path.name != 'Evidence_Manifest.json' and '__pycache__' not in path.parts:
            manifest.append({'path': path.relative_to(EVIDENCE).as_posix(), 'bytes': path.stat().st_size,
                             'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (reports / 'Evidence_Manifest.json').write_text(json.dumps({'generated_at': stamp(), 'files': manifest}, indent=2), encoding='utf-8')
    print(json.dumps({'automated': counts, 'scenarios': summary, 'artifacts': len(manifest), 'existing_test_files_preserved': len(preserved)}, indent=2))


if __name__ == '__main__':
    main()

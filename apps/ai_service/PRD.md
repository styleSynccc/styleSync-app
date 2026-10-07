# Digital Twin Pipeline: PRD and Status

Scope: turn one full-body photo of a user into a stored "digital twin" (clean 768×1024 person image, pose landmarks, hijab info), and garment/hijab photos into stored wardrobe items, both prepped the same way so a later try-on stage can use them directly.

Pipeline version: `twin-0.6.0`

Status legend: `[x]` done and verified · `[~]` done, only partly verified (see note) · `[ ]` not done

---

## 1. Goal

A user uploads a full-body photo and gets a twin that later try-on stages can use. It must work for **men, women without hijab, and women with hijab**, including loose clothing. Test devices: **Samsung Galaxy A55** (testing) and **Samsung Galaxy A07** (budget phone, the real demo).

## 2. Flow (from the workflow doc)

```
Flutter app --(photo + Firebase token)--> POST /v1/twins
  1. Verify token
  2. Validate image (size, resolution), fix EXIF orientation, resize/pad to 768x1024
  3. Pose check  (reject bad photos BEFORE the expensive step)
  4. Remove background
  5. Enhance quality (denoise, local contrast, sharpen) - see §4
  6. Flatten onto white
  7. Hijab analysis: detect + head-covering mask
  8. Save original, processed image, landmarks, hijab mask, metadata
```

`POST /v1/wardrobe` (garment/hijab items) follows the same steps 2, 4–6, 8, minus the pose check and hijab analysis (no person in these photos) - see §8.

The app instructs users to face the camera and show their whole body, so the pipeline does not check head direction, body cropping, or the number of people.

## 3. Requirements and status

### 3.1 Input handling
- [x] Reject empty and corrupt files; reject uploads over 25 MB (chunked read stops early; oversized `Content-Length` returns 413)
- [x] Pixel limit 100 MP, decoded downscaled to 3072 px long side (a full 50 MP decode would use ~450 MB per request). Tested with a synthetic 8160×6120 JPEG; comfortably covers real files too (see below)
- [x] Reject photos under 320 px on the short side or 640 px on the long side (screenshots, heavily compressed forwards)
- [x] Apply EXIF rotation, resize without stretching, centre on a white 768×1024 canvas
- [x] Detect file type from the real bytes, never from client headers
- [x] **Verified on 2 real, uncompressed A55 photos** (not WhatsApp copies): Galaxy A55 5G actually shoots 4080×3060 (12.5 MP), 7.4–7.6 MB, not the ~50 MP this doc assumed earlier — that assumption is corrected. Both files passed every check: EXIF rotation applied correctly (sensor 4080×3060 → portrait 3060×4080 with no code changes needed), downscaled to 2304×3072 for processing, clean background removal
- [ ] **Still not verified:** a real A07 photo (the demo device). The A07 is a lower-tier phone than the A55, so its camera, sensor noise and megapixel count may differ — a working A55 photo is not proof the A07 will behave the same
- [ ] Flutter client should also downscale/compress before upload (saves the user's mobile data)

### 3.2 Pose check (reject unsuitable photos)
- [x] Landmarks from MediaPipe; heavy calls run off the event loop and the pose model is locked (not thread-safe)
- [x] Side profile: shoulder-to-torso ratio (framing-independent). Validated on real photos
- [x] Sitting: skipped, not guessed, when hips/knees are hidden by long clothing
- [x] Arms hidden: wrist threshold 0.5 so valid photos with loose sleeves are not rejected
- Removed by decision (user instructions cover them): head-turned check, cropped head/feet check, multiple-people check

### 3.3 Background removal and quality enhancement
- [x] rembg (`isnet-general-use`), result flattened onto white
- [x] Hijab fabric survived on all 10 hijab test photos (checked by eye)
- [~] Men's and non-hijab cutouts were not inspected by eye
- [ ] Clean up leftovers when the person touches something (tree branch, car door, fence, bag strap, stray lines)
- [x] **Quality enhancement, added this session** - see §4 for the full story, including a real problem found and fixed before shipping

### 3.4 Hijab analysis
- [x] `HijabAnalyzer` interface; result saved as `wearsHijab` + `hijab_mask.png`
- [x] **Detection** (`MediaPipeHijabAnalyzer`, no training): MediaPipe multiclass segmenter on a head-and-shoulders crop. A hijab is labelled as clothing, never hair, with no neck skin. Rule: hair + neck-skin share of the crop < 1% → hijab. Result on real photos: 22 of 22 photos that pass the pose check classified correctly (11 hijab, 11 not)
- [~] Detection thresholds were chosen looking at the same photos they were tested on. Margins were wide (hijab 0.0–0.1% vs 2.9%+ for others), but it has not been tested on new people
- [~] **Mask** (baseline): clothing connected to the face, cut 0.35 shoulder-widths below the shoulder line. Covers the head hijab well, excludes the face, but **includes the shirt at the shoulders and drops long hijab tails**. Judged by eye only; it is a "head and shoulder area" mask, not an exact hijab outline
- [ ] **Exact hijab-vs-garment segmentation.** The off-the-shelf model cannot separate them (same class). Needs a trained model (labelled hijab masks) or a promptable segmenter; plugs in through `HijabAnalyzer`. Compared the MediaPipe baseline mask against SAM (ViT-B, ONNX) on 10 hijab photos: SAM gives a tighter hijab-only mask on some photos but only partially covers the hijab on 3–4 of 10, and runs 6–140s/photo on this CPU — too slow and too inconsistent to switch to yet
- [ ] Known detection risks not tested: songkok/cap on men, hair partly showing, niqab (no face found returns `wearsHijab: null`), hijab in a dark colour on a dark background
- [ ] Hijab style detection (shawl, pashmina, instant, khimar) — belongs to the wardrobe flow, not the twin

### 3.5 Storage and auth
- [x] Save per twin: `original.*`, `processed.jpg`, `landmarks.json`, `hijab_mask.png` (if hijab), `metadata.json` (written last)
- [x] Path-safe IDs (no directory traversal)
- [x] **List endpoints added this session**: `GET /v1/twins`, `GET /v1/wardrobe` - this user's saved twins/items, newest first, each with its processed image inline (base64). Needed so the Flutter wardrobe/twin screens show more than just what was uploaded in the current session. See §5
- [~] Firebase ID-token auth: missing/invalid token returns 401 (tested). Verifying a **real** token was not tested (no service-account credentials here)
- [ ] Firebase Storage + Firestore store (currently local disk under `data/`)

### 3.6 Quality and tooling
- [x] 55 automated tests pass (fake pose/background engine; hijab logic tested on hand-built label images)
- [x] End-to-end run with the **real** models on all 26 photos: 22 twins saved with correct artifacts and metadata
- [x] `scripts/check_pose.py` prints the pose measurements and saves cutouts; `scripts/check_hijab.py` compares baseline vs SAM hijab masks; `scripts/download_models.py` fetches the 16 MB hijab model
- [x] `requirements.txt` (UTF-8, direct dependencies only) installs cleanly in a fresh venv
- [x] `.gitignore` covers `data/`, `samples/`, `.venv/` so user photos cannot be committed by accident
- [x] CORS enabled (`cors_allow_all`, on by default) so the Flutter **web** build can call this API from its own dev-server origin — off before any real deployment
- [ ] Load test: concurrent uploads were not tried
- [ ] Test photos still missing: floor-length abaya, niqab, black hijab on a dark background, and a real A07 photo (the demo device, so it matters most). The 2 real A55 photos received were both men without hijab, so hijab detection/mask are still only validated on phone-compressed (WhatsApp-style) photos, not genuine camera files

**Deployment note:** run `python -m scripts.download_models` once; without the model file the service still works but saves `wearsHijab: null` (a warning is logged). Start the live server with `uvicorn app.main:app --host 0.0.0.0 --port 8000` (0.0.0.0, not 127.0.0.1, or the Android emulator/a physical phone can't reach it).

## 4. Quality enhancement (added this session)

Goal (your request): same treatment as the digital twin for wardrobe items - remove background, then clean up the photo so it's easier for a later VTON model to work with. No super-resolution: our photos are always *downscaled* to 768×1024 (every phone tested so far shoots well above that), so there's no low-resolution source to upscale, and adding one would mean a new GPU/PyTorch dependency in a pipeline that's deliberately stayed CPU-only and fast.

**What it does** (`app/imaging.py: enhance_quality`), applied to both the twin and every wardrobe item, after background removal and before compositing onto white:
1. Denoise (`cv2.fastNlMeansDenoisingColored`, `h=8`) - removes sensor noise
2. Local contrast (CLAHE on the LAB lightness channel only) - fixes flat/dim exposure
3. Sharpen (mild unsharp mask, `amount=0.3`) - restores edge crispness lost to compression/motion blur

**A real problem was found and fixed before shipping, not after:** the first version also did gray-world white balance (auto color-cast correction). Tested on real photos, it measurably shifted a navy shirt toward charcoal grey and warmed up skin tone — gray-world assumes a frame's average colour should be neutral, which breaks when one strong colour dominates the frame, which is routine for a photo of a single garment. For a fashion app, getting the garment's real colour wrong is worse than leaving a mild colour cast alone, so **white balance was dropped entirely**; only CLAHE (which doesn't touch hue/saturation) remains for contrast. A tightened version of the gray-world gain was also tried and still shifted colour visibly — the technique itself was the problem, not the strength.

- [x] Denoising verified: synthetic sensor noise (σ=20) cut ~9x
- [x] Sharpening verified: restores edge contrast lost to blur
- [x] Contrast verified: a flat/dim synthetic photo gets real dynamic range back
- [x] Garment-colour preservation verified: hue unchanged on a dominant-colour test image (this is the regression test for the bug above)
- [x] A flat/zero-variance input (e.g. test fixtures) is left untouched - CLAHE on a genuinely flat region can shift its value arbitrarily (nothing to spread across histogram bins), guarded against explicitly
- [x] Before/after comparison run on 3 real photos (1 hijab, 1 men's, 1 non-hijab women's) - denoising and sharpness improvements visible by eye; garment colour unchanged after the white-balance removal
- [x] Cost measured: **~1.3s added per image** (A/B tested in the same process to isolate it from other machine load). Denoising is the dominant cost
- [ ] Not tested on a genuinely noisy/dim low-light photo from a real phone (only synthetic noise and the existing, already well-lit sample photos)
- [ ] CLAHE is not mask-aware: at the subject/background boundary, leftover background-coloured pixels (BGR values are undefined where rembg's alpha=0) can influence nearby tile statistics. Not observed as a visible problem in the 3 photos checked, but not specifically tested for

## 5. Rejection rules (current)

| Code | Rule | User can fix by retaking? | Confidence |
|---|---|---|---|
| `INVALID_IMAGE` (400) | Empty, corrupt, >25 MB, >100 MP, or under 320×640 px | Yes | Size rules not tested on a real A07 photo |
| `NO_BODY_DETECTED` (422) | Pose model finds no person | Yes | Good (photo 46) |
| `INVALID_POSTURE` / `SIDE_PROFILE` | Shoulder/torso ratio < 0.70 | Yes | Good: valid 0.78–0.94, negatives 0.11–0.62 |
| `INVALID_POSTURE` / `SITTING` | Thigh/torso < 0.4 (only if hips+knees visible) | Yes | One real example (0.26 vs ≥0.65) |
| `INVALID_POSTURE` / `ARMS_HIDDEN` | Either wrist visibility < 0.5 | Mostly | Weak: a hands-behind-back photo (0.58) passes |
| `BACKGROUND_REMOVAL_FAILED` (500) | Cutout cannot be decoded | n/a (server side) | Rare |

## 6. API contract

`POST /v1/twins`: multipart field `file`, header `Authorization: Bearer <Firebase ID token>`
- **201**: `{ success, twinId, metadata, landmarks[33], personImageB64 }`

`GET /v1/twins`: same header, no body
- **200**: `{ success, twins: [{ twinId, metadata, personImageB64 }, ...] }`, newest first

`POST /v1/wardrobe`: multipart field `file` + form fields `category`, `style` (hijab only), header as above
- **201**: `{ success, itemId, metadata, itemImageB64 }`

`GET /v1/wardrobe`: same header, no body
- **200**: `{ success, items: [{ itemId, metadata, itemImageB64 }, ...] }`, newest first

`POST /v1/tryon`: JSON body `{ twinId, garmentItemId, hijabItemId? }`, header as above - see §9

**Errors** (all endpoints): `{ success:false, error_type, message, reason? }` with status 400 / 401 / 404 / 413 / 422 / 500 / 501

`metadata` (twin): `twinId, uid, status, wearsHijab (true/false/null), hijabConfidence (currently null), hijabAnalyzer, poseChecksSkipped, imageWidth, imageHeight, pipelineVersion, createdAt`. Landmarks and the hijab mask are in the padded 768×1024 image's coordinates.

## 7. Decisions

- **Decided:** wrist threshold 0.5 (a hands-behind-back photo now passes).
- **Decided:** no head-direction, cropping, or multi-person checks; the app instructs the user instead.
- **Decided:** resolution stays a hard requirement (demo device is a budget phone).
- **Decided:** quality enhancement = denoise + CLAHE contrast + mild sharpen. No white balance (see §4), no super-resolution.
- **Open:** exact hijab segmentation needs a trained model, or a better-prompted SAM. Does labelled data exist, or keep trying promptable segmenters first?
- **Open:** when to move from local disk to Firebase Storage + Firestore.
- **Open:** CatVTON vs IDM-VTON for the real try-on model - the user is testing both locally (RTX 4050, 6GB VRAM); not done in this service.

## 8. Results on the 26 test photos (real models, full pipeline)

| Group | Photos | Accepted | Hijab detected |
|---|---|---|---|
| Men | 5 | 5 | 0 (correct) |
| Women without hijab | 6 | 6 | 0 (correct) |
| Women with hijab | 10 | 10 | 10 (correct) |
| Extra: side profile / sitting / three-quarter / turned away (all hijab) | 4 | 0 (rejected) | n/a |
| Extra: hands behind back, black hijab | 1 | 1 | 1 (correct) |

Sample size is small. Thresholds are calibrated on these photos only.

## 9. Garment and hijab-wardrobe uploads (`POST /v1/wardrobe`)

Per the workflow doc's "user uploads garment photo" / "user uploads hijab photo in the wardrobe" steps. Takes `file` + `category` (`Tops`/`Pants`/`Shoes`/`Accessories`/`Hijab` — matches the mobile_app closet UI's own category labels exactly, see `home_screen.dart`'s `_categoryOrder`) + `style` (`Hijab` only: `shawl`/`pashmina`/`instant`/`khimar`).

Unlike the digital twin, there's no person in these photos, so **no pose check**. "Segmenting the hijab" here is a different, easier problem than §3.4's open item: the photo shows the hijab alone, so rembg's own foreground mask (its alpha channel) already is a correct outline. This does **not** solve the twin's exact hijab-vs-garment segmentation problem (separating hijab from the shirt it's worn with) — that's still open.

- [x] Validate category/style against a fixed vocab; style required (and only meaningful) for `hijab`
- [x] Reuses the twin pipeline's validated input handling (size/resolution/EXIF), background removal, **and quality enhancement** (§4 - added this session, same reasoning applies)
- [x] Rejects a blank/near-empty photo (`NO_GARMENT_DETECTED`) via a foreground-ratio check on the alpha mask
- [x] Hijab items save a `mask.png` (the foreground mask); other categories don't need one yet
- [x] `GET /v1/wardrobe` lists this user's items, newest first (added this session, for the Flutter wardrobe screen)
- [x] 9 automated tests (fake engine); smoke-tested with the real engine on 2 of the existing person photos (stand-ins — not real garment photos, so the foreground-ratio numbers aren't representative)
- [ ] **No real garment or hijab-alone photos tested.** Framing, background and the `min_garment_foreground_ratio` threshold (0.02, picked with no data) are all unverified
- [ ] Hijab style is "ask", not "detect" — no classifier exists for shawl/pashmina/instant/khimar
- [ ] Multiple items in one photo, or a person accidentally in the garment photo, are not detected
- [ ] Same storage/auth caveats as the twin pipeline (local disk, token verification untested with a real token)

## 10. Try-on orchestration (`POST /v1/tryon`)

Per the workflow doc's "user picks: twin + clothing item + hijab (optional)" step, through the two-stage try-on. Takes `twinId` + `garmentItemId` + optional `hijabItemId` (JSON body, no file upload — it references items already saved by `/v1/twins` and `/v1/wardrobe`).

**The actual image generation is NOT implemented.** A real try-on model (CatVTON or IDM-VTON - the user is testing both locally) is a diffusion model with multi-GB weights, normally run on a GPU — that's a separate effort from what's built here. `NotImplementedTryOnEngine` is wired in by default and raises `TRY_ON_NOT_IMPLEMENTED` (501) immediately. What *is* built and tested is everything around it:

- [x] Loads the twin and garment from storage; 404s if either doesn't exist for this user
- [x] Rejects a hijab item passed as `garmentItemId`, and a non-hijab item passed as `hijabItemId` (`INVALID_WARDROBE_ITEM`, 400)
- [x] If `hijabItemId` is omitted, the twin's **own** hijab mask (from its own photo, if any) protects that area during the clothing stage — this is correct as-is, since that mask is already in the twin's own canvas coordinates
- [x] If `hijabItemId` is given, stage 1 runs first and **must return where it placed the hijab** on the person — that returned mask, not the hijab item's flat-lay mask, is what protects it in stage 2. (Caught before shipping: the flat-lay mask is in the wardrobe photo's own coordinates, not the twin's — using it directly would have protected the wrong pixels.)
- [x] Result is persisted (`data/results/<uid>/<resultId>/`), same pattern as twins and wardrobe items
- [x] 9 automated tests (fake engine, verifies protection pixel-by-pixel) + smoke-tested against real twin/garment artifacts produced by the real pipelines (not hand-built fixtures) — confirms loading, validation, and the not-implemented error all fire correctly end to end
- [ ] **No real try-on model wired in.** User is testing CatVTON and IDM-VTON locally; neither is connected to this service yet
- [ ] The "paste back protected pixels if needed" step from the workflow doc isn't built — `protect_mask` is passed to `apply_garment`, but what the engine does with it depends on the real model's behavior, which doesn't exist yet to test against
- [ ] Same storage/auth caveats as twins and wardrobe (local disk, token verification untested with a real token)

## 11. Flutter UI ("link into the UI")

Wires the mobile app to `/v1/twins` and `/v1/wardrobe`. **Click-through verified end to end** against the live backend, over real Firebase, in Chrome (web build).

- [x] `http` + `file_picker` added (not `image_picker`: no official Windows desktop support, and Windows desktop is one of the two working dev targets here, alongside Chrome/Edge - Visual Studio isn't installed, so Windows desktop can't actually *build* yet despite showing as a target)
- [x] `AiService` (`lib/services/ai_service.dart`): typed client for all four endpoints, Firebase ID token attached automatically, server error messages surfaced as-is (they're already written for a user to read)
- [x] Screens: Home (post-login landing - there wasn't one before), Digital Twin (upload + gallery of past twins), Wardrobe (grid + add-item sheet with category/style)
- [x] Fixed: login/signup/Google sign-in now navigate to Home on success (previously went nowhere); a restored session on launch goes straight to Home instead of login; `signOut()` added (didn't exist before); `Get.put(AuthController())` moved out of `build()` (was re-registering on every rebuild)
- [x] `flutter analyze`: no issues. `flutter build web`: compiles
- [x] **End-to-end click-through verified** via headless Chromium (`chromium-cli` isn't available here, so a small Playwright driver was used instead): sign up with a throwaway account → real Firebase Auth creates the user and a real Firestore write succeeds → lands on Home → Digital Twin screen → pick a real sample photo → `Create My Twin` → real `POST /v1/twins` (201) → twin appears in the gallery, pipeline version `twin-0.6.0` confirms the quality-enhancement code ran. Same for Wardrobe: `Add Item` → category `top` → pick a photo → `Upload` → real `POST /v1/wardrobe` (201) → saved. `GET /v1/twins`/`GET /v1/wardrobe` also confirmed working (used by both screens on load)
- [~] Flutter Web specifically: CanvasKit renders to a single canvas with no DOM/accessibility tree, so driving it headlessly needed coordinate clicks instead of selectors, plus retries - clicks occasionally miss on the first attempt (confirmed via temporary debug logging that this is headless-rendering flakiness under CPU load, not an app bug: `register()` completes correctly every time it's actually invoked). Not something to fix in the app; noted here because it affects how this gets re-verified later
- [ ] Windows desktop build untested (Visual Studio not installed - `flutter build windows` fails with "Unable to find suitable Visual Studio toolchain")
- [x] **Android debug build now succeeds** (`flutter build apk --debug` → a real 152 MB `app-debug.apk`). Not run on a device/emulator yet - only confirmed it builds. Three real, unrelated bugs found and fixed along the way:
  - `android/build.gradle.kts` declared `com.google.gms.google-services` a second time at a conflicting version (4.4.0) against the one FlutterFire already set up in `settings.gradle.kts` (4.3.10) - Gradle refused to resolve the plugin at all. Removed the duplicate.
  - Android NDK 28.2.13676358 (required by `flutter.ndkVersion`) wasn't installed, and Gradle's auto-download silently failed. Installed manually; this newer "Android CLI" tool (replacing the deprecated `sdkmanager`) is itself flaky under this environment (a package install hung for ~28 minutes with no output before finishing - see git history/session notes, not worth repeating unless it recurs).
  - `android/app/build.gradle.kts`'s `applicationId` was still Flutter's template default (`com.example.mobile_app`), which doesn't match any entry in `google-services.json` - Firebase has this app registered as `com.styleSync_app` instead. Changed `applicationId` only (not `namespace`, so no Kotlin source files needed moving). **`com.styleSync_app` is an unconventional Android package name** (mixed case, underscore) - worth registering a proper reverse-domain one (e.g. `com.stylesync.app`) in the Firebase console and swapping it in here before this ships anywhere real.
  - The actual AGP/Gradle/Kotlin versions this Flutter SDK (3.47.2) had scaffolded - AGP 9.0.1, Gradle 9.1.0, Kotlin 2.3.20 - are all very recently released. AGP 9 enforces stricter AAR-metadata compileSdk checks that `file_picker` 8.0.7's published AAR doesn't meet (built against compileSdk 34). Downgraded all three together to the lowest versions this Flutter SDK will still accept (it has its own floors, hit one at a time: AGP ≥8.11.1, Gradle ≥8.14.0, Kotlin ≥2.2.20) - low enough to avoid AGP 9's stricter check, which fixed it. Flutter now prints "will soon be dropped, upgrade to AGP 9.0.1/Gradle 9.1.0/Kotlin 3.3.20" warnings on every build - **not urgent, but `file_picker` (or an alternative) will need to catch up to AGP 9 before those upgrades can happen**
- [ ] Only the "happy path" was click-through tested (web). Rejection flows (e.g. a bad-pose photo, an invalid category) are exercised by the backend's own tests but not through the UI. The Android build hasn't been click-through tested at all (no device/emulator here) - only confirmed to compile

## 12. Not started (later work)

- [ ] Windows desktop build (§11); Android click-through testing on a device/emulator
- [ ] A real try-on model - CatVTON/IDM-VTON testing is happening on the user's PC, outside this service (see §10, §7)
- [ ] Repo work: Firestore security rules, fix Codemagic Flutter version and the missing `integration_test/`, clean `.gitignore`/`README.md`, delete the stray `git` file
- [ ] Commit this work; delete the old root `main.py` and `requirement.txt` (superseded)

import io
import base64

import cv2
import numpy as np
import mediapipe as mp

from fastapi import FastAPI, File, UploadFile
from fastapi.responses import Response, JSONResponse
from rembg import remove, new_session
from PIL import Image, ImageOps

app = FastAPI()

# ---- Load heavy models ONCE at startup ----
session = new_session("isnet-general-use")

mp_pose = mp.solutions.pose
mp_drawing = mp.solutions.drawing_utils
pose_detector = mp_pose.Pose(static_image_mode=True, model_complexity=1)

MAX_DIM = 1024                       # Max edge length for standard endpoints
MAX_UPLOAD_BYTES = 15 * 1024 * 1024  # 15MB upload limit

# Standard target dimensions required by OOTDiffusion (3:4 aspect ratio)
TARGET_WIDTH = 768
TARGET_HEIGHT = 1024


class ImageValidationError(Exception):
    """Raised when an uploaded file fails validation before any processing starts."""
    pass


def load_and_fix_orientation(input_bytes: bytes) -> np.ndarray:
    """
    Decodes uploaded image, fixes EXIF orientation tags, and returns a BGR OpenCV array.
    """
    try:
        pil_image = Image.open(io.BytesIO(input_bytes))
        pil_image = ImageOps.exif_transpose(pil_image)  # Applies rotation, strips EXIF tag
        pil_image = pil_image.convert("RGB")
    except Exception as e:
        raise ImageValidationError(f"Could not read image: {e}")

    rgb_array = np.array(pil_image)
    return cv2.cvtColor(rgb_array, cv2.COLOR_RGB2BGR)


def validate_upload(file: UploadFile, input_bytes: bytes):
    """
    Validate size and actual image content. We deliberately do NOT trust
    file.content_type here — it's a client-supplied header, and Postman,
    curl, and some HTTP libraries (including some Flutter multipart setups)
    send 'application/octet-stream' for perfectly valid images. The real
    check happens later in load_and_fix_orientation, which will raise
    ImageValidationError if Pillow can't actually decode the bytes.
    """
    if len(input_bytes) == 0:
        raise ImageValidationError("Uploaded file is empty.")
    if len(input_bytes) > MAX_UPLOAD_BYTES:
        raise ImageValidationError(
            f"File too large ({len(input_bytes) / 1_000_000:.1f}MB). "
            f"Max is {MAX_UPLOAD_BYTES / 1_000_000:.0f}MB."
        )


def resize_and_pad_to_target(image: np.ndarray, target_w=TARGET_WIDTH, target_h=TARGET_HEIGHT) -> np.ndarray:
    """
    Resizes image without stretching and centers it on a target_w x target_h
    white canvas. Uses INTER_AREA for downscaling (sharper on shrink) and
    INTER_CUBIC for upscaling (INTER_AREA blurs when scale > 1.0).
    """
    h, w = image.shape[:2]
    scale = min(target_w / w, target_h / h)

    new_w = int(w * scale)
    new_h = int(h * scale)

    interp = cv2.INTER_AREA if scale < 1.0 else cv2.INTER_CUBIC
    resized = cv2.resize(image, (new_w, new_h), interpolation=interp)

    # Create white canvas
    canvas = np.full((target_h, target_w, 3), 255, dtype=np.uint8)

    # Center the resized image on the canvas
    x_offset = (target_w - new_w) // 2
    y_offset = (target_h - new_h) // 2
    canvas[y_offset:y_offset + new_h, x_offset:x_offset + new_w] = resized

    return canvas


def convert_transparent_to_white(rgba_image: np.ndarray) -> np.ndarray:
    """
    Converts transparent PNG (alpha channel) from rembg into a solid white background.
    """
    if rgba_image.shape[2] == 4:
        alpha = rgba_image[:, :, 3] / 255.0
        bgr = rgba_image[:, :, :3]

        white_bg = np.ones_like(bgr, dtype=np.uint8) * 255

        for c in range(0, 3):
            white_bg[:, :, c] = (alpha * bgr[:, :, c] + (1 - alpha) * white_bg[:, :, c])

        return white_bg
    return rgba_image


def validate_pose_for_tryon(landmarks) -> tuple[bool, str]:
    """
    Validates whether the subject's pose is suitable for OOTDiffusion.
    Checks for side profiles, sitting/squatting posture, hidden arms, and head direction.
    """
    nose = landmarks[0]
    left_shoulder = landmarks[11]
    right_shoulder = landmarks[12]
    left_wrist = landmarks[15]
    right_wrist = landmarks[16]
    left_hip = landmarks[23]
    right_hip = landmarks[24]
    left_knee = landmarks[25]
    right_knee = landmarks[26]

    # TEST 1: Check for side profile
    shoulder_width = abs(left_shoulder.x - right_shoulder.x)
    if shoulder_width < 0.18:
        return False, "Side profile detected. Please stand facing directly towards the camera."

    # TEST 2: Check for sitting or squatting
    hip_y = (left_hip.y + right_hip.y) / 2
    knee_y = (left_knee.y + right_knee.y) / 2
    shoulder_y = (left_shoulder.y + right_shoulder.y) / 2

    torso_length = abs(hip_y - shoulder_y)
    thigh_length = abs(knee_y - hip_y)

    if thigh_length < (torso_length * 0.4):
        return False, "Sitting or squatting posture detected. Please upload a full standing photo."

    # TEST 3: Check for hidden or behind-the-back arms
    if left_wrist.visibility < 0.6 or right_wrist.visibility < 0.6:
        return False, "Hands/arms are hidden or behind your back. Please keep your arms visible at your sides."

    # TEST 4: Check for turned head
    shoulder_center_x = (left_shoulder.x + right_shoulder.x) / 2
    if abs(nose.x - shoulder_center_x) > 0.08:
        return False, "Head is turned away. Please look straight at the camera."

    return True, "Pose is valid and ready for processing."


def resize_if_needed(image: np.ndarray, max_dim: int = MAX_DIM) -> np.ndarray:
    h, w = image.shape[:2]
    scale = max_dim / max(h, w)
    if scale < 1.0:
        image = cv2.resize(image, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    return image


def prepare_upload(file: UploadFile, input_bytes: bytes) -> np.ndarray:
    validate_upload(file, input_bytes)
    image = load_and_fix_orientation(input_bytes)
    image = resize_if_needed(image)
    return image


@app.get("/health")
def health_check():
    return {"status": "AI server is running"}


@app.post("/remove-bg")
async def remove_background(file: UploadFile = File(...)):
    input_bytes = await file.read()
    try:
        image = prepare_upload(file, input_bytes)
    except ImageValidationError as e:
        return JSONResponse(status_code=400, content={"error": str(e)})

    _, encoded = cv2.imencode(".png", image)
    output_bytes = remove(encoded.tobytes(), session=session)
    return Response(content=output_bytes, media_type="image/png")


@app.post("/extract-pose")
async def extract_pose(file: UploadFile = File(...)):
    input_bytes = await file.read()
    try:
        image = prepare_upload(file, input_bytes)
    except ImageValidationError as e:
        return JSONResponse(status_code=400, content={"error": str(e)})

    results = pose_detector.process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))

    if not results.pose_landmarks:
        return JSONResponse(status_code=422, content={"error": "No body detected in image"})

    mp_drawing.draw_landmarks(image, results.pose_landmarks, mp_pose.POSE_CONNECTIONS)
    _, encoded_image = cv2.imencode(".png", image)
    return Response(content=encoded_image.tobytes(), media_type="image/png")


@app.post("/generate-twin")
async def generate_twin(file: UploadFile = File(...)):
    input_bytes = await file.read()

    # 1. Validate file and fix EXIF orientation
    try:
        validate_upload(file, input_bytes)
        raw_image = load_and_fix_orientation(input_bytes)
    except ImageValidationError as e:
        return JSONResponse(status_code=400, content={"error": str(e)})

    # 2. Fit image into standard 768x1024 resolution with padding
    padded_image = resize_and_pad_to_target(raw_image)

    # 3. Extract pose & validate posture BEFORE running heavy background removal
    image_rgb = cv2.cvtColor(padded_image, cv2.COLOR_BGR2RGB)
    results = pose_detector.process(image_rgb)

    if not results.pose_landmarks:
        return JSONResponse(
            status_code=422,
            content={"error": "No human body detected. Please upload a clear full-body photograph."}
        )

    landmarks = results.pose_landmarks.landmark
    is_valid, pose_message = validate_pose_for_tryon(landmarks)

    if not is_valid:
        return JSONResponse(
            status_code=422,
            content={
                "success": False,
                "error_type": "INVALID_POSTURE",
                "message": pose_message
            }
        )

    # 4. Perform background removal (rembg)
    _, encoded = cv2.imencode(".png", padded_image)
    bg_removed_bytes = remove(encoded.tobytes(), session=session)

    np_arr = np.frombuffer(bg_removed_bytes, np.uint8)
    transparent_img = cv2.imdecode(np_arr, cv2.IMREAD_UNCHANGED)

    if transparent_img is None:
        return JSONResponse(
            status_code=500,
            content={"error": "Failed to remove image background."}
        )

    # 5. Convert background to solid white
    final_person_image = convert_transparent_to_white(transparent_img)

    # 6. Encode final image to Base64 and return JSON response
    _, final_buffer = cv2.imencode(".jpg", final_person_image, [int(cv2.IMWRITE_JPEG_QUALITY), 95])
    image_b64 = base64.b64encode(final_buffer).decode("utf-8")

    return JSONResponse(content={
        "success": True,
        "message": "Digital Twin generated successfully!",
        "image_width": TARGET_WIDTH,
        "image_height": TARGET_HEIGHT,
        "person_image_b64": image_b64,
        "landmarks": [
            {"x": lm.x, "y": lm.y, "z": lm.z, "visibility": lm.visibility}
            for lm in landmarks
        ]
    })
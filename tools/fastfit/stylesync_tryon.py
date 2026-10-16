"""StyleSync one-item-at-a-time try-on, on top of FastFit.

Flow (docs/virtual-tryon/README.md):
  1. pick one cloth (Top, Bottom or Shoes)
  2. generate
  3. show the result
  4. add another cloth (built on the current result) or delete one

Run from anywhere with FastFit's venv (FastFit cloned next to this repo,
see SETUP.md), then open http://localhost:7860:
  ..\\FastFit\\.venv\\Scripts\\python.exe tools\\fastfit\\stylesync_tryon.py

Set FASTFIT_DIR if FastFit lives somewhere else.
"""
import os
import sys
from pathlib import Path

FASTFIT_DIR = Path(
    os.environ.get("FASTFIT_DIR", Path(__file__).resolve().parents[3] / "FastFit")
)
# FastFit loads its models from relative paths (Models/...).
os.chdir(FASTFIT_DIR)
sys.path.insert(0, str(FASTFIT_DIR))

import gradio as gr  # noqa: E402
from PIL import Image  # noqa: E402

from app import FastFitDemo  # noqa: E402

# FastFit works in 3:4 and center-crops anything else, which would cut the
# head or feet off a tall 9:16 phone photo. So the twin is padded with white
# to 3:4 instead, generated in 3:4, and cropped back to its own shape to show.
FASTFIT_RATIO = 3 / 4

# Wardrobe category -> FastFit generate_image() keyword.
CATEGORIES = {"Top": "upper_img", "Bottom": "lower_img", "Shoes": "shoe_img"}

# FastFit demo defaults.
GEN_SETTINGS = dict(
    ref_height=512, num_inference_steps=30, guidance_scale=2.5,
    use_square_mask=False, seed=42, enable_pose=True,
)


def new_state():
    # steps: one dict per worn item, in the order they were put on.
    # Each step's result is the input for the next one. Images in state are
    # 3:4 (padded); `ratio` is the original photo's width/height.
    return {"twin": None, "ratio": FASTFIT_RATIO, "steps": []}


def pad_to_fastfit(img):
    """Flatten onto white and pad the sides (or top/bottom) to 3:4."""
    img = img.convert("RGBA")
    flat = Image.new("RGBA", img.size, (255, 255, 255, 255))
    img = Image.alpha_composite(flat, img).convert("RGB")
    w, h = img.size
    if w / h < FASTFIT_RATIO:
        size = (round(h * FASTFIT_RATIO), h)
    else:
        size = (w, round(w / FASTFIT_RATIO))
    canvas = Image.new("RGB", size, (255, 255, 255))
    canvas.paste(img, ((size[0] - w) // 2, (size[1] - h) // 2))
    return canvas


def crop_to_ratio(img, ratio):
    """Undo pad_to_fastfit's padding on a 3:4 image."""
    w, h = img.size
    if ratio < w / h:
        new_w = round(h * ratio)
        left = (w - new_w) // 2
        return img.crop((left, 0, left + new_w, h))
    new_h = round(w / ratio)
    top = (h - new_h) // 2
    return img.crop((0, top, w, top + new_h))


def run_fastfit(demo, person, category, cloth):
    garments = {"upper_img": None, "lower_img": None, "dress_img": None,
                "shoe_img": None, "bag_img": None}
    garments[CATEGORIES[category]] = cloth
    image, message = demo.generate_image(person, **garments, **GEN_SETTINGS)
    if image is None:
        raise gr.Error(f"Generation failed: {message}")
    return image


def rebuild_from(demo, state, start, progress):
    """Regenerate every step from index `start` onward."""
    steps = state["steps"]
    for i in range(start, len(steps)):
        progress((i - start) / max(len(steps) - start, 1),
                 desc=f"Putting on {steps[i]['category']}...")
        person = steps[i - 1]["result"] if i > 0 else state["twin"]
        steps[i]["result"] = run_fastfit(demo, person, steps[i]["category"], steps[i]["cloth"])


def current_image(state):
    img = state["steps"][-1]["result"] if state["steps"] else state["twin"]
    return crop_to_ratio(img, state["ratio"]) if img is not None else None


def wearing_text(state):
    if not state["steps"]:
        return "**Wearing:** nothing yet"
    lines = [f"{i + 1}. {s['category']}" for i, s in enumerate(state["steps"])]
    return "**Wearing (in order):**\n\n" + "\n".join(lines)


def view(state, status):
    worn = [s["category"] for s in state["steps"]]
    return (
        state,
        current_image(state),
        wearing_text(state),
        gr.Dropdown(choices=worn, value=worn[-1] if worn else None),
        status,
    )


def build_ui(demo):
    with gr.Blocks(title="StyleSync Try-On") as ui:
        state = gr.State(new_state())
        gr.Markdown("# StyleSync Try-On\nOne item at a time: pick a cloth, "
                    "generate, then add more or delete.")
        with gr.Row():
            with gr.Column():
                # RGBA so a transparent twin photo keeps its alpha and
                # pad_to_fastfit can flatten it onto white (RGB mode turned
                # the transparent area black).
                twin = gr.Image(label="1. Digital twin photo (phone 9:16 is fine)",
                                type="pil", image_mode="RGBA", sources=["upload"],
                                height=480)
                category = gr.Radio(list(CATEGORIES), value="Top", label="2. Category")
                cloth = gr.Image(label="3. Cloth photo", type="pil",
                                 sources=["upload"], height=220)
                add_btn = gr.Button("Generate / Add cloth", variant="primary")
            with gr.Column():
                result = gr.Image(label="Result", type="pil", height=640,
                                  interactive=False)
                wearing = gr.Markdown(wearing_text(new_state()))
                with gr.Row():
                    to_delete = gr.Dropdown(choices=[], label="Remove item")
                    delete_btn = gr.Button("Delete")
                reset_btn = gr.Button("Reset (remove all clothes)")
                status = gr.Markdown()
        outputs = [state, result, wearing, to_delete, status]

        def on_twin(state, twin_img):
            state = new_state()
            if twin_img is not None:
                state["ratio"] = twin_img.width / twin_img.height
                state["twin"] = pad_to_fastfit(twin_img)
            return view(state, "Twin loaded. Pick a cloth." if twin_img else "")

        def on_add(state, category, cloth_img, progress=gr.Progress()):
            if state["twin"] is None:
                raise gr.Error("Upload the digital twin photo first.")
            if cloth_img is None:
                raise gr.Error("Upload a cloth photo first.")
            steps = state["steps"]
            worn = [s["category"] for s in steps]
            if category in worn:
                # Same category again replaces the old item in place, then
                # everything put on after it is redone on the new result.
                i = worn.index(category)
                steps[i] = {"category": category, "cloth": cloth_img, "result": None}
                rebuild_from(demo, state, i, progress)
                return view(state, f"Replaced {category}.")
            steps.append({"category": category, "cloth": cloth_img, "result": None})
            try:
                rebuild_from(demo, state, len(steps) - 1, progress)
            except gr.Error:
                steps.pop()
                raise
            return view(state, f"Added {category}.")

        def on_delete(state, category, progress=gr.Progress()):
            worn = [s["category"] for s in state["steps"]]
            if category not in worn:
                raise gr.Error("Pick an item to remove.")
            i = worn.index(category)
            state["steps"].pop(i)
            if i == len(state["steps"]):
                # It was the last item: the previous result is already there.
                return view(state, f"Removed {category} (no regenerate).")
            rebuild_from(demo, state, i, progress)
            return view(state, f"Removed {category} and redid the items after it.")

        def on_reset(state):
            twin_img, ratio = state["twin"], state["ratio"]
            state = new_state()
            state["twin"], state["ratio"] = twin_img, ratio
            return view(state, "Back to the plain twin photo.")

        twin.change(on_twin, [state, twin], outputs)
        add_btn.click(on_add, [state, category, cloth], outputs)
        delete_btn.click(on_delete, [state, to_delete], outputs)
        reset_btn.click(on_reset, [state], outputs)
    return ui


if __name__ == "__main__":
    build_ui(FastFitDemo()).launch(server_name="0.0.0.0", server_port=7860,
                                   show_error=True)

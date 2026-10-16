# Virtual Try-On

The user dresses their digital twin **one item at a time**.

## Flow

1. User picks one cloth (Tops, Pants or Shoes).
2. AI generates the twin wearing it.
3. Result is shown.
4. User can **add** another cloth (built on the current result) or **delete** one.

Rules:

- Delete the last item → go back to the previous image (no AI run).
- Delete an earlier item → redo the items added after it.
- Pick a category already worn → replaces the old one.
- Accessories and built-in sample items can't be tried on.

## Frontend to-do (`apps/mobile_app/lib/`)

1. **`services/closet_controller.dart`:** make `ClothingItem` load `itemId` from Firestore.
2. **`screens/virtual_tryon_screen.dart`:** rebuild the page:
   - big image: twin photo, then the result
   - "Wearing" list, with ✕ to delete each item
   - "+ Add cloth" button (picker with Tops / Pants / Shoes)
   - "Save Look" and "Reset" buttons
   - loading state (20–60 s) and error state
   - if no twin yet → send the user to Profile
3. **`screens/saved_outfits_screen.dart`:** see "Saved Outfits page" below.
4. **Last:** remove the Outfit Creator (screen, route). The middle home button opens Saved Outfits instead. Check with hhasif first.

Done: steps 1-2, plus Save Look and the result image on Saved Outfits. Not done: the 2 tabs on Saved Outfits, step 4.

## Saved Outfits page

Replaces the Outfit Creator. Shows looks saved from Virtual Try-On and AI Inspo Mirror.

```
┌─────────────────────────────┐
│  Saved Outfits              │
│ [ Virtual Try-On | Inspo ]  │  ← 2 tabs
├─────────────────────────────┤
│  grid of saved results      │
└─────────────────────────────┘
```

- Rename the title "My Outfits" → **"Saved Outfits"**.
- 2 tabs, filtered by `source`:
  - **Virtual Try-On:** result image.
  - **AI Inspo Mirror:** result image + the inspo photo next to it.
- Tap a look → big image, items, delete.

Saved to `users/{uid}/outfits`:

```
{
  name:           "Casual Friday",
  source:         "tryon" | "inspo",
  resultImageUrl: "...",   // twin wearing it
  inspoImageUrl:  "...",   // inspo only
  items:          [ {id, category, imageUrl} ],
  createdAt:      ...
}
```

## Backend API (built)

```
POST /v1/tryon   (JSON)
  twinId:            the user's twinId
  garmentItemId:     wardrobe itemId (Tops, Pants or Shoes)
  startFromResultId: previous resultId (leave out for the first item)
→ { resultId, resultImageB64, metadata: { wearing: [{itemId, category}] } }
```

Running it locally needs 2 processes:

1. FastFit worker (FastFit's venv): `tools/fastfit/fastfit_worker.py` (port 7861)
2. AI service: `uvicorn app.main:app --host 0.0.0.0 --port 8000` (calls the worker)

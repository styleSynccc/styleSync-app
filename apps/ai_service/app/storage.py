import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from .errors import TwinNotFoundError, WardrobeItemNotFoundError

_SAFE_ID = re.compile(r"[A-Za-z0-9_-]{1,128}")

# Stores deal in raw bytes/JSON only, never decoded images - that keeps them
# free of an image-library dependency and makes the later swap to Firebase
# Storage (which also just streams bytes) a smaller change. Decoding is the
# caller's job (see app/tryon.py).


@dataclass(frozen=True)
class StoredTwin:
    metadata: dict
    processed_jpg: bytes
    hijab_mask_png: bytes | None


@dataclass(frozen=True)
class StoredWardrobeItem:
    metadata: dict
    processed_jpg: bytes
    mask_png: bytes | None


class TwinStore(Protocol):
    def save(
        self,
        uid: str,
        twin_id: str,
        *,
        original: bytes,
        original_ext: str,
        processed_jpg: bytes,
        landmarks: list[dict],
        hijab_mask_png: bytes | None,
        metadata: dict,
    ) -> dict[str, str]:
        """Persist all artifacts; returns artifact name -> location."""
        ...

    def load(self, uid: str, twin_id: str) -> StoredTwin:
        """Raises TwinNotFoundError if there's no such twin for this user."""
        ...

    def list(self, uid: str) -> list[StoredTwin]:
        """This user's twins, newest first."""
        ...


class LocalTwinStore:
    """Writes to disk. Swap for a Firebase Storage + Firestore store later."""

    def __init__(self, root: Path):
        self._root = Path(root)

    def save(self, uid, twin_id, *, original, original_ext, processed_jpg,
             landmarks, hijab_mask_png, metadata) -> dict[str, str]:
        for value in (uid, twin_id, original_ext):
            if not _SAFE_ID.fullmatch(value):
                raise ValueError(f"unsafe path component: {value!r}")

        folder = self._root / "twins" / uid / twin_id
        folder.mkdir(parents=True, exist_ok=True)

        files = {
            f"original.{original_ext}": original,
            "processed.jpg": processed_jpg,
            "landmarks.json": json.dumps(landmarks).encode(),
        }
        if hijab_mask_png is not None:
            files["hijab_mask.png"] = hijab_mask_png
        for name, data in files.items():
            (folder / name).write_bytes(data)

        # Written last: a folder without metadata.json is an incomplete twin.
        (folder / "metadata.json").write_text(json.dumps(metadata, indent=2))
        return {name: str(folder / name) for name in [*files, "metadata.json"]}

    def load(self, uid: str, twin_id: str) -> StoredTwin:
        for value in (uid, twin_id):
            if not _SAFE_ID.fullmatch(value):
                raise ValueError(f"unsafe path component: {value!r}")
        folder = self._root / "twins" / uid / twin_id
        meta_path = folder / "metadata.json"
        if not meta_path.exists():
            raise TwinNotFoundError(f"No twin {twin_id!r} for this user.")
        mask_path = folder / "hijab_mask.png"
        return StoredTwin(
            metadata=json.loads(meta_path.read_text()),
            processed_jpg=(folder / "processed.jpg").read_bytes(),
            hijab_mask_png=mask_path.read_bytes() if mask_path.exists() else None,
        )

    def list(self, uid: str) -> list[StoredTwin]:
        if not _SAFE_ID.fullmatch(uid):
            raise ValueError(f"unsafe path component: {uid!r}")
        folder = self._root / "twins" / uid
        if not folder.exists():
            return []
        twins = [self.load(uid, p.name) for p in folder.iterdir() if (p / "metadata.json").exists()]
        twins.sort(key=lambda t: t.metadata.get("createdAt", ""), reverse=True)
        return twins


class WardrobeStore(Protocol):
    def save(
        self,
        uid: str,
        item_id: str,
        *,
        original: bytes,
        original_ext: str,
        processed_jpg: bytes,
        mask_png: bytes | None,
        metadata: dict,
    ) -> dict[str, str]:
        """Persist all artifacts; returns artifact name -> location."""
        ...

    def load(self, uid: str, item_id: str) -> StoredWardrobeItem:
        """Raises WardrobeItemNotFoundError if there's no such item for this user."""
        ...

    def list(self, uid: str) -> list[StoredWardrobeItem]:
        """This user's wardrobe items, newest first."""
        ...


class LocalWardrobeStore:
    """Writes to disk. Swap for a Firebase Storage + Firestore store later."""

    def __init__(self, root: Path):
        self._root = Path(root)

    def save(self, uid, item_id, *, original, original_ext, processed_jpg,
             mask_png, metadata) -> dict[str, str]:
        for value in (uid, item_id, original_ext):
            if not _SAFE_ID.fullmatch(value):
                raise ValueError(f"unsafe path component: {value!r}")

        folder = self._root / "wardrobe" / uid / item_id
        folder.mkdir(parents=True, exist_ok=True)

        files = {
            f"original.{original_ext}": original,
            "processed.jpg": processed_jpg,
        }
        if mask_png is not None:
            files["mask.png"] = mask_png
        for name, data in files.items():
            (folder / name).write_bytes(data)

        # Written last: a folder without metadata.json is an incomplete item.
        (folder / "metadata.json").write_text(json.dumps(metadata, indent=2))
        return {name: str(folder / name) for name in [*files, "metadata.json"]}

    def load(self, uid: str, item_id: str) -> StoredWardrobeItem:
        for value in (uid, item_id):
            if not _SAFE_ID.fullmatch(value):
                raise ValueError(f"unsafe path component: {value!r}")
        folder = self._root / "wardrobe" / uid / item_id
        meta_path = folder / "metadata.json"
        if not meta_path.exists():
            raise WardrobeItemNotFoundError(f"No wardrobe item {item_id!r} for this user.")
        mask_path = folder / "mask.png"
        return StoredWardrobeItem(
            metadata=json.loads(meta_path.read_text()),
            processed_jpg=(folder / "processed.jpg").read_bytes(),
            mask_png=mask_path.read_bytes() if mask_path.exists() else None,
        )

    def list(self, uid: str) -> list[StoredWardrobeItem]:
        if not _SAFE_ID.fullmatch(uid):
            raise ValueError(f"unsafe path component: {uid!r}")
        folder = self._root / "wardrobe" / uid
        if not folder.exists():
            return []
        items = [self.load(uid, p.name) for p in folder.iterdir() if (p / "metadata.json").exists()]
        items.sort(key=lambda i: i.metadata.get("createdAt", ""), reverse=True)
        return items


class ResultStore(Protocol):
    def save(self, uid: str, result_id: str, *, result_jpg: bytes, metadata: dict) -> dict[str, str]:
        """Persist a generated try-on result; returns artifact name -> location."""
        ...


class LocalResultStore:
    """Writes to disk. Swap for a Firebase Storage + Firestore store later."""

    def __init__(self, root: Path):
        self._root = Path(root)

    def save(self, uid: str, result_id: str, *, result_jpg: bytes, metadata: dict) -> dict[str, str]:
        for value in (uid, result_id):
            if not _SAFE_ID.fullmatch(value):
                raise ValueError(f"unsafe path component: {value!r}")
        folder = self._root / "results" / uid / result_id
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "result.jpg").write_bytes(result_jpg)
        # Written last: a folder without metadata.json is an incomplete result.
        (folder / "metadata.json").write_text(json.dumps(metadata, indent=2))
        return {"result.jpg": str(folder / "result.jpg"), "metadata.json": str(folder / "metadata.json")}

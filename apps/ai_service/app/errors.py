class PipelineError(Exception):
    """A failure the client should see, with a stable machine-readable code."""

    status_code = 500
    code = "PIPELINE_ERROR"

    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


class ImageValidationError(PipelineError):
    status_code = 400
    code = "INVALID_IMAGE"


class NoBodyError(PipelineError):
    status_code = 422
    code = "NO_BODY_DETECTED"


class InvalidPostureError(PipelineError):
    status_code = 422
    code = "INVALID_POSTURE"

    def __init__(self, message: str, reason: str):
        super().__init__(message)
        self.reason = reason


class BackgroundRemovalError(PipelineError):
    status_code = 500
    code = "BACKGROUND_REMOVAL_FAILED"


class InvalidCategoryError(PipelineError):
    status_code = 400
    code = "INVALID_CATEGORY"


class InvalidStyleError(PipelineError):
    status_code = 400
    code = "INVALID_STYLE"


class NoGarmentError(PipelineError):
    status_code = 422
    code = "NO_GARMENT_DETECTED"


class TwinNotFoundError(PipelineError):
    status_code = 404
    code = "TWIN_NOT_FOUND"


class WardrobeItemNotFoundError(PipelineError):
    status_code = 404
    code = "WARDROBE_ITEM_NOT_FOUND"


class InvalidWardrobeItemError(PipelineError):
    status_code = 400
    code = "INVALID_WARDROBE_ITEM"


class TryOnNotImplementedError(PipelineError):
    status_code = 501
    code = "TRY_ON_NOT_IMPLEMENTED"

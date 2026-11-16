# Automated test inventory

Generated from executed JUnit/JSONL results. Full parameterized node names appear below; loading/setup/teardown records are excluded. Existing placeholder test is nonfunctional. Font rerun replaces the same added Flutter check results for counting purposes.

| Framework | Run | Test | Outcome | Evidence |
| --- | --- | --- | --- | --- |
| pytest | baseline | `tests/test_auth.py::test_verify_returns_firebase_uid` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_auth.py::test_verify_rejects_invalid_firebase_claims[claims0]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_auth.py::test_verify_rejects_invalid_firebase_claims[claims1]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_auth.py::test_verify_rejects_invalid_firebase_claims[claims2]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_auth.py::test_verify_rejects_invalid_firebase_claims[claims3]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_enhance_quality.py::test_denoising_reduces_noise_variance` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_enhance_quality.py::test_sharpening_increases_edge_contrast` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_enhance_quality.py::test_low_contrast_channel_is_stretched` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_enhance_quality.py::test_does_not_shift_a_dominant_garment_colour` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_enhance_quality.py::test_flat_image_is_not_corrupted` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_fashn_api.py::test_shoes_require_server_side_api_key` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_fashn_api.py::test_shoe_generation_submits_polls_and_decodes` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_fashn_api.py::test_inspo_uses_one_quality_1k_call_and_identity_prompt` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_fashn_api.py::test_inspo_invalid_provider_response_is_handled` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_fashn_api.py::test_accessories_request_quality_1k_and_preserve_clothing` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_fashn_api.py::test_all_clothing_uses_quality_1k_once_with_hijab_preservation[Tops]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_fashn_api.py::test_all_clothing_uses_quality_1k_once_with_hijab_preservation[Pants]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_fashn_api.py::test_all_clothing_uses_quality_1k_once_with_hijab_preservation[Skirts]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_fashn_api.py::test_failed_prediction_is_not_resubmitted` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_garment_extraction.py::test_worker_errors[422-NoGarmentError]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_garment_extraction.py::test_worker_errors[503-GarmentExtractionError]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_garment_extraction.py::test_worker_connection_failure` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_garment_extraction.py::test_worker_mask_response[204-None]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_garment_extraction.py::test_worker_mask_response[200-shape1]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_garment_extraction.py::test_worker_mask_response[200-shape2]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_mode_controls_provider_payload_credit_total_and_saved_metadata[fast-1-tryon-2]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_mode_controls_provider_payload_credit_total_and_saved_metadata[fast-1-inspo-1]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_mode_controls_provider_payload_credit_total_and_saved_metadata[balanced-2-tryon-2]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_mode_controls_provider_payload_credit_total_and_saved_metadata[balanced-2-inspo-1]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_mode_controls_provider_payload_credit_total_and_saved_metadata[quality-3-tryon-2]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_mode_controls_provider_payload_credit_total_and_saved_metadata[quality-3-inspo-1]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_wrong_mode_quote_never_submits_a_paid_call[fast-3-tryon-2]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_wrong_mode_quote_never_submits_a_paid_call[fast-3-inspo-1]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_wrong_mode_quote_never_submits_a_paid_call[balanced-1-tryon-2]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_wrong_mode_quote_never_submits_a_paid_call[balanced-1-inspo-1]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_wrong_mode_quote_never_submits_a_paid_call[quality-2-tryon-2]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_wrong_mode_quote_never_submits_a_paid_call[quality-2-inspo-1]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_invalid_modes_never_submit_a_paid_call[turbo-tryon]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_invalid_modes_never_submit_a_paid_call[turbo-inspo]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_invalid_modes_never_submit_a_paid_call[FAST-tryon]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_invalid_modes_never_submit_a_paid_call[FAST-inspo]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_invalid_modes_never_submit_a_paid_call[fast -tryon]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_invalid_modes_never_submit_a_paid_call[fast -inspo]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_missing_fast_quote_never_submits_a_paid_call[tryon]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_missing_fast_quote_never_submits_a_paid_call[inspo]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_generation_modes.py::test_requests_with_different_modes_do_not_change_each_others_engine` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_hijab_mediapipe.py::test_head_covered_by_clothing_is_hijab_with_mask` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_hijab_mediapipe.py::test_visible_hair_is_not_hijab` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_hijab_mediapipe.py::test_visible_neck_skin_is_not_hijab` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_hijab_mediapipe.py::test_no_face_means_no_decision` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_hijab_mediapipe.py::test_head_crop_box_is_centred_on_nose_and_clipped_to_canvas` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_imaging.py::test_transparent_product_image_is_flattened_on_white` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_inspo_api.py::test_inspo_returns_and_persists_result` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_inspo_api.py::test_inspo_rejects_other_users_twin_without_calling_provider` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_inspo_api.py::test_inspo_requires_firebase_auth` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_inspo_api.py::test_inspo_validates_before_paid_generation` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_inspo_api.py::test_inspo_missing_key_returns_actionable_error` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_inspo_api.py::test_provider_failure_does_not_save_a_result` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_list_endpoints.py::test_list_twins_empty` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_list_endpoints.py::test_list_twins_newest_first` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_list_endpoints.py::test_list_twins_only_returns_this_users_twins` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_list_endpoints.py::test_list_wardrobe_newest_first` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_list_endpoints.py::test_list_wardrobe_empty` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_list_endpoints.py::test_twins_list_requires_auth` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_list_endpoints.py::test_wardrobe_list_requires_auth` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_max_quality.py::test_two_item_quote_must_be_six_before_any_paid_call[None]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_max_quality.py::test_two_item_quote_must_be_six_before_any_paid_call[0]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_max_quality.py::test_two_item_quote_must_be_six_before_any_paid_call[3]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_max_quality.py::test_two_item_quote_must_be_six_before_any_paid_call[10]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_max_quality.py::test_two_item_quote_must_be_six_before_any_paid_call[True]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_max_quality.py::test_two_paid_passes_keep_provider_size_between_steps_and_in_saved_result` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_max_quality.py::test_inspo_requires_three_credit_quote_without_provider_calls[None]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_max_quality.py::test_inspo_requires_three_credit_quote_without_provider_calls[2]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_max_quality.py::test_inspo_requires_three_credit_quote_without_provider_calls[5]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_max_quality.py::test_inspo_single_three_credit_pass_preserves_provider_size` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_happy_path_saves_all_artifacts` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_hijab_mask_is_saved_when_analyzer_provides_one` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_no_body_is_422_and_skips_background_removal` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_bad_posture_is_rejected_before_background_removal` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_garbage_bytes_are_400` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_oversized_upload_is_rejected` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_pixel_bomb_is_rejected` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_50mp_phone_photo_is_accepted` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_too_small_photo_is_rejected` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_auth_required_when_not_disabled` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_resize_and_pad_keeps_aspect_and_centres` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pipeline_api.py::test_composite_on_white` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pose.py::test_valid_standing_pose` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pose.py::test_side_profile` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pose.py::test_small_front_facing_person_is_not_a_side_profile` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pose.py::test_sitting` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pose.py::test_hidden_arms` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pose.py::test_loose_sleeves_with_borderline_wrist_visibility_are_accepted` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pose.py::test_head_direction_is_not_checked` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_pose.py::test_hidden_knees_skip_sitting_test_instead_of_rejecting` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_unknown_twin_is_404` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_unknown_garment_is_404` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_hijab_item_rejected_as_garment` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_non_hijab_item_rejected_as_hijab_choice` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_top_and_pants_are_applied_in_stable_order` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_top_and_skirt_are_applied_in_stable_order` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_pants_and_skirt_cannot_be_selected_together` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_top_pants_and_shoes_are_applied_in_stable_order` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_two_items_from_the_same_category_are_rejected` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_at_least_one_garment_is_required` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_garment_only_protects_twins_own_hijab` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_chosen_hijab_runs_both_stages_and_protects_its_own_placement` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_result_is_persisted` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_worker_unavailable_by_default` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_shoes_explain_missing_hosted_api_key` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_auth_required_when_not_disabled` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_accessory_only_keeps_full_frame_and_records_item` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_accessory_runs_after_complete_outfit` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_multiple_accessories_keep_selection_order_and_accumulate` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_five_accessories_combine_with_top_pants_and_shoes` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_six_accessories_are_rejected_before_generation` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_duplicate_accessory_is_rejected_before_generation` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_api.py::test_accessories_use_hosted_engine_and_require_key` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_crop.py::test_crop_removes_empty_side_margins_and_keeps_portrait_aspect` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_crop.py::test_invalid_landmarks_leave_the_image_unchanged` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_crop.py::test_result_is_normalized_to_storage_size` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_engine_selection.py::test_fashn_is_the_only_default_engine` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_engine_selection.py::test_fashn_api_key_enables_hosted_shoe_engine` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_engine_selection.py::test_skirt_uses_local_bottoms_engine` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_mask.py::test_top_mask_covers_torso_but_not_face_or_hands` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_mask.py::test_pants_mask_covers_legs_but_not_torso` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_mask.py::test_shoes_mask_covers_feet_but_not_legs` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_tryon_mask.py::test_protected_pixels_are_removed_from_replacement_mask` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_garment_item_saved_without_mask` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_hijab_item_saves_style_and_mask` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_unknown_category_is_rejected` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_hijab_without_style_is_rejected` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_hijab_with_unknown_style_is_rejected` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_style_is_ignored_for_non_hijab_category` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_blank_photo_is_rejected_as_no_garment` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_too_small_photo_is_rejected` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_square_bundled_asset_resolution_is_accepted` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_auth_required_when_not_disabled` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_person_photo_saves_only_selected_garment[Tops-2]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_person_photo_saves_only_selected_garment[Pants-0]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_person_photo_saves_only_selected_garment[Skirts-0]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_extraction_failure_does_not_save_whole_person[error0-422]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| pytest | baseline | `tests/test_wardrobe_api.py::test_extraction_failure_does_not_save_whole_person[error1-503]` | PASS | [structured result](../logs/fastapi/baseline.xml) |
| Flutter | baseline | `ai_service_test.dart::FastAPI validation list is displayed instead of a false connection error` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `ai_service_test.dart::structured server errors and non-string reason fields remain readable` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `ai_service_test.dart::unreachable twin list times out without retrying` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `ai_service_test.dart::stuck authentication times out before sending any API request` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `ai_service_test.dart::refresh recovers after an offline list request` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `ai_service_test.dart::wardrobe list has the same bounded loading behaviour` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `ai_service_test.dart::a generation timeout is not misreported as a connection failure` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::maximum-quality quote counts every item including accessories` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `notification_service_test.dart::Malaysian 10:11 PM is scheduled at 10:11 PM, with exact timing` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `notification_service_test.dart::unknown timezone fallback preserves the instant instead of shifting eight hours` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `notification_service_test.dart::denied exact access uses approximate timing and reports it` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `notification_service_test.dart::disabled notifications and past times do not create alarms` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `form_state_test.dart::login keeps typed fields after parent rebuild` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::VTON shows the total and cancellation declines generation` | FAIL | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_draft_test.dart::double tapping save uploads once and successful saves stay saved` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_draft_test.dart::a failed upload unlocks save for a retry` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_draft_test.dart::result cannot be saved after account changes to null` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_draft_test.dart::result cannot be saved after account changes to another-user` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::Inspo confirms exactly one three-credit generation` | FAIL | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::VTON sends its confirmed total once` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `form_state_test.dart::sign-up keeps typed fields after parent rebuild` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::cost confirmation remains usable in landscape` | FAIL | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `inspo_mirror_screen_test.dart::empty twin list explains setup and cannot submit a paid request` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::Inspo sends the three-credit confirmation in its multipart request` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::Fast sends matching mode and cost to both endpoints` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_plan_test.dart::a past reminder today is no longer upcoming` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_plan_test.dart::a plan expires at its selected time, not at midnight` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_plan_test.dart::a future reminder is upcoming` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::Fast confirmation shows its own total` | FAIL | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_plan_test.dart::legacy date-only plan expires at the next local midnight` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::Balanced sends matching mode and cost to both endpoints` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_plan_test.dart::a date-only plan from yesterday is not upcoming` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `form_state_test.dart::twin setup keeps height, weight and preferences after rebuild` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_plan_test.dart::missing or invalid dates do not produce upcoming outfits` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_plan_test.dart::existing planner records appear in gallery without createdAt or imageUrl` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_plan_test.dart::gallery preserves custom titles and creation dates` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::Balanced confirmation shows its own total` | FAIL | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::Quality sends matching mode and cost to both endpoints` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `inspo_mirror_screen_test.dart::API error can be recovered by refreshing twins` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::Quality confirmation shows its own total` | FAIL | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `generation_confirmation_test.dart::mode selector switches choices and wraps on small screens` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::invalid body metric "" is rejected` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::invalid body metric "abc" is rejected` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::invalid body metric "-1" is rejected` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::invalid body metric "0" is rejected` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::invalid body metric "NaN" is rejected` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::invalid body metric "Infinity" is rejected` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::invalid body metric "-Infinity" is rejected` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::invalid body metric "1e999" is rejected` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::valid body metric "170" is accepted` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::valid body metric "65.5" is accepted` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `profile_validation_test.dart::valid body metric " 165.5 " is accepted` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_preview_test.dart::planner thumbnail fits all six clothing pieces` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `wardrobe_recovery_test.dart::owned closet image paths accepts current and legacy paths only for this user` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `wardrobe_recovery_test.dart::recovers missing gallery and bundled items without duplicating linked items` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `wardrobe_recovery_test.dart::continues after missing images or failed uploads and leaves changed records alone` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_preview_test.dart::planner detail shows categories and can scroll` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_preview_test.dart::empty planner outfit has a friendly preview` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `outfit_preview_test.dart::gallery upload uses its actual network URL` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `password_reset_test.dart::reset from profile does not pop the profile page` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `widget_test.dart::Placeholder test` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| Flutter | baseline | `password_reset_test.dart::login reset closes its dialog, not the underlying page` | PASS | [structured result](../logs/flutter/baseline.jsonl) |
| pytest | added | `tests/test_fyp_functional_gaps.py::test_TC007_missing_twin_photo_is_schema_error_and_saves_nothing` | PASS | [structured result](../logs/fastapi/added.xml) |
| pytest | added | `tests/test_fyp_functional_gaps.py::test_TC013_missing_category_is_schema_error_and_saves_nothing` | PASS | [structured result](../logs/fastapi/added.xml) |
| pytest | added | `tests/test_fyp_functional_gaps.py::test_TC026_absent_twin_rejects_before_provider_or_result_save` | PASS | [structured result](../logs/fastapi/added.xml) |
| pytest | added | `tests/test_fyp_functional_gaps.py::test_TC023_svg_reference_is_rejected_before_provider_or_result_save` | PASS | [structured result](../logs/fastapi/added.xml) |
| pytest | added | `tests/test_fyp_functional_gaps.py::test_TC027_low_resolution_reference_is_rejected_before_provider` | PASS | [structured result](../logs/fastapi/added.xml) |
| pytest | added | `tests/test_fyp_functional_gaps.py::test_TC027_characterization_blank_decodable_reference_reaches_fake_provider` | PASS | [structured result](../logs/fastapi/added.xml) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-002 empty sign-up fields show all required errors without registration` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-006 empty login fields prevent credential submission` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-001 valid sign-up form forwards all details to an isolated controller` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-004 valid login form forwards credentials to an isolated controller` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-003 Firebase rejection is shown and loading stops (fake Auth)` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-005 Firebase rejection is shown and loading stops (fake Auth)` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-008 setup cannot continue without a body photo` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-008 controller rejects incomplete metrics before Firebase or file access` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-024 cancelling inspiration picker leaves selection empty and sends no generation` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-036 missing saved outfit image has a thumbnail fallback` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |
| Flutter | added-readable | `fyp_functional_gaps_test.dart::TC-036 missing saved outfit image has a detail message` | PASS | [structured result](../logs/flutter/added-readable.jsonl) |

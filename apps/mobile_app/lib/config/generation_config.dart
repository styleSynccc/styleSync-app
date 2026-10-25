// Keep in sync with apps/ai_service/app/config.py. The server independently
// checks this quote and rejects mismatches before making a paid request.
const maxQualityCreditsPerImage = 3;
const maxQualityLabel = 'Quality · 1K';

int maxQualityCreditCost(int itemCount) =>
    itemCount * maxQualityCreditsPerImage;

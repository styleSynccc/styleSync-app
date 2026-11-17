# StyleSync — 90-second launch film

1920 × 1080, 30 fps, exactly 90 seconds. Tone: polished, playful fashion editorial.

Angle: Your wardrobe has possibilities. StyleSync brings them into view.
Audience: people organising their clothes, exploring looks, and planning outfits.
Hook: A closet full of clothes. Still deciding what to wear?
Highlights: My Closet; Virtual Try-On and AI Inspo Mirror; saved outfits and Outfit Planner.
Punchline: Your clothes. Your possibilities. StyleSync.
Caption: Meet StyleSync: your digital wardrobe and virtual try-on companion. Organise your closet, explore looks with AI Inspo Mirror, and plan what to wear next.

## Visual identity and source use

Reuse the actual StyleSync lettering and coloured logo, supplied garment cutouts, and the existing My Closet screenshot (which says only “User”). Source UI is white with #1A1A1A text, black buttons, rounded 12px controls, Material-style sans-serif. Brand accents are electric blue, violet, pink and red from the existing logo. Video typography uses installed Segoe UI with restrained editorial sizes.

The native Flutter screens depend on Firebase authentication, Firestore and device photo access, so they cannot run as isolated browser components. Browser compositions mirror their source labels, spacing, controls and garment rows, and use their original images directly. Animated demo selections and a fictional outfit plan are labelled “Illustrative demo”. No real account data, personal photos, API generation, testimonials, performance claims, download URLs, or availability claims are included. The try-on and inspiration portions show the supported selection flow, not fabricated AI output. No personal-photo screenshots are used.

## Sound

Original instrumental, 120 BPM in A minor, 4/4. Soft kick, rounded bass, warm pad and short plucked notes. Subtle selection sounds share the key and beat grid. Cuts occur on the half-second beat grid. Gentle intro and 4-second outro fade; no voiceover.

## Storyboard

| Time | Duration | Scene and motion |
|---|---:|---|
| 0–4 | 4s | Hook: garment cutouts float in; “A closet full of clothes.” then “Still deciding what to wear?” Frame 0 is replaced by the settled poster. |
| 4–10 | 6s | Reveal: original lettering and logo; “Your digital wardrobe. More possibilities.” Actual My Closet screen enters a phone frame. |
| 10–20 | 10s | My Closet: original clothing assets assemble into the real category grid. Categories and plus action are highlighted. |
| 20–28 | 8s | Choose your pieces: simulated category taps switch Tops, Pants, Shoes and Accessories, keeping source labels. |
| 28–38 | 10s | Virtual Try-On: selected top, bottoms and shoes appear one at a time, then the action is highlighted. Demo only; no generation is submitted. |
| 38–48 | 10s | Digital twin: explain “Choose your digital twin. Choose your look.” Placeholder photo slot, garment selection, and original source action wording. |
| 48–58 | 10s | AI Inspo Mirror: source copy “An outfit you love. On your twin.” Upload photo slot, twin slot, “Generate on my twin”. No fabricated result. |
| 58–66 | 8s | My Outfits: original garment assets in two fictional saved outfit cards. Save feedback and selection animate on beat. |
| 66–78 | 12s | Outfit Planner: fictional calendar date and outfit card; a date highlights, pieces assemble, then save confirmation. |
| 78–84 | 6s | Recap: Closet, Try-On, Planner shown as three animated product panels. |
| 84–90 | 6s | Outro: logo and lettering; “Your clothes. Your possibilities.” followed by “Meet StyleSync”. |

Total: 90 seconds / 2,700 frames. Each scene dips through its background at boundaries to avoid busy double exposures. Settled text is held at least 0.3 seconds per word. Check representative frames in all scenes and precise transition endpoints before rendering. Poster is the fully settled reveal at 8 seconds; it replaces frame 0 without extending the film.

## Build

Use installed Chrome and Puppeteer. Chrome WebCodecs supplies H.264 and AAC encoding; a local script muxes MP4. No packages or tools are fetched. Original music is synthesized locally. All intermediate files and rendering code remain under work/.

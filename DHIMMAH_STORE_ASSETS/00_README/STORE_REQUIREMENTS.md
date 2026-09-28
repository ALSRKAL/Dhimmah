# Store requirements — what was checked, where, and what was decided

Every number below was read from the vendor's own page on **2026-09-26**. Nothing
here is from memory, and where a page could not be read that is stated instead of
guessed.

## Apple

| Requirement | Value as published | Source | Decision |
| --- | --- | --- | --- |
| Formats | `.jpeg`, `.jpg`, `.png` | App Store Connect — Screenshot specifications (requested path `reference/screenshot-specifications`, which now redirects to `reference/app-information/screenshot-specifications`) | PNG, sRGB |
| Transparency | "Images can't include alpha channels or transparencies." | same page | PNG with no alpha, verified per file |
| Count | "You can upload one to 10 screenshots" | same page | 8 per device size and language |
| iPhone 6.9″ | 1260 × 2736, 1290 × 2796, **1320 × 2868** pixels | same page | 1320 × 2868 — the master the captures are composed into |
| iPhone 6.5″ | 1284 × 2778, 1242 × 2688 pixels | same page | not produced; only required when 6.9″ is absent |
| iPad 13″ | **2064 × 2752**, 2048 × 2732 pixels — "Required if app runs on iPad" | same page | 2064 × 2752 — **not produced, no iOS runtime on this machine** |
| Icon | iOS/iPadOS/macOS 1024 × 1024 px, layered, unmasked layers | Human Interface Guidelines — App icons (content read from the page's own JSON endpoint `tutorials/data/design/human-interface-guidelines/app-icons.json`; the HTML is a JavaScript app) | shipped brand artwork at 1024 × 1024, no alpha, not redesigned |
| Icon file-size limit | not stated on the HIG page | same | reported as "not published" rather than invented |
| Preview video | up to 3 per device size and language, `.mov`/`.m4v`/`.mp4` H.264 | App Store Connect — Upload app previews and screenshots | not produced (no video) |
| Real-UI wording | no explicit clause found on either page | both pages above | the screenshots are photographs of the running app regardless |
| New device type | "iPhone Duo" sizes listed, with a page note that uploading assets for it "will be available later this year" | screenshot specifications | noted, nothing to produce yet |

## Google Play

| Requirement | Value as published | Source | Decision |
| --- | --- | --- | --- |
| Screenshot format | "JPEG or 24-bit PNG (no alpha)" | Play Console Help — Add preview assets to showcase your app (`support.google.com/googleplay/android-developer/answer/9866151`) | 24-bit PNG, no alpha |
| Screenshot count | "You can add up to 8 screenshots for each supported device type"; "a minimum of two screenshots across different device types" to publish | same page | 8 phone screenshots per language; tablet set not produced |
| Screenshot dimensions | "Minimum dimension: 320px", "Maximum dimension: 3840px", and the maximum "can't be more than twice as long as the minimum dimension" | same page | 1080 × 1920: 1.78:1, inside both bounds |
| Recommendation eligibility | "at least four screenshots with minimum 1080px resolution… 9:16 for portrait (minimum 1080x1920px)" | same page | all eight are 1080 × 1920, so the set qualifies |
| Large screens (tablet, Chromebook) | "minimum of 4 screenshots", "between 1,080 and 7,680px", "a 9:16 aspect ratio for portrait" | same page | not produced this round (Android tablet runtime exists, tablet captures not attempted) — recorded as missing, not as done |
| Feature graphic | "JPEG or 24-bit PNG (no alpha)", "1024px by 500px" | same page | 1024 × 500 PNG, no alpha, both languages |
| App icon | "32-bit PNG (with alpha)", "512px by 512px", "Maximum file size: 1024KB" | same page | 512 × 512 RGBA, checked against the size limit |
| Real-UI rule | "Screenshots must demonstrate the actual in-app or in-game experience"; "Use captured footage of the app or game itself." | same page | this is why every frame is captured inside the running app and the compositor only scales it |
| Tagline area | "Taglines should not take up more than 20% of the image." | same page | the marketing band is measured and checked against 20% of the canvas height |
| Feature-graphic best practices | **NOT FETCHED as a specification page** — `developer.android.com/distribute/best-practices/launch/feature-graphic` redirects to a marketing page with no specs (and to an OAuth sign-in on direct request) | — | the feature graphic is built to the Play Console Help values above, and nothing was taken from the dead page |
| Other form factors | Wear OS 1:1 min 384 × 384; Android TV banner 1280 × 720; Automotive 800 × 1280 + 1024 × 768; XR 4–8 at 8:5 | same page | out of scope for this app (phone and tablet only) |

## What follows from this

* The phone canvases are **1080 × 1920** and the feature graphic **1024 × 500**
  because those are the published values, not because they look right.
* Nothing in the package carries an alpha channel except the Play icon, which the
  page asks to have one.
* The Apple screenshots are **not produced**. The published size for the 6.9″
  iPhone is 1320 × 2868 and for the 13″ iPad 2064 × 2752, but producing them
  requires a macOS machine with Xcode and a simulator or a device; this machine
  has neither. See `../02_APP_STORE/NOT_PRODUCED.md` for the exact commands that
  close that gap.

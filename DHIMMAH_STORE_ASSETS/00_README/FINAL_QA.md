# Visual QA — what was actually looked at

Not a validator run: this is the pass where every image was opened and read with
an eye. It was done on 2026-09-26 against the files in this package.

## Images opened

| Image | What was checked | Result |
| --- | --- | --- |
| `04_SOURCE_SCREENSHOTS/ANDROID/AR/01_dashboard_ar.png` | currency, totals, RTL, no banner | riyals throughout (﷼), **all three figures reconcile**: I owe 1,417,500 = 250,000 + 875,000 + 212,500 + 80,000; owed to me 600,000 = 300,000 + 187,500 + 112,500; net 817,500 = 1,417,500 − 600,000; overdue 875,000 and due soon 550,000 = 250,000 + 300,000. Nothing cut off, no system banner, no debug banner |
| `04_SOURCE_SCREENSHOTS/ANDROID/AR/04_debt_detail_ar.png` | the flagship record | total 375,000 ﷼, paid 125,000 ﷼, remaining 250,000 ﷼, progress bar a third filled; dates, reminder "قبل 3 أيام · قبل يوم", one payment dated 14 سبتمبر 2026 |
| `04_SOURCE_SCREENSHOTS/ANDROID/AR/03_people_ar.png` | five people, the two-person record | أحمد محمد، خالد العلي، علي حسن، محمد صالح، مكتب المحاسبة — and the shared record (80,000 ﷼) appears on **both** علي حسن's and محمد صالح's pages, with محمد صالح showing "دين واحد" |
| `04_SOURCE_SCREENSHOTS/ANDROID/EN/01_dashboard_en.png` | currency, totals, LTR | dollars throughout ($), totals reconcile the same way ($5,670 − $2,400 = $3,270) |
| `01_GOOGLE_PLAY/PHONE_AR/01_dashboard_ar_google_1080x1920.png` | composition, margins, Arabic headline | headline shaped and joined correctly, right-aligned, no clipping, brand row (mark at the right edge, wordmark after it) matches the app's own header |
| `01_GOOGLE_PLAY/PHONE_EN/04_debt_detail_en_google_1080x1920.png` | the flagship slide | **$ 1,500 total, $ 500 paid, $ 1,000 remaining** — the figure the listing is built on |
| `01_GOOGLE_PLAY/PHONE_EN/ALTERNATES/01_dashboard_dark_en_google_1080x1920.png` | the dark page | genuinely dark (#131211 page, light ink), app in its dark theme, same amounts |
| `01_GOOGLE_PLAY/FEATURE_GRAPHIC_AR/feature_graphic_ar_1024x500.png` | banner composition | mark leading at the right, wordmark and tagline to its left, centred, nothing near the edges, no screenshot and no invented UI in it |
| `03_ICONS/GOOGLE_PLAY/icon_512x512.png` | the icon | the shipped wallet-and-receipt mark, square, sharp |
| `06_VALIDATION/contact_sheets/GOOGLE_PHONE_AR_CONTACT_SHEET.png` | the Arabic set as a story | eight slides in the order 01 dashboard → 08 statement, all riyals, all the same card size and position |
| `06_VALIDATION/contact_sheets/GOOGLE_PHONE_EN_CONTACT_SHEET.png` | the English set as a story | eight slides, all dollars, same geometry as each other |

## Defects found, and what was done

| Defect | Fix |
| --- | --- |
| The English dashboard slide's marketing band measured **20.5%** of the canvas, and the obligations slide **22.8%** — over Google's published "taglines should not take up more than 20% of the image" | The compositor now measures the whole set and steps the type down a fixed ladder until the tallest band fits, then draws every slide at that one scale. Worst case now 18.6% (EN dashboard), 13.5% (AR set). The check is enforced by the validator, not by eye. |
| Cards sat at a different height on slides with a two-line headline | The card top is measured from the tallest band in the set, so all eight slides of a language line up exactly (AR: 687 × 1526 at y=334; EN: 643 × 1429 at y=431) |
| The composed brand row put the wordmark before the mark; the app's own header puts the mark first (right edge in Arabic) | `brand_row` rebuilt to lead with the mark, matching the app |
| Frames from the previous revision (a different currency) were still on the device and would have been fetched alongside the new ones | Every capture run now empties the device folder first, and the stale frames were deleted rather than shipped |
| A tool hook dropped a hidden state folder inside `04_SOURCE_SCREENSHOTS/` | Removed; the scan and the stray-file check now skip hidden directories |

## What was deliberately left as it is

* **The add-debt form is photographed empty**, in the state a person sees when
  they open it. Filling it in would have meant typing into the app during the
  capture — a staged screen rather than the real opening state.
* **The activity feed on the debt detail says "today"** for a payment dated
  14 September: the record's own date is the payment date, the timeline's date is
  when the entry was written. Both are the app's real behaviour; a person who
  enters an old payment today sees exactly this.
* **One currency per listing.** The app can show several currencies side by side,
  but the demo ledger is single-currency so each listing reads consistently.
* **The icon keeps its rounded corners.** It is the app's shipped artwork, and
  the brief was not to redesign it; Play applies its own mask on top.

## What this pass does *not* prove

Nothing about iOS or iPad: no such screenshot exists to look at. The Apple
sections of the package are empty by design and say so.

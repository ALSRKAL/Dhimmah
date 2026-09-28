# ذِمّة — برومبت واحد لكل صور المتجر (Nano Banana / أي مولّد صور)

انسخ هذا البرومبت كاملًا وأرسله مع **صورة الشاشة المرفقة** في كل مرة.
لكل صورة: افتح الملف المرافق لها من `05_NANO_BANANA_PROMPTS/GOOGLE_PLAY/`،
أرفق صورة المصدر، والصق هذا البرومبت.

> **ملاحظة مهمة قبل البدء:** الصور النهائية **موجودة بالفعل** في هذا المجلد
> (`01_GOOGLE_PLAY/PHONE_AR`, `PHONE_EN`, `FEATURE_GRAPHIC_AR/EN`)، وهي مُنتَجة
> آليًا من لقطات حقيقية للتطبيق بخط التطبيق نفسه، والنص العربي فيها مرسوم
> **حرفيًا** بلا أي توليد. استخدم هذا البرومبت فقط إن أردت **إعادة إنتاج** الصور
> بمولّد صور. إن لم يستطع المولّد كتابة العربية كما هي، اترك شريط النص فارغًا
> وسيُركَّب النص الصحيح فوقه من `compose_assets.py`.

---

## البرومبت

**The supplied Dhimmah screenshot is the source of truth.**
**Preserve the exact application UI.**
**Do not redraw, reinterpret, replace, invent, or modify the app interface.**

You are composing a store listing image for **ذِمّة (Dhimmah)**, an Arabic-first
personal debt ledger. You are given one screenshot of the real running app.
Reproduce that screenshot inside a calm, typography-led page. The screenshot is
the subject; you are only the page around it.

### Canvas

- Google Play phone screenshot: **1080 × 1920** (9:16), PNG, no alpha.
- Google Play feature graphic: **1024 × 500**, PNG, no alpha.
- Portrait only. Never produce a landscape composition.

### What must be preserved pixel-for-pixel inside the card

- every amount, currency symbol, digit and separator
- every name and every word of the interface
- every date and relative phrase
- every button, label, icon and navigation tab
- typography, weights, line breaks, text alignment
- the state the screen is in (what is selected, open, scrolled)
- the layout: nothing moved, nothing resized, nothing re-coloured

Do not crop the screenshot. Scale it whole, keeping its aspect ratio.

### Page style (exact)

- Background: warm paper **#F7F5F2** (dark page: **#131211**, only for the dark alternate).
- Ink: **#1C1917**. Secondary text: **#6B655C**. Hairline border: **#E5E1DA**.
- Font: **IBM Plex Sans Arabic** (SemiBold for the headline, Regular for the
  supporting line). Do not substitute another Arabic font.
- The screenshot sits in a rounded card (radius 40 px) with a 2 px hairline
  border and one soft, wide shadow. No device frame, no notch, no bezel, no
  reflection, no perspective, no 3D tilt.
- Brand row at the top, on the reading side: the mark, then «ذِمّة» in Arabic and
  "Dhimmah" in English.
- Margins: 84 px on every edge; nothing important inside the outer 60 px.
- Marketing text occupies less than 20% of the canvas height (Play's tagline rule).

### Text (Arabic listing / English listing)

Draw the headline and the supporting line **exactly as given below**, in IBM Plex
Sans Arabic, right-aligned for Arabic and left-aligned for English. Do not
translate, shorten, rephrase, re-punctuate or re-typeset them. Arabic must be
correctly shaped and joined, RTL, with no letter-spacing tricks and no mirrored
glyphs. Mixed numbers and currency symbols keep their own direction.

| # | Attach this screenshot | Headline (AR) | Supporting line (AR) |
| --- | --- | --- | --- |
| 01 | `04_SOURCE_SCREENSHOTS/ANDROID/AR/01_dashboard_ar.png` | اعرف ما لك وما عليك | كل دين ودفعة في مكان واحد، بالأرقام الصحيحة |
| 02 | `04_SOURCE_SCREENSHOTS/ANDROID/AR/02_add_debt_ar.png` | سجّل الدين في ثوانٍ | المبلغ والتاريخ والطرف الآخر — نموذج واحد واضح |
| 03 | `04_SOURCE_SCREENSHOTS/ANDROID/AR/03_people_ar.png` | كل شخص وسجله بوضوح | من له ومن عليه، مجموعًا لكل شخص |
| 04 | `04_SOURCE_SCREENSHOTS/ANDROID/AR/04_debt_detail_ar.png` | تابع المدفوع والمتبقي | كل دفعة بتاريخها، والمتبقي يتحدث فورًا |
| 05 | `04_SOURCE_SCREENSHOTS/ANDROID/AR/05_obligations_ar.png` | التزاماتك الشهرية تحت السيطرة | إيجار وفواتير وأقساط، مع تذكير قبل الاستحقاق |
| 06 | `04_SOURCE_SCREENSHOTS/ANDROID/AR/06_ledger_ar.png` | كل سجلك في مكان واحد | ابحث وفلتر بين كل الديون والدفعات |
| 07 | `04_SOURCE_SCREENSHOTS/ANDROID/AR/08_backup_ar.png` | بياناتك معك دائمًا | نسخ احتياطي محلي وتصدير بضغطة |
| 08 | `04_SOURCE_SCREENSHOTS/ANDROID/AR/07_reports_ar.png` | كشف حساب واضح تشاركه | ملخص شهري وأرقام جاهزة للتصدير |

| # | Attach this screenshot | Headline (EN) | Supporting line (EN) |
| --- | --- | --- | --- |
| 01 | `04_SOURCE_SCREENSHOTS/ANDROID/EN/01_dashboard_en.png` | Know what you owe, and what you're owed | Every debt and payment in one place, with the numbers right |
| 02 | `04_SOURCE_SCREENSHOTS/ANDROID/EN/02_add_debt_en.png` | Record a debt in seconds | Amount, date and the other party — one clear form |
| 03 | `04_SOURCE_SCREENSHOTS/ANDROID/EN/03_people_en.png` | Every person, their own record | Who owes and who is owed, totalled per person |
| 04 | `04_SOURCE_SCREENSHOTS/ANDROID/EN/04_debt_detail_en.png` | Track what's paid and what's left | Every payment dated, the remainder updated at once |
| 05 | `04_SOURCE_SCREENSHOTS/ANDROID/EN/05_obligations_en.png` | Your recurring commitments, in order | Rent, bills and installments, with a reminder before each due date |
| 06 | `04_SOURCE_SCREENSHOTS/ANDROID/EN/06_ledger_en.png` | Your whole ledger in one place | Search and filter every debt and payment |
| 07 | `04_SOURCE_SCREENSHOTS/ANDROID/EN/08_backup_en.png` | Your data stays yours | A local backup and an export, one tap away |
| 08 | `04_SOURCE_SCREENSHOTS/ANDROID/EN/07_reports_en.png` | A clear statement you can share | A monthly summary with figures ready to export |

### Currency

- The Arabic listing is a **Yemeni riyal** ledger: amounts read like **﷼ 375,000**.
- The English listing is a **US dollar** ledger: amounts read like **$ 1,500**.
- Every amount is already drawn by the app. **Never convert, restate, round or
  re-format a single figure**, and never add an amount that is not in the
  screenshot. No other currency may appear anywhere.

### Never

gradients, purple/blue "AI" glows, neon, glassmorphism, giant cards, phone
mockups or bezels, floating UI, 3D, cartoon characters, blobs, emoji, fake
reflections, fake depth, invented charts or dashboards, ratings, review stars,
awards, badges, "download now" buttons, arrows drawn at the UI, fake hands or
people, watermarks.

### Dark alternate (one image only)

The dark dashboard uses page **#131211**, ink **#F2EFEA**, secondary **#ABA49B**,
border **#35312C**; everything else is identical.

### Output

- PNG, sRGB, no transparency, exactly the canvas size above.
- Sharp text, no resampling artefacts, no JPEG ringing around glyphs.
- If you cannot reproduce the Arabic text exactly, leave the text band empty —
  the correct finished images already exist in this folder, and a wrong Arabic
  word is worse than no word.

### Alt text (paste into the store listing, not into the image)

| # | العربية | English |
| --- | --- | --- |
| 01 | لوحة ذِمّة الرئيسية تعرض ما للمستخدم وما عليه وما يحتاج إلى متابعة. | Dhimmah dashboard showing what you owe, what is owed to you, and items needing attention. |
| 02 | نموذج إضافة دين في ذِمّة مع اختيار الطرف الآخر والمبلغ وتاريخ الاستحقاق. | Dhimmah's add-debt form with the other party, the amount and the due date. |
| 03 | شاشة الأشخاص في ذِمّة تعرض كل شخص ورصيده من الديون. | Dhimmah's people screen listing each person with their balance. |
| 04 | تفاصيل دين في ذِمّة تعرض الدفعات المسجلة والمبلغ المتبقي. | A Dhimmah debt detail showing recorded payments and the remaining amount. |
| 05 | شاشة الالتزامات في ذِمّة تعرض الأقساط والالتزامات الشهرية وحالة كل منها. | Dhimmah's obligations screen showing monthly commitments and their status. |
| 06 | سجل ذِمّة الكامل لقائمة الديون مع حالتها ومبالغها. | Dhimmah's full ledger listing debts with their status and amounts. |
| 07 | شاشة النسخ الاحتياطي في ذِمّة مع حالة آخر نسخة وخيارات التصدير. | Dhimmah's backup screen with the last snapshot's status and export options. |
| 08 | شاشة التقارير في ذِمّة تعرض ملخص الشهر للديون والمدفوعات. | Dhimmah's reports screen with the month's summary of debts and payments. |

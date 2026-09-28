# Google Play — upload order

Everything here goes into **Play Console → your app → Main store listing**.
Upload the files in the order below; the numbering is the order a visitor reads
them, not the order they were photographed in.

## 1. Arabic listing (default language)

| # | File to upload | What it shows | Alt text to paste |
| --- | --- | --- | --- |
| 1 | `01_GOOGLE_PLAY/PHONE_AR/01_dashboard_ar_google_1080x1920.png` | Dashboard — what you owe and what you're owed | لوحة ذِمّة الرئيسية تعرض ما للمستخدم وما عليه وما يحتاج إلى متابعة. |
| 2 | `01_GOOGLE_PLAY/PHONE_AR/02_add_debt_ar_google_1080x1920.png` | Add-debt form | نموذج إضافة دين في ذِمّة مع اختيار الطرف الآخر والمبلغ وتاريخ الاستحقاق. |
| 3 | `01_GOOGLE_PLAY/PHONE_AR/03_people_ar_google_1080x1920.png` | People and their balances | شاشة الأشخاص في ذِمّة تعرض كل شخص ورصيده من الديون. |
| 4 | `01_GOOGLE_PLAY/PHONE_AR/04_debt_detail_ar_google_1080x1920.png` | A debt: paid and remaining | تفاصيل دين في ذِمّة تعرض الدفعات المسجلة والمبلغ المتبقي. |
| 5 | `01_GOOGLE_PLAY/PHONE_AR/05_obligations_ar_google_1080x1920.png` | Recurring commitments | شاشة الالتزامات في ذِمّة تعرض الأقساط والالتزامات الشهرية وحالة كل منها. |
| 6 | `01_GOOGLE_PLAY/PHONE_AR/06_ledger_ar_google_1080x1920.png` | The full ledger | سجل ذِمّة الكامل لقائمة الديون مع حالتها ومبالغها. |
| 7 | `01_GOOGLE_PLAY/PHONE_AR/07_backup_ar_google_1080x1920.png` | Backup and export | شاشة النسخ الاحتياطي في ذِمّة مع حالة آخر نسخة وخيارات التصدير. |
| 8 | `01_GOOGLE_PLAY/PHONE_AR/08_reports_ar_google_1080x1920.png` | The monthly statement | شاشة التقارير في ذِمّة تعرض ملخص الشهر للديون والمدفوعات. |

Optional ninth: `01_GOOGLE_PLAY/PHONE_AR/ALTERNATES/01_dashboard_dark_ar_google_1080x1920.png`
(the dark dashboard). Play allows up to 8 per device type, so it goes in only if
you drop one of the eight above and make the whole set dark.

## 2. English listing

| # | File to upload | What it shows | Alt text to paste |
| --- | --- | --- | --- |
| 1 | `01_GOOGLE_PLAY/PHONE_EN/01_dashboard_en_google_1080x1920.png` | Dashboard | Dhimmah dashboard showing what you owe, what is owed to you, and items needing attention. |
| 2 | `01_GOOGLE_PLAY/PHONE_EN/02_add_debt_en_google_1080x1920.png` | Add-debt form | Dhimmah's add-debt form with the other party, the amount and the due date. |
| 3 | `01_GOOGLE_PLAY/PHONE_EN/03_people_en_google_1080x1920.png` | People and their balances | Dhimmah's people screen listing each person with their balance. |
| 4 | `01_GOOGLE_PLAY/PHONE_EN/04_debt_detail_en_google_1080x1920.png` | A debt: paid and remaining | A Dhimmah debt detail showing recorded payments and the remaining amount. |
| 5 | `01_GOOGLE_PLAY/PHONE_EN/05_obligations_en_google_1080x1920.png` | Recurring commitments | Dhimmah's obligations screen showing monthly commitments and their status. |
| 6 | `01_GOOGLE_PLAY/PHONE_EN/06_ledger_en_google_1080x1920.png` | The full ledger | Dhimmah's full ledger listing debts with their status and amounts. |
| 7 | `01_GOOGLE_PLAY/PHONE_EN/07_backup_en_google_1080x1920.png` | Backup and export | Dhimmah's backup screen with the last snapshot's status and export options. |
| 8 | `01_GOOGLE_PLAY/PHONE_EN/08_reports_en_google_1080x1920.png` | The monthly statement | Dhimmah's reports screen with the month's summary of debts and payments. |

## 3. Feature graphic (one per language)

| Language | File |
| --- | --- |
| Arabic | `01_GOOGLE_PLAY/FEATURE_GRAPHIC_AR/feature_graphic_ar_1024x500.png` |
| English | `01_GOOGLE_PLAY/FEATURE_GRAPHIC_EN/feature_graphic_en_1024x500.png` |

## 4. App icon

`03_ICONS/GOOGLE_PLAY/icon_512x512.png` — 32-bit PNG with alpha, 512 × 512,
under the 1024 KB limit. This is the app's existing icon, not a redesign.

## 5. Other fields the console asks for

* **Short description** (80 characters max): the copy is not in this package. If
  you need one, write it from the same product truth the screenshots show.
* **Large-screen (tablet) screenshots**: not produced. Play asks for a minimum of
  4 at 1080–7680 px, 9:16 portrait. See
  `../04_SOURCE_SCREENSHOTS/IPAD/NOT_CAPTURED.md` for how to produce them from the
  same harness on a tablet emulator.
* **App preview video**: none.

## Before you upload — the 60-second check

1. Open `06_VALIDATION/contact_sheets/GOOGLE_PHONE_AR_CONTACT_SHEET.png` and
   `..._EN_CONTACT_SHEET.png` and read the eight slides in order.
2. Confirm the amounts read in riyals (AR) and dollars (EN) — see
   `06_VALIDATION/currency_report.csv`.
3. Upload, then open the listing preview and check the first two slides at
   thumbnail size: the headline must still be readable.

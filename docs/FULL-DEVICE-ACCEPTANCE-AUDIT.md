# Full Real-Device Acceptance Audit — Backup / Dedicated Folder / Restore

One question at the end: does the backup system work reliably on the real
device, and what is still unproven?

---

## 1. Environment

| | |
| --- | --- |
| Device | **Samsung Galaxy S24 Ultra (SM-S928U1)** — real hardware |
| Android | **16 (API 36)**, 1080×2340 @ 420 dpi |
| Storage free | 232 GB of 461 GB |
| Flutter / Dart | 3.44.9 stable / 3.x |
| Gradle / Kotlin | 9.1.0 / 2.3.20 |
| Package | `com.dhimmah.dhimmah`, versionCode 1, **debug** build, debuggable |
| Install | fresh `uninstall` + `install` (journey step 1), later `install -r` after each fix |
| Analysis tooling | guarded UI driver (window-manager + hierarchy must both agree before any input), `logcat` running for the whole session |

Emulator was used only for an early smoke check and is **not** counted as device
evidence anywhere below.

---

## 2. Build / static gate — PASS (and explicitly *not* acceptance)

- `dart analyze`: **No issues found!**
- backup-related suites: **188 tests passed** (hardening, kill matrix, round
  trip, failure, coordinator, worker, compatibility, migrations, notifications,
  file gateway, Android wiring, widget, status provider)
- Android build: ✓; installed and launched on the device ✓

---

## 3. What was proven on the real device, with evidence

Evidence directory: `docs/final-acceptance/device/v10/` (screenshots, hierarchy
dumps, JSON per step), plus `artifacts/audit-logcat.txt`.

### 3.1 The dataset was created through the real UI

People **Ahmed, Khalid, MohammedSaleh, Sara** created with the real form
(`create_person.py`, guarded). Then:

| record | shape |
| --- | --- |
| Debt A | owed-to-me, Ahmed, **₹1,500**, due 7 Oct 2026, reminder, **33% paid** |
| Debt B | I-owe, Khalid, **₹300**, note `Qarad`, **paid in full (100%)** |
| Debt C | owed-to-me, **Ahmed + Khalid (multi-person)**, ₹1,000, due 30 Sep |

Plus the obligation **Rent ₹800 monthly**. The app's own validation was
exercised for real: it **refused a due date earlier than the debt date**
(`تاريخ الاستحقاق قبل تاريخ الدين`) and **refused a debt with no direction
selected** (`حقل مطلوب واحد لم يكتمل`) — both correct behaviours caught by the
driver, and the driver was corrected, not the app.

### 3.2 The on-device backup file matches the dataset exactly

`Download/Dhimmah/dhimmah-manual-20260927T104722429.dhimmah` (8,468 bytes), and
the *app's own confirmation sheet* read it back and reported
**`4 شخص · 3 دين · 2 دفعة`**. The file's envelope (pulled and inspected)
carries:

```text
people: 4   debts: 3   debtPeople: 4   payments: 2
obligations: 1   obligationOccurrences: 3   activity: 11   reminders: 0
schemaVersion: 4   formatVersion: 1   encryption: none   kind: manual
```

`debtPeople: 4` is the multi-person debt surviving (A:1 + B:1 + C:2), and
`reminders: 0` is *consistent*, not a loss: notifications are disabled in
settings, so no reminder rows are armed (`التذكيرات متوقفة في الإعدادات`).

### 3.3 Save → verify → the folder

- The **first-run state** is a real state: the screen showed
  `أنشئ مكانًا لنسخك الاحتياطية` and a save with no folder answered with that
  setup, not an error (`AU6_sheet`).
- The **real `ACTION_OPEN_DOCUMENT_TREE` picker** opened through the channel.
- Android itself **refuses a tree grant for `Download` and for the storage
  root** on this device — `Can't use this folder: To protect your privacy`
  (`AUDIT_picker_download.png`). The folder was created through the picker's own
  `CREATE NEW FOLDER`, and the system then asked
  **`Allow ذِمّة to access folder?` → ALLOW** — the grant is the user's.
- The app then showed the folder card `مجلد النسخ الاحتياطية · متاح`, and
  `فحص الآن` (deep check: probe write/read/remove) reported
  **`5 نسخة صالحة`**.
- Timing: save-tap → verified confirmation **9.1 s**.

### 3.4 Two real product bugs were found on the device — and fixed at the root

**Bug 1 — the app wrote into the folder *above* the one it reported.**
`createFolder` returns the new subfolder as a **document** URI, but every folder
operation read it with `getTreeDocumentId` — which on a document URI resolves to
the *tree it was built from*. Result: the app remembered a folder named `Dhimmah
Backups`, wrote its backups into the **parent** `Download/Dhimmah`, and left the
subfolder it had created empty. Files were written, verified and listed — the
app was *self-consistent* — but the design's promise was broken.
**Fix**: document semantics everywhere (`folderDocumentId` resolves either URI
kind to the folder itself). Rebuilt and reinstalled.

**Bug 2 — a deleted folder was reported as `متاح`.** While the phone was in
human use the folder's contents were deleted from outside the app; the app
**kept reporting `متاح · لا توجد نسخ احتياطية`** for a folder that no longer
existed, because a SAF grant survives the deletion of its target and a query on
a vanished document returns *no row* rather than an error. **Fix**: an empty
row is now `FileNotFoundException` → the health becomes *unavailable* and the
screen offers `إعادة السماح`. Rebuilt and reinstalled; the on-device
re-verification of this state is pending (the device locked first — see §5).

### 3.5 One tap → one backup (an interference investigation, resolved)

After the first save the folder held **four** files. logcat shows exactly one
`input tap` in that window — and **three touch-injection pairs with no adb
command**, i.e. the phone was being touched by hand while the confirmation sheet
was up; each touch dismissed the sheet and re-pressed save. The controlled
experiment settles it: **one tap → exactly one new file (5 → 6)**, and every one
of the four is a valid, individually checksummed backup. Not a defect; recorded
because the audit should know where its files came from.

---

## 4. The fix for what you asked about

> **كيف أستطيع استعادة النسخة الداخلية؟ لا يوجد خيار**

There was no option — that was a real design gap. Restoring only worked through
a file the user finds in the system picker, so the safest copy (the one inside
the app) could not be restored from the UI at all.

**Now every copy in `النسخ السابقة` has a restore button** — internal and folder
rows alike:

```text
النسخ السابقة
  ├─ في مجلد النسخ      [استعادة] [حذف]
  └─ داخل التطبيق       [استعادة] [مشاركة] [حذف]
```

One press closes the sheet, inspects that copy (same parse, same checksum, same
validation as a picked file), shows the same preview with the counts and the two
modes (استبدال / دمج), takes the same safety copy first, and restores
transactionally. Nothing about the checks depends on where the copy came from,
and the app refuses a copy it cannot vouch for with the reason.

Proven by tests: `a copy inside the app restores with one press — no file
picker` walks the whole flow and asserts the ledger goes **back** to the
snapshot's state (the person added *after* the snapshot is gone). This test also
caught a third real bug: **a tall restore preview pushed its own استعادة button
below the screen**, where it could not be reached — the sheet now constrains its
height and scrolls. On a phone that was the difference between "can read the
restore" and "can actually confirm it".

On **simplicity**: recovery is now one press inside the app; the folder exists
for the copy that survives uninstalling. No new steps were added anywhere.

---

## 5. What is BLOCKED, and why

The device **locked itself** during the run (`mDreamingLockscreen=true`,
`isKeyguardShowing=true`, and `cmd lock_settings get-disabled` → `false`, i.e.
there is a PIN/biometric). I did not attempt to unlock it. The on-device steps
below therefore stopped here and are **BLOCKED — DEVICE LOCKED**, not skipped:

- on-device re-verification of the two folder fixes (wrong-scope writes,
  vanished-folder state) — the fixes are built, installed and unit/widget-proven
- restore through the *real* picker and the real file-validation matrix
  (the 9 prepared files in `artifacts/validation-files/`)
- duplicate protection ×3 and safety backup on the device
- app restart / folder persistence across restart
- permission revoke and re-authorize
- kill during backup/restore on the device
- large-dataset device timings and frame timings
- the rest of the 26-step journey from step 7 onward

One more environment note: Android exposes **no shell mechanism to revoke a
persisted SAF grant** on a non-rooted device, so the pure *permission-revoked*
state is only reachable through the system UI by the user; `pm clear` (reinstall
simulation) is available and is the planned route for the reinstall step.

---

## 6. Platform confidence — kept separate

| platform | what is proven | what is not |
| --- | --- | --- |
| **Android — proven on device** | real UI dataset creation; real tree picker; folder grant via ALLOW; external save with read-back verification; on-device file with correct counts; `فحص الآن`; internal + folder history; the app's own validation refusals | |
| **Android — proven by tests only** | the two folder fixes above; internal restore end-to-end; tall-sheet fix; duplicate protection; safety backup; kill matrix (16/16); retention | their on-device confirmation |
| **Android — blocked** | everything in §5 | |
| **iOS** | nothing | **iOS NOT PROVEN.** The Swift channel is written to the documented APIs and **not compiled** (no Xcode here); no iPhone exists in this environment. Nothing about Android counts toward iOS. |

---

## 7. Final verdict

**NOT READY** — by the audit's own rule: the critical restore path *on the
device* is not yet fully proven, and the device is locked.

The honest state:

- **Works, seen on the real device:** creating the dataset; the first-run folder
  state; choosing a folder through Android's real picker; granting access;
  saving a backup that is written **and read back and verified**, with the
  confirmation naming the file, its size and the dataset counts; deep folder
  check; the folder card and its actions.
- **Fixed on the device's evidence, awaiting on-device re-test:** the
  wrong-scope folder writes, the vanished-folder state, and — the one you asked
  for — **restoring the internal copy in one press**.
- **Blocked by the lock screen:** the rest of the journey.

When you unlock the phone, finishing this is short, and it is exactly the part
you care about: open **النسخ السابقة → داخل التطبيق → استعادة**, confirm, and
the ledger comes back. Then the folder round-trip and the reinstall, and the
audit closes.

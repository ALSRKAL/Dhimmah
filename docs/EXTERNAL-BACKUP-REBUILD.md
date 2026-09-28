# EXTERNAL BACKUP — rebuilding the save path

The backup subsystem had one architectural fault left, and this is the record of
removing it: the way a copy left the app was the system **share sheet**, which is
not a way to obtain a file. On the phone this was tested on, the share sheet
offered messaging applications, Quick Share, Gmail, ChatGPT and Telegram — and
nowhere that stores a file. A user of that build could not end up with a
`.dhimmah` they owned, and because `share_plus` returns no destination, the app
could never have verified one if they had.

Saving and sharing are now two different things, and the save is a real one.

- [1. What was wrong](#1-what-was-wrong)
- [2. The platform audit](#2-the-platform-audit)
- [3. What was built](#3-what-was-built)
- [4. The save contract](#4-the-save-contract)
- [5. What was preserved](#5-what-was-preserved)
- [6. Tests](#6-tests)
- [7. Performance](#7-performance)
- [8. Real-device status](#8-real-device-status)
- [9. Acceptance matrix](#9-acceptance-matrix)
- [10. Verdict](#10-verdict)

---

## 1. What was wrong

Two independent facts, and the design only worked if neither were true.

**The share sheet has no file destination on this device.** Proven by opening it
with a real backup in hand: `docs/final-acceptance/device/v10/logs/X3_share_sheet.xml`
lists every target, and after scrolling there is no Files, no Drive, no
"Save to…", no "More". The targets are chat applications, Quick Share, Gmail,
ChatGPT and Telegram.

**A share cannot be verified.** `share_plus` hands the file to the system chooser
and returns no destination URI, so the app cannot reopen what the user chose.
There was therefore no way to implement the read-back the mission requires, on
top of that mechanism, at any level of care.

The design conclusion is not "find more share targets" — it is that **sharing was
never the backup**, and the code had no other way out of the app.

---

## 2. The platform audit

Before writing anything, the installed stack was read rather than assumed:

| package | version |
| --- | --- |
| `file_selector` | 1.1.0 |
| `file_selector_android` | 0.5.2+11 |
| `file_selector_platform_interface` | 2.7.0 |
| `share_plus` | 13.3.0 |
| `path_provider` | 2.1.6 |

`file_selector_android 0.5.2+11` contains **no `ACTION_CREATE_DOCUMENT` anywhere**
(`grep -rl ACTION_CREATE_DOCUMENT` over the package returns nothing), and its
`getSaveLocation` falls through to the platform interface's deprecated
`getSavePath`, which Android does not implement. So there is no plugin route to a
user-chosen save location on this stack.

`ACTION_CREATE_DOCUMENT` also returns a `content://` URI, which `dart:io` cannot
open — so **some** platform bridge is required whoever writes it. The app already
has a house pattern for one (`AppUpdateChannel`: a Kotlin class with a channel
name, a launcher registered at field initialisation, and registration and
disposal in `MainActivity`), and the new bridge follows it exactly.

Rejected alternatives, and why:

- **A fictional MIME type** (`application/vnd.dhimmah`) — providers that do not
  know it refuse the document, which is the same class of mistake that made the
  restore picker look empty. `application/octet-stream` is what every provider
  accepts, and the content is what makes the file a backup.
- **Writing to a shared folder by path** — that needs broad storage permission,
  which this app deliberately does not ask for, and it would put a user's ledger
  where other applications can read it.
- **Persisting the returned URI and calling it "the external backup"** — the file
  lives where the user put it and may be moved or deleted; metadata about it
  would go stale and become a claim the app cannot keep.

---

## 3. What was built

### Android — `BackupFileChannel.kt`

Four narrow calls, no policy:

| call | what it does |
| --- | --- |
| `createDocument` | `ACTION_CREATE_DOCUMENT` via `ActivityResultContracts.CreateDocument`; answers with what the user chose, or null if they changed their mind |
| `write` | writes the bytes through `ContentResolver.openOutputStream(uri, "wt")`, flushes, closes; answers with the number written |
| `read` | reads the document back through `ContentResolver.openInputStream` |
| `metadata` | the name and size the **provider** reports |

Deliberate details:

- `"wt"`, not `"w"`: a document the user picked may already exist, and without
  truncation a shorter backup would leave the tail of the previous file behind —
  a file that is neither backup.
- An empty payload is refused outright, with its own error code
  (`empty_bytes`), because a zero-byte document reporting success is the one
  outcome the class exists to prevent.
- I/O runs on a single background thread and results are posted to the main
  thread: a backup is megabytes, and that is not work for the thread drawing
  frames.
- The provider is the authority on the name. If Android changes the suggested
  filename — it may append its own extension, or resolve a collision — what comes
  back is what the app reports.

### Dart — `SaveTarget`

```dart
abstract interface class SaveTarget {
  String get displayName;
  String get identifier;   // opaque: a content:// URI on Android
  Future<int> write(List<int> bytes);
  Future<List<int>> read();
  Future<int?> size();
}
```

The identifier is never treated as a path, and nothing above the gateway learns
what it is. `FileGateway` gained one method, `createSaveTarget({suggestedName})`,
whose null answer means the user changed their mind.

### Dart — `ExternalBackupService`

The order is the contract, and every step is checked before the next:

1. take a snapshot — the same atomic, checksummed write the app already makes;
2. read those exact bytes and **parse them**, so the user is not asked to choose
   a home for a payload this build cannot read back itself;
3. ask where it should go;
4. write;
5. **read the document back** and compare it with what was sent;
6. only then report success.

The comparison is: not empty, not shorter, **byte-identical**, then parsed again
with `BackupFormat.parse` — which recomputes the checksum over the payload and
refuses the file if the envelope's stated checksum disagrees. The counts shown in
the confirmation come from *that* parse, so what the user is shown is what the
file on their disk holds.

A second, sharper reason for comparing bytes rather than lengths: a provider that
rewrites a document with different content of the *same length* passes a length
check. There is a test for exactly that.

### The screen

`Backup & Restore` now lists two distinct acts:

| row | what it is |
| --- | --- |
| **حفظ نسخة خارجية** | the backup: the user picks the place, the app writes and then verifies the document |
| **مشاركة النسخة** | a convenience: send a copy to another application |
| استعد من ملف | restore, unchanged |
| النسخ السابقة | the internal history, unchanged |

The health card's headline is now `نسخة داخلية محفوظة` — "an internal copy is
saved" — rather than `بياناتك محفوظة`. That is deliberate: saying "your data is
saved" while the user has just asked for a copy somewhere they own, and that copy
failed, would be the app overstating what it knows. The card describes the
internal state, and says so.

Every ending of a save is stated:

| outcome | what the user sees |
| --- | --- |
| written and read back | a confirmation with the file's own name and size, and the row counts read from that file |
| written but not verifiable | `كُتب الملف لكن تعذّر التحقق منه بعد الحفظ` |
| empty or short | `الملف المحفوظ فارغ أو ناقص` |
| the destination refused | `تعذّر كتابة الملف في المكان الذي اخترته` |
| a platform with no such flow | `هذا الجهاز لا يوفّر اختيار مكان للحفظ` |
| the user backed out | nothing at all — cancelling is an answer, not a failure |

---

## 4. The save contract

```text
SUCCESS  ⇒  the document was read back
            AND it is byte-identical to what was generated
            AND it parses as a Dhimmah backup
            AND the checksum recomputed over its payload matches the envelope
            AND the provider does not report it as empty
```

`save` returns a report rather than a boolean, so a caller cannot collapse
"verified" and "attempted" into one value: `ExternalSaveReport.outcome` is
`saved`, `cancelled` or `failed`, and `failed` carries the step that failed.
There is no code path that returns `saved` without having read the document back.

---

## 5. What was preserved

Nothing that already worked was touched, and no guarantee was weakened:

- the delete-while-open behaviour proven on the phone, the immediate row removal,
  the empty state, the failed-delete handling and its message;
- atomic local writes, temporary-file handling, collision-suffixed names,
  checksum, canonical payload, structural/relationship/financial validation;
- the transactional restore with rollback, the safety snapshot before a
  replacement restore, identity-based merge, idempotency, retention (5 automatic
  / 3 safety / manual never auto-deleted), derived-state and notification rebuild;
- the restore picker with **no** type filter, which is what stopped it hiding
  valid files, now pinned by a test;
- `encryption = none`, disclosed honestly, and no keystore or PIN state in a
  backup; no new backend, account, cloud or network dependency.

One consequence is worth stating plainly: the app deletes **internal** snapshots
from its history, and it cannot delete the external file — the user owns it, and
the app has no persistent permission over it. Deleting an entry in
`النسخ السابقة` has never touched an external copy, and now that external copies
exist for real, the privacy note on the screen already says where each kind
lives.

---

## 6. Tests

| what | count | where |
| --- | --- | --- |
| the save contract | 10 | `test/data/external_backup_test.dart` |
| the channel and the picker filter | 8 | `test/platform/file_gateway_test.dart` |
| Android wiring (channel name, document type, `CreateDocument`, resolver, disposal) | 4 | `test/platform/android_setup_test.dart` |
| the screen (external save, verification failure, cancel, sharing, delete, empty state, refusal) | 10 | `test/widget/backup_screen_test.dart` |
| corruption matrix (now includes unknown currency and duplicate ids) | 15 | `test/data/backup_hardening_test.dart` |

The save contract tests are the point. Written explicitly and each one a way a
save could look fine and not be:

- a chooser that succeeded is **not** a save (the destination exists and the
  write refuses → `failed`);
- a short write is a failure, not a smaller backup;
- a document that cannot be read back is not called saved;
- a document that reads back as something else — **the same length, different
  bytes** — is refused;
- a document the provider reports as empty is refused, even after a write that
  claimed the full length;
- a provider that will not report a size at all is *not* a failure (the bytes
  were already checked, and a missing description is not a bad file);
- cancelling is neither a success nor an error;
- the snapshot behind an external save is itself a real internal backup.

Those tests found and fixed two classification bugs of my own while being
written: a failure *while reading back* was being reported as a write failure,
and a same-length corruption was being reported as "incomplete" rather than
"unverifiable".

---

## 7. Performance

Host, 500 people / 2,500 debts / 1.04 MB, `test/tool/external_save_profile_test.dart`:

| step | time |
| --- | --- |
| internal snapshot (write + checksum) | 815 ms |
| **external save (write + read back + verify)** | **1083 ms** |
| of which the verification | 268 ms |
| inspect (validate + read) | 318 ms |
| restore (replace) | 1108 ms |

So proving a copy costs about a quarter of the save again — the price of reading
it back. That is the cost this design chooses to pay, and it is measured rather
than asserted.

Device measurements from the earlier phase remain in
`docs/PERFORMANCE-GATE.md`; the numbers for the new save path are host-only,
because the phone was unavailable (see §8).

---

## 8. Real-device status

The phone (SM-S928U1, Android 16) was reachable for the first half of this
mission and then left the network: `adb connect` times out, `adb mdns services`
is empty, and all candidate ports are closed. There is a reconnect loop watching
for it (`tool/wait_for_device.py`), which installs the current build the moment it
returns; it has not returned.

An emulator was tried as a *smoke* environment for the Kotlin bridge and was not
usable: it began raising `Application Not Responding` dialogs for its own
launcher and then for `com.android.systemui` while the host was under load from
the test runs. Nothing was concluded from it, and in any case an emulator is not
the device this mission names — emulator output is not recorded as device
evidence here.

Consequently:

- **The new save flow has not been exercised on hardware.** It compiles, the
  Kotlin is wired and pinned by tests, and the Dart contract is proven against
  every failure mode — but the first real `ACTION_CREATE_DOCUMENT` has not been
  shown to the device. Status: `NOT PROVEN`.
- Everything downstream of an external file — picking it, restoring it,
  reinstalling and restoring it — is likewise `NOT PROVEN` for this build.

What *is* proven on the device, from the previous phase, and was not changed by
this work: the delete-while-open behaviour, the immediate row update, the empty
state (screenshots in `docs/final-acceptance/device/v10/screenshots/`).

---

## 9. Acceptance matrix

Statuses exactly `PASS`, `FAIL`, `NOT PROVEN`, `SKIPPED — ENVIRONMENT`.

| # | Area | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Internal backup | PASS | `backup_hardening_test.dart`, device snapshots created in the previous phase |
| 2 | External save UI | PASS (code + test) | `backup_screen_test.dart` — the row exists, is the primary action, and confirms only after verification |
| 3 | External file created | NOT PROVEN | implemented and pinned; the phone was unreachable for the real run |
| 4 | External file non-zero | NOT PROVEN | as above |
| 5 | External read-back | NOT PROVEN | as above; the contract is proven against every failure mode in `external_backup_test.dart` |
| 6 | External checksum | NOT PROVEN | as above; `BackupFormat.parse` recomputes it, and the parse is mandatory before success |
| 7 | Restore picker | NOT PROVEN | no external file could be produced on this device |
| 8 | `.dhimmah` selectable | NOT PROVEN | as above |
| 9 | Invalid file rejection | PASS | corruption matrix, 15 cases, database fingerprint unchanged in each |
| 10 | Restore preview | PASS | `backup_hardening_test.dart` |
| 11 | Safety backup | PASS | `backup_hardening_test.dart`, `backup_round_trip_test.dart` |
| 12 | Restore commit | PASS | `backup_round_trip_test.dart` |
| 13 | Restore correctness | PASS | round trip, hardening, compatibility |
| 14 | UI refresh after restore | PASS | `backup_screen_test.dart` |
| 15 | Delete open-sheet refresh | **PASS (device)** | `D1_delete_before.png` / `D1_delete_after.png` |
| 16 | Failed delete | PASS | `backup_screen_test.dart`, real `EACCES` |
| 17 | Empty state | **PASS (device)** | `E4_empty_state.png` |
| 18 | Retention | PASS | `backup_hardening_test.dart` |
| 19 | Manual backup protection | PASS | same |
| 20 | Merge | PASS | same |
| 21 | Repeated merge | PASS | same (idempotent) |
| 22 | Notification rebuild | PASS | `notification_lifecycle_test.dart` |
| 23 | Uninstall/reinstall | NOT PROVEN | needs an external file, which needs the phone |
| 24 | Post-reinstall restore | NOT PROVEN | as above |
| 25 | Device performance | NOT PROVEN | new path is host-only this session |
| 26 | Device p95 / frame timing | NOT PROVEN | as above |
| 27 | Device memory | NOT PROVEN | as above |
| 28 | Kill / interruption | PASS | `backup_kill_matrix_test.dart` (16/16) |
| 29 | Widget tests | PASS | 10 tests, `backup_screen_test.dart` |
| 30 | Full regression | PASS | see §10 |

---

## 10. Verdict

**PARTIAL**

The architectural fault is gone. Sharing and saving are separate concepts, the
save is Android's own document creation flow, and a save reports success only
after the document has been read back and compared byte for byte with what was
generated — with the checksum recomputed by the format's own reader. The share
sheet remains as the convenience it always was, and is no longer the only way out
of the app.

Everything that could be proven without the phone is proven: **597 tests passing**
on the full suite, **153 tests green on three consecutive runs** of the critical
set, a clean analyzer, and a save contract with ten tests aimed specifically at
the ways a save can look successful and not be. Two defects of my own were found
by that coverage and fixed, the corruption matrix now covers the
unknown-currency and duplicate-id cases the mission listed, and the cost of the
verification is measured rather than asserted (268 ms of a 1,083 ms save at
500 people / 2,500 debts).

It is not `CLOSED`, and the reason is not a design gap: the phone left the
network part-way through and never came back, so the first real
`ACTION_CREATE_DOCUMENT`, the first real external `.dhimmah`, the picker, the
reinstall and the device performance numbers are all `NOT PROVEN`. None of them
is inferred from a host test.

To finish it, with the phone reachable:

1. `flutter build apk --debug` and install, then press **حفظ نسخة خارجية** and
   choose a folder in the system chooser — the app writes the document, reads it
   back, and confirms only if it verifies;
2. note the file, its name and its size, then delete the app and reinstall it;
3. press **استعد من ملف**, pick that file in the real picker, and confirm the
   restored ledger;
4. re-run the delete-while-open check to confirm it is still green.

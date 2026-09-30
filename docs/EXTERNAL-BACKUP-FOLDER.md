# DHIMMAH BACKUP FOLDER — the storage-location architecture

The backup had a real save flow but no *home*. Every save asked the user where to
put one file, and nothing remembered the answer. This is the record of building
the missing piece: a `Dhimmah Backup Location` — chosen once, remembered, verified,
and returned to automatically for save, restore and delete — across Android and
iOS, with the two storage layers kept visibly apart.

- [1. The product model](#1-the-product-model)
- [2. Android](#2-android)
- [3. iOS](#3-ios)
- [4. The cross-platform contract](#4-the-cross-platform-contract)
- [5. Reconciliation](#5-reconciliation)
- [6. What the screen shows](#6-what-the-screen-shows)
- [7. Security and permissions](#7-security-and-permissions)
- [8. Tests](#8-tests)
- [9. Real devices](#9-real-devices)
- [10. Acceptance matrix](#10-acceptance-matrix)
- [11. Remaining risks](#11-remaining-risks)
- [12. Verdict](#12-verdict)

---

## 1. The product model

Two layers, never confused:

| layer | what it is for | where it lives |
| --- | --- | --- |
| **Internal backup** | automatic protection, the safety snapshot, fast local recovery | the app's own storage, private |
| **User backup folder** | portable `.dhimmah` files the user owns: manual saves, restore, uninstall/reinstall recovery | a folder the user chose, outside the app |

The folder is called **`Dhimmah Backups`**, and the app creates it inside
whatever the user picks:

```text
<chosen location>/
    Dhimmah Backups/
        dhimmah-manual-20260926-140522.dhimmah
```

Decisions that were made explicitly rather than inherited:

- **Automatic backups stay internal.** They are protection, not archival, and
  writing every automatic snapshot into a folder the user owns would fill it with
  files they did not ask for. Manual saves and the user's own copies go in the
  folder; the safety snapshot stays internal so that a restore never depends on
  the user's folder being writable.
- **The folder reference is stored in its own small file**, not in the settings
  table. The schema version is stamped into every backup file (`BackupService`
  takes it from the database), so adding a settings column would bump the version
  on a change that has nothing to do with the ledger's data — and backups written
  by the previous build would then be refused by this one, for a reason no user
  could see.
- **Deleting a history entry deletes from the layer it came from.** An internal
  entry deletes an internal file; a folder entry deletes the user's document.
  Neither touches the other, and the screen says which is which.
- **Changing the folder keeps the old one.** Nothing is moved or deleted; the old
  folder is released and its files remain the user's.

---

## 2. Android

Mechanism: **`ACTION_OPEN_DOCUMENT_TREE`** through
`ActivityResultContracts.OpenDocumentTree`, then `DocumentsContract` for
everything inside it. Available since API 21, and the mechanism Android provides
precisely so an app can be granted *one directory* without a storage permission.

`BackupFileChannel` (one channel, two groups of calls — the single-document
chooser from the previous pass, and the folder operations):

| call | what it does |
| --- | --- |
| `chooseFolder` | opens the directory picker; **takes the persistable URI permission** in the same reply, which is what makes the folder still ours next launch |
| `createFolder` | makes `Dhimmah Backups` inside the chosen folder, if the provider allows directory creation |
| `writeDocument` | finds an existing document of the same name (so a re-save replaces rather than litters) or creates one, writes, flushes, closes |
| `readDocument` | reads a document back — how a saved copy is verified |
| `listDocuments` | every child, with the provider's own name, size, modification time and type |
| `deleteDocument` | removes one document |
| `verifyWritable` | writes a probe file, reads it back, removes it — the only honest way to know a folder that lists fine also accepts writes |
| `describeFolder` | what the provider says now, and whether the grant still holds |
| `releaseFolder` | gives the grant back, when the user changes folder |

Everything runs on one background thread; results are posted to the main thread.
The provider is the authority on names: if Android renames on a collision, what
came back is what the app reports and remembers.

---

## 3. iOS

`ios/Runner/BackupFolderChannel.swift`: the equivalent mechanism, which on iOS is
a **security-scoped bookmark** — `UIDocumentPickerViewController(forOpeningContentTypes: [.folder])`
to choose the folder, `url.bookmarkData()` to remember it, and
`startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`
bracketing every access afterwards. The bookmark is the folder's identifier;
nothing else is persisted, and no raw temporary URL is assumed to keep working.

**This file has not been compiled.** The machine this was written on has no
Xcode, so it is code review only, and it is recorded as such rather than as
proven. `AppDelegate` creates the channel in `didInitializeImplicitFlutterEngine`
with the engine's messenger, as Flutter's UIScene migration guide describes for
method channels; the method surface is identical to the Android channel's, so
the Dart layer above is shared unchanged.

A review without a compiler found, and fixed, faults that would each have
stopped it: the channel was registered as a plugin it did not declare itself
to be, from a callback that runs before the scene's engine exists; one throwing
call lacked `try` and another parsed as a member of `String`; the picker's
delegate was held weakly and gone before the user chose; replies were sent off
the main thread; and security-scoped access was opened on every call and never
closed. Fixed by reading the APIs, still not by building them.

---

## 4. The cross-platform contract

The domain sees one interface and no platform types:

```dart
abstract interface class BackupLocationRepository {
  Future<BackupLocation?> getConfiguredLocation();
  Future<ChosenFolder?> chooseLocation();
  Future<BackupLocationHealth> check({bool deep});
  Future<List<ExternalBackupFile>> listBackups();
  Future<ExternalBackupFile> createBackupFile({required String suggestedName, required List<int> bytes});
  Future<List<int>> readBackup(ExternalBackupFile file);
  Future<void> deleteBackup(ExternalBackupFile file);
  Future<String?> initialLocation();
  Future<void> clearLocation();
}
```

`BackupLocation` is an opaque identifier, the name the user recognises, the
platform, when it was last verified, and whether the access is *standing*. A
`content://` tree URI and a security-scoped bookmark are the same thing here, and
neither is ever converted into a path — that rule is stated in the interface's
documentation, because it is the one that keeps a provider difference from
becoming a crash.

The health model is the eight states the mission named — `notConfigured`,
`configured`, `verifying`, `available`, `unavailable`, `permissionRevoked`,
`readOnly`, `error` — plus what the check counted: valid backups, files that are
named like backups but are not, and unrelated files.

**First use** is a state, not an error: with no folder configured, the screen
shows `أنشئ مكانًا لنسخك الاحتياطية` with `اختيار مجلد النسخ الاحتياطية` and
`لاحقًا`. A save attempted with no folder answers `needsFolder`, and the screen
offers that setup rather than an error message.

**A folder the app cannot make `Dhimmah Backups` inside** is never adopted
silently: the choice comes back as `needsConfirmation`, and the user is asked
whether to use the folder they picked. Declining clears it and asks again.

**After a reinstall** the app offers to re-authorize the folder or restore from a
file; it does not claim the old grant survived, because on Android it does not.

---

## 5. Reconciliation

The folder **is** the authority on the user's external backups, so there is
nothing to go stale: files the user added, deleted or moved outside the app are
simply what the next listing says.

What the listing does *not* do is take a file's word for what it is:

- a name ending `.dhimmah` is read and parsed (`BackupFormat.parse`, which
  recomputes the checksum);
- a file that parses becomes a valid backup, with its kind and date taken from
  its own envelope;
- a file that does not parse is shown as **invalid**, not offered as a backup;
- a file with another name is **unrelated**, and left alone entirely;
- a `.dhimmah` over 64 MB is classified without being read — a Dhimmah backup at
  ten thousand records is a few megabytes, so anything far larger is not
  something this app wrote, and reading it would only be to say so;
- a file the app *cannot read right now* is neither valid nor invalid — it is
  `unchecked`, because a provider hiccup is not proof a file is broken.

Content validation therefore covers §29's "smart file discovery" and §23's
"never trust the name", and the existing MIME-filter defect stays pinned by
`test/platform/file_gateway_test.dart`.

---

## 6. What the screen shows

Between the internal-status card and the actions, the folder has its own card:

| state | what the user sees |
| --- | --- |
| not configured | the setup card: what the folder is for, and `اختيار مجلد النسخ الاحتياطية` |
| available | `مجلد النسخ الاحتياطية` · `متاح` · `N نسخة صالحة` · `تغيير المجلد` · `فحص الآن` |
| read-only | the folder row with `المجلد لا يقبل الكتابة` |
| revoked / unreachable | the folder row with `مجلد النسخ الاحتياطية غير متاح` and `إعادة السماح` |

`فحص الآن` does the deep check: the probe write, read and removal.

The history sheet now has **two sections**, headed `في مجلد النسخ` and
`داخل التطبيق`. A folder row is listed by its own file name with its kind, date
and size, and deleting it removes the document from the folder and updates the
open sheet in place — the same delete → authoritative state → refresh chain that
was proven for internal entries, now covering both layers. A folder row has no
share button, on purpose: the file already lives outside the app, and sharing it
would mean copying it back into the sandbox first.

One consequence is worth stating: the history row is enabled when *either* layer
has something in it. After a reinstall with a folder full of backups but an empty
app, hiding the history would hide the only copies there are — that gap was found
by a test and fixed.

---

## 7. Security and permissions

- **No broad storage permission.** The folder grant is the user's own choice,
  made to this app, for this folder, and revocable by them; nothing else is
  requested.
- **The persisted grant is taken when the folder is chosen** and released when
  the user changes or clears it.
- **No credentials, no PIN or keystore state, no sensitive file names.** The
  suggested name is the app's own stamp; the tests assert it carries no user data
  and cannot traverse a directory.
- **`encryption = none` is still disclosed honestly** on the screen, and nothing
  in this work added encryption silently.
- **Offline-first, unchanged**: no account, no server, no upload. Cloud
  destinations that appear in the system picker are user-chosen storage, not a
  backend.

---

## 8. Tests

| what | count | where |
| --- | --- | --- |
| the save contract (verified document, no-folder state, refused write, read-only, zero-byte, same-length rewrite) | 6 | `test/data/external_backup_test.dart` |
| the folder contract (choose/remember, revoked, unavailable, read-only, not-configured, reconciliation, external deletion, content-not-name, forget) | 10 | same |
| the gateway and the picker (filter guard, initial location, cancelled, channel) | 10 | `test/platform/file_gateway_test.dart` |
| the Android wiring (channel name, MIME, `CreateDocument`, `OpenDocumentTree`, resolver, disposal) | 4 | `test/platform/android_setup_test.dart` |
| the screen (setup state, folder card, invalid note, revoked, two-layer history, folder delete refresh, save confirm, verification failure) | 15 | `test/widget/backup_screen_test.dart` |
| everything else that was already green | — | 572 before this mission |

**609 tests pass on the full suite**, with the analyzer clean. Two of the tests
found real product gaps while being written: the history row was disabled when a
configured folder held copies but the app had no internal snapshot yet (exactly
the after-a-reinstall state), and a revoked folder was shown as a card with no
way back.

---

## 9. Real devices

**Android (S24 Ultra).** The phone left the network part-way through this mission
and has not returned; a reconnect loop (`tool/wait_for_device.py`) is armed and
will install the current build the moment it does. The folder flow is *not*
device-proven.

**Emulator (smoke only — not device evidence).** With the real phone away, the
flow was driven on an emulator to at least prove the code runs:

- the real `ACTION_OPEN_DOCUMENT_TREE` picker opens through the channel
  (`EM3_tree_picker.xml`);
- the first-run setup sheet renders, and cancelling the picker returns the app to
  that setup state with nothing silently chosen (`EM5_after.png`);
- **the emulator's own DocumentsUI refuses a tree grant for every folder in
  primary storage** — `Can't use this folder: To protect your privacy, choose
  another folder`, with `USE THIS FOLDER` greyed out (`EM6_after_folder_choice.png`).
  That is the image's provider, not the app: the app never received a folder, and
  it behaved correctly by returning to the setup state rather than inventing one.

**iOS.** No iPhone and no macOS toolchain on this machine: `NOT PROVEN — REAL IOS
HARDWARE`, and the Swift is not compiled.

---

## 10. Acceptance matrix

Statuses exactly `PASS`, `FAIL`, `NOT PROVEN`, `SKIPPED — ENVIRONMENT`. **DEVICE**
means observed on hardware; **CODE** means proven by a test against the real
implementation.

| # | Area | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Internal backup | PASS | `backup_hardening_test.dart`; device snapshots from the earlier phase |
| 2 | External save UI | PASS (CODE) | `backup_screen_test.dart` |
| 3 | Folder chosen once and remembered | PASS (CODE) | `external_backup_test.dart` — choose/remember/initial-location |
| 4 | `Dhimmah Backups` subfolder created | PASS (CODE) | repository + channel tests; **DEVICE: NOT PROVEN** |
| 5 | Save writes into the folder | PASS (CODE) | save contract tests; **DEVICE: NOT PROVEN** |
| 6 | External file non-zero | PASS (CODE) | zero-byte refused in tests; **DEVICE: NOT PROVEN** |
| 7 | External read-back | PASS (CODE) | read-back mandatory; same-length rewrite refused; **DEVICE: NOT PROVEN** |
| 8 | External checksum | PASS (CODE) | `BackupFormat.parse` recomputes it before success |
| 9 | Restore picker | PASS (CODE) | no filter, initial-location hint pinned |
| 10 | `.dhimmah` selectable | PASS (CODE) | content decides, name does not; **DEVICE: NOT PROVEN** |
| 11 | Invalid file rejection | PASS | corruption matrix, 15 cases, fingerprint unchanged |
| 12 | Restore preview | PASS | `backup_hardening_test.dart` |
| 13 | Safety backup | PASS | internal, independent of the folder |
| 14 | Restore commit | PASS | `backup_round_trip_test.dart` |
| 15 | Restore correctness | PASS | round trip, hardening, compatibility |
| 16 | UI refresh after restore | PASS | `backup_screen_test.dart` |
| 17 | Delete open-sheet refresh | **PASS (DEVICE)** + CODE | `D1_delete_before/after.png`; folder layer covered by tests |
| 18 | Failed delete keeps item | PASS | real `EACCES`; folder failures mapped |
| 19 | Empty state | **PASS (DEVICE)** + CODE | `E4_empty_state.png`; folder empty state tested |
| 20 | Retention | PASS | 5 automatic / 3 safety / manual never removed |
| 21 | Manual backup protection | PASS | same |
| 22 | Merge / repeated merge | PASS | idempotent |
| 23 | Notification rebuild | PASS | `notification_lifecycle_test.dart` |
| 24 | Folder health states | PASS (CODE) | eight states, counted contents |
| 25 | Uninstall/reinstall | NOT PROVEN | needs the phone; the app offers re-authorization |
| 26 | Post-reinstall restore | NOT PROVEN | as above |
| 27 | Device performance | NOT PROVEN | host only: verification costs 268 ms of a 1,083 ms save |
| 28 | Device p95 / frames | NOT PROVEN | as above |
| 29 | Device memory | NOT PROVEN | as above |
| 30 | Kill / interruption | PASS | `backup_kill_matrix_test.dart` (16/16) |
| 31 | Widget tests | PASS | 15 tests |
| 32 | Full regression | PASS | 609 passed, 0 failed |

---

## 11. Remaining risks

Only genuine ones:

1. **The folder flow has never run on hardware.** The Android channel compiles
   and is pinned by tests; the emulator's provider refuses folder grants, so the
   first real `OpenDocumentTree` → create → save → verify has not been watched.
   Until it is, this is `NOT PROVEN` on the device, whatever the tests say.
2. **The iOS Swift is uncompiled.** It follows documented APIs and the UIScene
   registration pattern, but a compile on macOS is the only real check, and
   iOS behaviour is unproven.
3. **A provider may refuse `createFolder`.** The product handles it by asking the
   user rather than adopting a folder silently; on a provider that refuses
   directory creation *and* whose user wants a subfolder, the answer is a
   different provider.
4. **Reconciliation reads every `.dhimmah` in the folder.** With a handful of
   backups that is milliseconds; with hundreds of large files it would be slow.
   The 64 MB cap bounds the worst case, but a folder that large is not something
   this app created, and the cost is paid when the screen opens, not in the
   background.

---

## 12. Verdict

**PARTIAL**

The architecture the mission asked for exists and is tested end to end at the
layer that can be tested here: one platform-neutral `BackupLocation` contract,
eight health states, first-run setup, a folder chosen once and remembered with a
persisted grant, save-into-folder with mandatory read-back verification,
content-based reconciliation where the folder is the authority, deletion from
either layer with the open sheet updating in place, and a screen that keeps the
two layers visibly apart.

`CLOSED` needs hardware. The S24 Ultra was unreachable for the second half of the
work, the only emulator available refuses the folder grant at the provider level,
and there is no iPhone. Nothing is claimed from a host test that the mission
requires from a device, and the four steps that close it are the same ones the
previous mission listed, now with the folder in the middle of them:

1. install, press `حفظ نسخة خارجية`, choose a folder in the real picker;
2. confirm the app creates `Dhimmah Backups`, writes the document, and reports a
   verified save;
3. restart the app and confirm the same folder is recognised, then restore from
   it through the real picker;
4. uninstall, reinstall, re-authorize, and restore again.

# Backup encryption: the decision, and why

**Status:** decided — **A. no encryption**, with the limitation stated in the file
and on the screen.
**Date:** 2026-09-26
**Applies to:** `.dhimmah` files written by `BackupFormat.currentFormatVersion` 1.

This is a record of an engineering decision, not a plan. It exists because the
question "why is the backup not encrypted?" deserves an answer that can be
checked, and because the answer changes only if one of the facts below changes.

---

## What a backup is, and who can read it

A `.dhimmah` file is the entire ledger — every person, every record, every
payment, the notes attached to them, and the settings that are not tied to the
device — written as plain UTF-8 JSON with a SHA-256 checksum over the payload.
The checksum is *integrity*: it proves the file arrived as it was written. It is
not confidentiality, and the file says so:

```json
"encryption": "none"
```

Where the file lives matters more than what is in it:

| Copy | Who can read it |
| --- | --- |
| Automatic and safety snapshots | The app's private directory. No other app, and nothing on the device without root, can read them. |
| A copy the user shares | Wherever the user sent it — their files app, a cloud drive, a chat. **Anyone who can open that file can read the ledger.** |

Android's own backup is switched off for this app
(`allowBackup="false"`, `fullBackupContent="false"`,
`dataExtractionRules` restricting cloud and device transfer), so the ledger
never leaves the device through the operating system either.

## The options, against the things that matter

| | **A. none** | **B. password** | **C. device-backed key** | **D. hybrid (B + C)** |
| --- | --- | --- | --- | --- |
| Who can read a shared file | anyone who has it | only someone with the password | only this device | either |
| Restore on a **new** phone | works | works, password needed | **impossible** — the key never left the old device | works with the password |
| Restore after reinstall | works | works, password needed | **impossible** — same reason | works with the password |
| Forgotten password | n/a | **the data is gone. There is no recovery, by design.** | n/a | same |
| Key management | none | password → KDF (PBKDF2/Argon2) → AES-GCM; salt + parameters must travel in the file | Android keystore; key is non-exportable, and is deleted with the app | both paths |
| Usability | open the file | type a password to save, and again to restore | nothing | two ways to be confused about which key was used |
| Security | none against someone who has the file; strong against other apps on the device | strong, **as strong as the password the user actually chooses** | strong, tied to hardware | as strong as the weakest path allowed |
| Performance | none | +KDF (deliberately slow: ~100 ms+) and streaming AES; measurable but small next to the encode | none | small |
| Implementation complexity | none | a key-derivation choice, a cipher, a container format, a version bump, a password prompt in two flows, an error taxonomy for "wrong password" vs "damaged", and a warning the user must accept — the last of which people click through | keystore plumbing, plus the recovery dead end above | all of it |
| Worst realistic outcome | a shared file is read by someone the user sent it to, or by anyone who finds it | **a user loses every record because they cannot remember a password they set a year ago** | **a user loses every record because they replaced their phone** | a user cannot tell which path a file needs |

## Why A, and not the others

The brief for this feature was one sentence: *a user must be able to get their
data back.* Every other property is secondary to that, and the options divide
cleanly on it:

* **C is not a backup.** A file that can only be read by the device that wrote it
  fails the one job a backup has. It would be a fine way to protect the *live*
  database (a different feature), and a false promise as a portable copy.
* **B moves the risk, it does not remove it.** Encryption protects a file that
  leaked; a password protects it by making the file unreadable to its owner when
  the password is forgotten. For a ledger of family loans — data with no
  regulatory requirement, and no backup of the backup — trading "someone who has
  the file can read it" for "the owner can permanently lose it" is the wrong
  trade. And the honest version of B needs a warning that says *if you forget
  this, your records are gone forever*, which is precisely the sentence this
  feature exists to eliminate.
* **D is worse than either half.** It offers both, so it must carry both risks
  plus a new one: a user who cannot tell which kind of file they are holding.

What A must do instead is be **honest**, and it is:

* the file states `"encryption": "none"`;
* the restore screen says so before anything is restored:
  «الملف غير مشفّر: من يفتحه يقرأ بياناتك.»;
* the settings screen says where snapshots live and who can read them, and
  distinguishes the app's own copies from a file the user shares;
* the app asks for **no storage permission** and takes its portable copies out
  through the system picker and share sheet, so a copy only exists where the user
  put it.

## What would change this decision

Not a preference — one of these:

1. **A regulatory or contractual requirement** to encrypt financial records at
   rest. Then B (with a documented, tested recovery story) becomes mandatory, and
   the "lost password" risk has to be accepted explicitly in writing.
2. **A second, non-portable artefact** with a different job: a local cache the
   app restores by itself after a reinstall on the *same* device, where C would
   be the right tool and the recovery dead end would not matter (the user's own
   portable copy is still the backup).
3. **Evidence that users share backups to places they do not trust** and would
   rather type a password than accept that. That is a product decision, and it
   should be made by asking them.

Until one of those happens, the checkable properties stay: the format is
self-describing, the checksum catches damage, the file is portable to any device,
and no user can lose their ledger to a password they do not have.

## What is deliberately not done

* **No password, and no key material, in the file, the logs or the source.** The
  app has no secrets of its own to lose.
* **No obfuscation in place of encryption.** Base64 or a fixed XOR is not
  encryption; it would only make the file look protected while the app's own
  message said it was.
* **No device-bound state in a portable file.** Lock state and biometric
  enrolment live in the keystore and are never restored — see
  `lib/data/backup/backup_codec.dart`, where the two lock switches and the
  "summary sent" marker are excluded on purpose.

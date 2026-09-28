# Performance gate

**Status:** official, separate from the unit suite.
**Datasets:** 500 people / 2,500 records / 10,000 payments, and 1,000 / 10,000 / 40,000.
**Last measured:** 2026-09-26, on the host below and on a Galaxy S24 Ultra.

## Why it is not part of `flutter test`

The gate seeds sixty-one thousand rows and then writes and restores a twelve-megabyte
file. One run takes minutes, and the figures depend on the machine — so as a unit test
it would be both slow and flaky, and the failure it produced would say "this laptop is
busy" rather than "the app regressed". It is therefore a gate that runs on purpose, and
the unit suite asserts *correctness* while this asserts *cost*.

What the suite does cover is the regression that matters for correctness: the paging
guard in `TableReader` falls back to a full read when the pages do not add up, so a
schema change that broke the fast path would fail a unit test, not silently produce a
short snapshot.

## Commands

```bash
# phases, stalls and memory at the phone-sized dataset
flutter test test/tool/backup_phase_profile_test.dart --plain-name 'phase split'

# the same at the largest dataset the app is expected to meet
flutter test test/tool/backup_phase_profile_test.dart --plain-name 'phase split' \
  --dart-define=people=1000 --dart-define=debts=10

# how long the frame thread is held, one-shot versus paged
flutter test test/tool/backup_phase_profile_test.dart --plain-name 'longest stall' \
  --dart-define=people=1000 --dart-define=debts=10

# the complexity curve: linear, or worse
flutter test test/tool/backup_phase_profile_test.dart --plain-name 'complexity curve'

# frames during a real backup and restore, on a device
flutter test integration_test/backup_audit_on_device_test.dart -d <device> \
  --plain-name 'app survives'
```

## Measured baseline

| Operation | 500/2,500/10,000 | 1,000/10,000/40,000 |
| --- | ---: | ---: |
| create (host, debug) | 3.9–4.8 s | **8.6 s** |
| restore, replace into an empty ledger | 6.5 s | **11.0 s** |
| restore with the safety snapshot | 9.7 s | **14.9 s** |
| longest synchronous stall in the read | 117–190 ms | **191 ms** |
| same, before paging | 812 ms | 3,111 ms |
| peak RSS | 484 MB after create | **589 MB** (was 666 MB) |

Device (S24 Ultra, Android 16, debug, 500/2,500/10,000): backup 769 ms with **12 frames**
(build p90 10.7 ms); restore 1,022 ms with **12 frames** (build p90 2.3 ms, no frame over
16.7 ms, worst gap 383 ms).

## Expected range and regression threshold

The figures above are the baseline. A run is a **regression** if any of these holds:

| Signal | Threshold | Why this number |
| --- | --- | --- |
| create, 40,000 payments | > 13 s (baseline 8.6 s + 50%) | the host varies ±20% run to run; 50% is outside that |
| restore into an empty ledger | > 16.5 s (baseline 11.0 s + 50%) | same |
| worst stall, paged read | > 600 ms (baseline 191 ms) | a page of 500 rows should never cost a third of a second |
| frames over 16.7 ms during a restore, on a device | > 2 (baseline 0) | the restore is expected to be smooth |

Absolute wall times are reported, never asserted: a threshold pinned in a test file
measures the machine. The gate is read by a person, against the numbers above.

## Interpretation

* **Stall is the figure that matters for the product.** Wall time says how long the user
  waits; the stall says whether the screen is frozen. They were reduced together by
  paging, but they are not the same number and a change may improve one and not the other.
* **A residual stall of ~200 ms per phase is expected and acceptable**: it is one page of
  row mapping. Anything at or above the threshold means a phase went back to reading or
  writing in one piece.
* **Memory grows with the file, not with the operation count.** The peak is the payload
  map plus its canonical bytes plus the file's bytes; if it climbs across repeated
  operations, that is a leak and not this gate's baseline.

## Known gaps in this gate

* The host is the developer machine, not a fixed runner, so absolute numbers are
  indicative; the ratios are what transfer.
* A six-cycle leak run is **not** part of it (not written yet).
* The device column needs a phone attached; there is no CI runner with one.

/// The steps a backup and a restore really perform, in the order they happen.
///
/// This file exists because a progress indicator has only two honest options:
/// name the work that is actually happening, or say nothing. A percentage that
/// is not tied to anything is worse than a spinner — it claims knowledge the app
/// does not have.
///
/// So these enumerations are not a UI invention laid over the pipeline: each
/// value is emitted by the service at the moment that step's work starts, and
/// the numbers they carry are the real position in the real sequence.
library;

/// The work a snapshot does, in order.
enum BackupStep {
  /// Reading every table inside one transaction.
  reading,

  /// Sorting the rows and building the payload.
  building,

  /// Hashing the payload.
  hashing,

  /// Writing the temporary file, flushing it, renaming it into place.
  writing,

  /// Reading the file back and proving it is what was meant to be written.
  verifying,

  /// Dropping the snapshots that aged out.
  retaining,
}

/// The work a restore does, in order.
///
/// The first four belong to *inspecting* a file — which is the first half of a
/// restore, and is what the app is doing while the user waits after choosing
/// one. The rest belong to applying it.
enum RestoreStep {
  /// Reading the file's bytes.
  reading,

  /// Turning the text into maps.
  decoding,

  /// Checking the checksum over the payload.
  checking,

  /// Structural, referential and financial validation.
  validating,

  /// Deciding, row by row, what will be written.
  planning,

  /// The safety copy of what is on the device now.
  snapshot,

  /// The single database transaction.
  writing,

  /// Checking the state the transaction is about to commit.
  verifying,

  /// Materialising periods and recomputing notifications.
  rebuilding,
}

/// Reports a step, then lets the event loop turn.
///
/// A step is only *visible* if a frame is drawn between one heavy phase and the
/// next, and a phase such as validation is one synchronous stretch of work with
/// no await inside it. Yielding here is what turns the report into something the
/// user sees rather than four labels that appear together at the end.
///
/// Nothing happens when no listener is attached — which is every test, and the
/// automatic snapshots the coordinator takes — so a caller that does not care
/// about progress pays neither the callback nor the yield.
Future<void> reportStep<T>(void Function(T step)? onStep, T step) async {
  if (onStep == null) return;
  onStep(step);
  await Future<void>.delayed(Duration.zero);
}

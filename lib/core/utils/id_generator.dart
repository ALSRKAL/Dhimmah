import 'package:uuid/uuid.dart';

/// Single source of identifiers for every record in the app.
///
/// Ids are generated on the client so a record created offline already has its
/// final identity — which is what will let a future sync layer upload it without
/// having to rewrite references to it.
const Uuid _uuid = Uuid();

String newId() => _uuid.v4();

/// Shared immutable DTOs for the Zuum API (`docs/03_api_contract.md`).
///
/// Hand-written `fromJson`/`toJson` on purpose: no codegen dependency,
/// explicit contract, easy to diff against the OpenAPI spec.
library;

export 'booking.dart';
export 'fare.dart';
export 'location.dart';
export 'notification.dart';
export 'paged.dart';
export 'promo.dart';
export 'service_category.dart';
export 'session.dart';
export 'support.dart';
export 'user.dart';
export 'wallet.dart';

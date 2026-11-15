/// Tolerant numeric readers for DRF payloads.
///
/// Django `DecimalField`s are serialized as strings, while the same fields are
/// numbers in the mock adapters. Accept both without weakening the contract.
double? jsonDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? jsonInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

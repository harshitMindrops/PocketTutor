abstract final class TimestampParser {
  static int parse(dynamic value, {int? fallback}) {
    if (value == null) {
      return fallback ?? DateTime.now().millisecondsSinceEpoch;
    }
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ??
        (fallback ?? DateTime.now().millisecondsSinceEpoch);
  }
}

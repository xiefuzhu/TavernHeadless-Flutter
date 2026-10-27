String readString(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

String? readNullableString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

int readInt(Object? value, [int fallback = 0]) {
  return value is int ? value : fallback;
}

int? readNullableInt(Object? value) {
  return value is int ? value : null;
}

bool readBool(Object? value, [bool fallback = false]) {
  return value is bool ? value : fallback;
}

Map<String, Object?> readMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, Object?>> readObjectList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<Map>().map(readMap).toList(growable: false);
}

List<String> readStringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList(growable: false);
}

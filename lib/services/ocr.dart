import 'dart:math';

class ScanResult {
  const ScanResult({required this.seriesName, required this.slot});
  final String seriesName;
  final int slot;

  static ScanResult? tryParse(String text) {
    final lines = text
        .replaceAll('／', '/')
        .replaceAll('⁄', '/')
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final piecePattern = RegExp(
      r'(?<!\d)([1-4Il|])\s*(?:[/|\\]|of)\s*[4A](?!\d)',
      caseSensitive: false,
    );
    for (var index = 0; index < lines.length; index++) {
      final match = piecePattern.firstMatch(lines[index]);
      if (match == null) continue;
      final rawSlot = match.group(1)!;
      final slot = int.tryParse(rawSlot) ?? 1;
      final sameLine = _cleanName(lines[index].substring(0, match.start));
      if (sameLine.isNotEmpty) {
        return ScanResult(seriesName: sameLine, slot: slot);
      }
      for (var previous = index - 1; previous >= 0; previous--) {
        final name = _cleanName(lines[previous]);
        if (name.isNotEmpty) return ScanResult(seriesName: name, slot: slot);
      }
      if (index + 1 < lines.length) {
        final next = _cleanName(lines[index + 1]);
        if (next.isNotEmpty) return ScanResult(seriesName: next, slot: slot);
      }
    }
    return null;
  }

  static String _cleanName(String value) {
    var name = value
        .replaceAll(RegExp(r'\bclipper\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*[-–—:]+|[-–—:\s]+$'), '')
        .trim();
    if (RegExp(
      r'^(made\s+in|www\.|https?://|ref[.:\s]|[\d\W]+$)',
      caseSensitive: false,
    ).hasMatch(name)) {
      return '';
    }
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    return name.length > 120 ? name.substring(0, 120).trim() : name;
  }
}

String normalizeSeriesName(String value) {
  final folded = value
      .replaceAll('İ', 'I')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  return folded
      .split(RegExp(r'\s+'))
      .where(
        (t) =>
            t.isNotEmpty &&
            !const {
              'clipper',
              'series',
              'serie',
              'serisi',
              'collection',
            }.contains(t),
      )
      .join(' ');
}

double seriesNameScore(String normalizedQuery, String normalizedName) {
  if (normalizedQuery.isEmpty || normalizedName.isEmpty) return 0;
  if (normalizedQuery == normalizedName) return 1;
  final query = normalizedQuery.length > 160
      ? normalizedQuery.substring(0, 160)
      : normalizedQuery;
  final name = normalizedName.length > 160
      ? normalizedName.substring(0, 160)
      : normalizedName;
  final a = query.split(' ').toSet();
  final b = name.split(' ').toSet();
  final dice = 2 * a.intersection(b).length / (a.length + b.length);
  var previous = List<int>.generate(name.length + 1, (i) => i);
  for (var i = 1; i <= query.length; i++) {
    final current = List<int>.filled(name.length + 1, 0)..[0] = i;
    for (var j = 1; j <= name.length; j++) {
      current[j] = min(
        min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] +
            (query.codeUnitAt(i - 1) == name.codeUnitAt(j - 1) ? 0 : 1),
      );
    }
    previous = current;
  }
  final similarity = 1 - previous.last / max(query.length, name.length);
  final numbers = RegExp(r'\d+');
  final queryNumbers = numbers.allMatches(query).map((m) => m.group(0)).toSet();
  final nameNumbers = numbers.allMatches(name).map((m) => m.group(0)).toSet();
  final conflictingNumbers =
      queryNumbers.isNotEmpty &&
      nameNumbers.isNotEmpty &&
      (queryNumbers.difference(nameNumbers).isNotEmpty ||
          nameNumbers.difference(queryNumbers).isNotEmpty);
  return (0.55 * similarity + 0.45 * dice) * (conflictingNumbers ? 0.35 : 1);
}

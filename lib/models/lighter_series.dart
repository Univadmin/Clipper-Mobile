class LighterSeries {
  LighterSeries({
    required this.id,
    required this.name,
    required this.seriesNumber,
    Set<int>? ownedPieces,
  }) : ownedPieces = Set<int>.unmodifiable(
         (ownedPieces ?? const <int>{}).where((slot) => slot >= 1 && slot <= 4),
       ),
       assert(seriesNumber > 0);

  final String id;
  final String name;
  final int seriesNumber;
  final Set<int> ownedPieces;

  int get ownedCount => ownedPieces.length;
  bool get isComplete => ownedPieces.length == 4;
  double get completionRatio => ownedPieces.length / 4;

  bool hasPiece(int slot) => ownedPieces.contains(slot);

  List<int> get missingPieces => List<int>.generate(
    4,
    (index) => index + 1,
  ).where((slot) => !ownedPieces.contains(slot)).toList();

  LighterSeries copyWith({
    String? name,
    int? seriesNumber,
    Set<int>? ownedPieces,
  }) {
    return LighterSeries(
      id: id,
      name: name ?? this.name,
      seriesNumber: seriesNumber ?? this.seriesNumber,
      ownedPieces: ownedPieces ?? this.ownedPieces,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'seriesNumber': seriesNumber,
      'ownedPieces': ownedPieces.toList()..sort(),
    };
  }

  factory LighterSeries.fromJson(Map<String, dynamic> json) {
    final number = json['seriesNumber'];
    if (number is! int ||
        number <= 0 ||
        json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty) {
      throw const FormatException('Geçersiz seri alanları');
    }
    return LighterSeries(
      id: json['id'] as String,
      name: json['name'] as String,
      seriesNumber: json['seriesNumber'] as int,
      ownedPieces:
          (json['ownedPieces'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toSet() ??
          {},
    );
  }
}

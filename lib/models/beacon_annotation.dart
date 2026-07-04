class BeaconAnnotation {
  BeaconAnnotation({
    required this.beaconId,
    this.note = '',
    this.imagePath,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String beaconId;
  final String note;
  final String? imagePath;
  final DateTime updatedAt;

  bool get hasContent => note.trim().isNotEmpty || imagePath != null;

  BeaconAnnotation copyWith({
    String? note,
    Object? imagePath = _unset,
    DateTime? updatedAt,
  }) {
    return BeaconAnnotation(
      beaconId: beaconId,
      note: note ?? this.note,
      imagePath: imagePath == _unset ? this.imagePath : imagePath as String?,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'beaconId': beaconId,
      'note': note,
      'imagePath': imagePath,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BeaconAnnotation.fromJson(Map<String, Object?> json) {
    return BeaconAnnotation(
      beaconId: json['beaconId'] as String,
      note: json['note'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

const Object _unset = Object();

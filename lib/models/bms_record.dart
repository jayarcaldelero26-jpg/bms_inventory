class BMSRecord {
  final String id; // firestore id
  final String type; // species | habitat | threat | human
  final String assessmentYear;
  final String assessmentPeriod;
  final String station;

  /// dynamic fields (species, habitat, threat, human)
  final Map<String, dynamic> data;

  final double? latitude;
  final double? longitude;

  /// Firebase Storage photo URL
  final String photoUrl;

  final DateTime createdAt;

  BMSRecord({
    required this.id,
    required this.type,
    required this.assessmentYear,
    required this.assessmentPeriod,
    required this.station,
    required this.data,
    required this.photoUrl,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  /// Save to Firestore
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'assessmentYear': assessmentYear,
      'assessmentPeriod': assessmentPeriod,
      'station': station,
      'data': data,
      'latitude': latitude,
      'longitude': longitude,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Read from Firestore
  factory BMSRecord.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return BMSRecord(
      id: id,
      type: map['type'],
      assessmentYear: map['assessmentYear'],
      assessmentPeriod: map['assessmentPeriod'],
      station: map['station'],
      data: Map<String, dynamic>.from(map['data']),
      latitude: map['latitude'],
      longitude: map['longitude'],
      photoUrl: map['photoUrl'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

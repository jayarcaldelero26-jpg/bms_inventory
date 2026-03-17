class OfflineLog {
  final String localId;
  final String type; // species | habitat | threat | human_activity
  final Map<String, dynamic> data;
  String status; // pending | synced | error
  final DateTime createdAt;
  DateTime? syncedAt;

  OfflineLog({
    required this.localId,
    required this.type,
    required this.data,
    this.status = 'pending',
    required this.createdAt,
    this.syncedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'type': type,
      'data': data,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
    };
  }

  factory OfflineLog.fromMap(Map map) {
    return OfflineLog(
      localId: map['localId'],
      type: map['type'],
      data: Map<String, dynamic>.from(map['data']),
      status: map['status'],
      createdAt: DateTime.parse(map['createdAt']),
      syncedAt:
          map['syncedAt'] != null ? DateTime.parse(map['syncedAt']) : null,
    );
  }
}

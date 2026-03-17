import '../enums/accuracy_mode.dart';

class TransectState {
  String? activeTransectId;
  DateTime? startTime;
  DateTime? endTime;

  double currentLat = 0;
  double currentLng = 0;
  double arrowLat = 0;
  double arrowLng = 0;

  double distanceMeters = 0;
  double minElevation = 99999;
  double maxElevation = 0;

  double gpsBearing = 0;
  double compassHeading = 0;

  AccuracyMode accuracyMode = AccuracyMode.forest;
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cds_smart_mobile/transect/legacy/transect_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('bms_inventory_test_');
    Hive.init(hiveDir.path);
    await Hive.openBox('transects');
    await Hive.openBox('transect_points');
  });

  tearDown(() async {
    final service = TransectService();
    service.activeTransectId = null;
    service.transectStart = null;
    service.transectEnd = null;
    service.weather = null;
    service.bmsLocation = null;
    service.assessmentPeriod = null;
    service.assessmentYear = null;
    service.distanceMeters = 0;
    service.minElevation = 99999;
    service.maxElevation = 0;
    service.startLat = 0;
    service.startLng = 0;
    service.endLat = 0;
    service.endLng = 0;
    service.currentLat = 0;
    service.currentLng = 0;
    service.currentElevation = 0;
    service.observers = [];
    service.ecosystemType = null;
    service.speciesGroup = 'Flora';

    await Hive.deleteBoxFromDisk('transects');
    await Hive.deleteBoxFromDisk('transect_points');
    await hiveDir.delete(recursive: true);
  });

  test('restoreActiveTransect recovers metadata required by save flows', () async {
    final transects = Hive.box('transects');
    final points = Hive.box('transect_points');

    await transects.put('active_transect_id', 'transect-1');
    await transects.put('active_transect_state', {
      'transectId': 'transect-1',
      'transectStart': '2026-03-17T08:00:00.000',
      'weather': 'Cloudy',
      'bmsLocation': 'San Isidro',
      'assessmentPeriod': '1st Assessment',
      'assessmentYear': 2026,
      'selectedTransectId': 'transect-1',
    });

    await points.add({
      'transectId': 'transect-1',
      'lat': 7.1000,
      'lng': 125.1000,
      'alt': 100.0,
      'time': '2026-03-17T08:00:00.000',
    });
    await points.add({
      'transectId': 'transect-1',
      'lat': 7.1005,
      'lng': 125.1005,
      'alt': 110.0,
      'time': '2026-03-17T08:05:00.000',
    });

    final service = TransectService();
    await service.restoreActiveTransect(startSensors: false);

    expect(service.activeTransectId, 'transect-1');
    expect(service.bmsLocation, 'San Isidro');
    expect(service.assessmentPeriod, '1st Assessment');
    expect(service.assessmentYear, 2026);
    expect(
      service.transectStart?.toIso8601String(),
      '2026-03-17T08:00:00.000',
    );
    expect(service.currentLat, 7.1005);
    expect(service.currentLng, 125.1005);
    expect(service.distanceMeters, greaterThan(0));
    expect(service.missingRecordContextFields, isEmpty);
  });
}

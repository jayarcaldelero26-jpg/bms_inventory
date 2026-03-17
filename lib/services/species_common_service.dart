import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> loadCommonNamesOnce() async {
  final box = Hive.box('species_common');

  await box.clear();

  final jsonStr = await rootBundle.loadString(
    'assets/data/species_common.json',
  );

  final Map<String, dynamic> data = jsonDecode(jsonStr);

  data.forEach((scientificName, commonName) {
    box.put(scientificName, commonName);
  });
}

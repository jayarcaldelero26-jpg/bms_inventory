import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> loadSpeciesOnce() async {
  final box = await Hive.openBox('species_master'); // ✅ MUST BE openBox

  if (box.isNotEmpty) return;

  final jsonStr = await rootBundle.loadString(
    'assets/data/hamiguitan_species_master.json',
  );

  final List list = jsonDecode(jsonStr);
  for (final item in list) {
    await box.add(item);
  }
}

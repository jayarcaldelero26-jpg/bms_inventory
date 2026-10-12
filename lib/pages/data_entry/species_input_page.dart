import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:cds_smart_mobile/widgets/species_search_modal.dart';
import '../../pagev2/species/widgets/species_save_button.dart';
import '../../services/local_photo_service.dart';
import '../../widgets/flat_card.dart';
import '../../transect/legacy/transect_service.dart';

//////////////////////////////////////////////////////////////
///                 SPECIES INPUT PAGE                    ///
//////////////////////////////////////////////////////////////

class SpeciesInputPage extends StatefulWidget {
  const SpeciesInputPage({super.key});

  @override
  State<SpeciesInputPage> createState() => _SpeciesInputPageState();
}

class _SpeciesInputPageState extends State<SpeciesInputPage> {
  // ================= COMMON AUTOCOMPLETE =================
  OverlayEntry? _commonOverlay;
  final LayerLink _commonLink = LayerLink();
  List<String> commonSuggestions = [];
  final List<String> uploadedUrls = [];
  final List<String> localPaths = [];
  // ================= SCIENTIFIC AUTOCOMPLETE =================
  OverlayEntry? _scientificOverlay;
  final LayerLink _scientificLink = LayerLink();
  List<String> scientificSuggestions = [];
  late final List<String> _scientificCache;
  final FocusNode scientificFocus = FocusNode();
  final FocusNode commonFocus = FocusNode();

  // ================= OPTIONS =================
  final stations = [
    'Station 0',
    'Station 1',
    'Station 2',
    'Station 3',
    'Station 4',
    'Station 5',
    'Station 6',
    'Station 7',
    'Station 8',
  ];
  final floraStatuses = [
    'Not observed',
    'Flowering',
    'Fruiting',
    'Senescence',
    'Withered pitcher',
  ];
  final floraTypes = [
    'Tree',
    'Shrub',
    'Herb',
    'Orchid',
    'Fern',
    'Carnivorous plant',
    'Grass',
    'Others',
  ];
  final faunaTypes = ['Terrestrial', 'Avian', 'Aquatic'];

  final detectionTypes = [
    'Seen',
    'Heard',
    'Tracks',
    'Droppings',
    'Nest',
    'Camera trap',
    'Dead specimen',
  ];

  // ================= STATE =================
  Set<String> selectedFloraStatuses = {};
  String station = '';
  String category = '';
  String floraType = '';
  String faunaType = '';
  String conservationStatus = '';
  String lifeStage = '';
  String sex = '';
  String biogeographicStatus = '';
  String detectionType = '';

  String scientificName = '';
  String? countValue;

  double? latitude;
  double? longitude;
  double? accuracy;

  // ✅ ADDED ONLY
  double? elevation;
  DateTime? observedAt;
  bool isProminent = false;
  bool gettingGps = true;
  bool hasGpsFix = false;
  String gpsStatus = 'Searching GPS…';

  // ================= ADDED OBSERVATION =================
  String observationMethod = '';
  String habitatType = '';
  String observerName = '';

  // ================= PHOTOS =================
  final List<String> localPhotoPaths = [];
  bool _savingPhoto = false;

  // ================= CONTROLLERS =================
  final scientificCtrl = TextEditingController();
  final commonCtrl = TextEditingController();
  final remarksCtrl = TextEditingController();
  final behaviorCtrl = TextEditingController();
  final countCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getLocation();

    scientificFocus.addListener(() {
      if (!scientificFocus.hasFocus) {
        _scientificOverlay?.remove();
        _scientificOverlay = null;
      }
    });

    commonFocus.addListener(() {
      if (!commonFocus.hasFocus) {
        _commonOverlay?.remove();
        _commonOverlay = null;
      }
    });

    final box = Hive.box('species_master');
    _scientificCache = box.values
        .whereType<Map>()
        .map((e) => (e['scientificName'] ?? '').toString())
        .toSet()
        .toList();
  }

  @override
  void dispose() {
    scientificFocus.dispose();
    commonFocus.dispose();
    _commonOverlay?.remove();
    _scientificOverlay?.remove();
    scientificCtrl.dispose();
    commonCtrl.dispose();
    remarksCtrl.dispose();
    behaviorCtrl.dispose();
    countCtrl.dispose();
    super.dispose();
  }

  // ================= COMMON SEARCH =================
  void searchCommonNames(String query) {
    final box = Hive.box('species_common');

    if (query.isEmpty) {
      setState(() => commonSuggestions.clear());
      _commonOverlay?.remove();
      _commonOverlay = null;
      return;
    }

    final results = box.values
        .whereType<String>()
        .where((n) => n.toLowerCase().contains(query.toLowerCase()))
        .take(10)
        .toList();

    setState(() => commonSuggestions = results);

    if (results.isNotEmpty) {
      _showCommonOverlay();
    } else {
      _commonOverlay?.remove();
      _commonOverlay = null;
    }
  }

  void _showCommonOverlay() {
    _commonOverlay?.remove();
    final overlay = Overlay.of(context);

    _commonOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _commonLink,
          offset: const Offset(0, -220),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: commonSuggestions.map((name) {
                return ListTile(
                  title: Text(name),
                  onTap: () {
                    commonCtrl.text = name;
                    _commonOverlay?.remove();
                    _commonOverlay = null;
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_commonOverlay!);
  }

  // ================= SCIENTIFIC SEARCH =================
  void searchScientificNames(String query) {
    if (query.isEmpty) {
      scientificSuggestions.clear();
      _scientificOverlay?.remove();
      _scientificOverlay = null;
      return;
    }

    final results = _scientificCache
        .where((n) => n.toLowerCase().contains(query.toLowerCase()))
        .take(10)
        .toList();

    setState(() => scientificSuggestions = results);

    if (results.isNotEmpty) {
      _showScientificOverlay();
    } else {
      _scientificOverlay?.remove();
      _scientificOverlay = null;
    }
  }

  void _showScientificOverlay() {
    _scientificOverlay?.remove();
    final overlay = Overlay.of(context);

    _scientificOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _scientificLink,
          offset: const Offset(0, -220),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: scientificSuggestions.map((name) {
                final clean = name.split(',').first;
                return ListTile(
                  title: Text(
                    clean,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    scientificCtrl.text = clean;
                    scientificName = clean;
                    _scientificOverlay?.remove();
                    _scientificOverlay = null;
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_scientificOverlay!);
  }

  // ================= GPS =================
  Future<void> _getLocation() async {
    setState(() {
      gettingGps = true;
      gpsStatus = 'Searching GPS…';
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw 'Location disabled';

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw 'Permission denied';
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;
      setState(() {
        latitude = pos.latitude;
        longitude = pos.longitude;
        accuracy = pos.accuracy;

        // ✅ ADDED ONLY
        elevation = pos.altitude;
        observedAt = DateTime.now();

        hasGpsFix = true;
        gpsStatus = 'GPS Locked';
        gettingGps = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        hasGpsFix = false;
        gpsStatus = 'GPS Failed';
        gettingGps = false;
      });
    }
  }

  // ================= PHOTO =================
  Future<void> _addPhoto() async {
    if (_savingPhoto) return;

    setState(() => _savingPhoto = true);

    try {
      final path = await LocalPhotoService.captureAndSave(prefix: 'species');

      if (path == null) {
        throw Exception('Photo capture failed');
      }

      if (!mounted) return;

      setState(() {
        localPhotoPaths.add(path);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo not saved: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingPhoto = false);
      }
    }
  }

  // ================= UI HELPERS =================
  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    hintText: 'Fill $label',
    hintStyle: TextStyle(
      color: Colors.grey.shade500,
      fontStyle: FontStyle.italic,
    ),
    filled: true,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value, // 👈 IMPORTANT
        decoration: _dec(label).copyWith(
          hintText: 'Select $label',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
        items: items
            .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  String _fmtObserved(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final transect = TransectService();

    if (!transect.hasActiveTransect) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4FBF4),
        appBar: AppBar(
          title: const Text('Species Observation'),
          backgroundColor: const Color(0xFF7FBF7F),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.route, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'No Active Transect',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start a transect first before recording species.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text('Species Observation'),
        backgroundColor: const Color(0xFF7FBF7F),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 120,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          /// GPS STATUS
          FlatCard(
            title: 'GPS Status',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// LEFT — GPS INFO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gpsStatus,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      if (hasGpsFix) ...[
                        const SizedBox(height: 6),
                        Text('Lat: ${latitude!.toStringAsFixed(5)}'),
                        Text('Lng: ${longitude!.toStringAsFixed(5)}'),
                        Text('Accuracy: ${accuracy?.toStringAsFixed(1)} m'),
                      ],

                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: gettingGps ? null : _getLocation,
                        icon: const Icon(Icons.gps_fixed),
                        label: const Text('Refresh GPS'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                /// RIGHT — ELEVATION & OBSERVED
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Elevation
                    Row(
                      children: [
                        const Text(
                          'ELEVATION (GPS)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(Icons.terrain, size: 16),
                      ],
                    ),
                    Text(
                      elevation != null
                          ? '${elevation!.toStringAsFixed(2)} m'
                          : '—',
                    ),
                    const SizedBox(height: 12),

                    /// Observed Time
                    Row(
                      children: [
                        const Text(
                          'OBSERVED Date&Time',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(Icons.schedule, size: 16),
                      ],
                    ),
                    Text(observedAt != null ? _fmtObserved(observedAt) : '—'),
                  ],
                ),
              ],
            ),
          ),

          /// ASSESSMENT
          FlatCard(
            title: 'Assessment',
            child: Column(
              children: [
                _dropdown(
                  'Station',
                  station,
                  stations,
                  (v) => setState(() => station = v),
                ),
              ],
            ),
          ),

          /// PHOTO
          FlatCard(
            title: 'Photo Evidence',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...localPhotoPaths.map(
                  (p) => Image.file(
                    File(p),
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
                GestureDetector(
                  onTap: _addPhoto,
                  child: Container(
                    width: 90,
                    height: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green),
                    ),
                    child: _savingPhoto
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Icon(Icons.camera_alt),
                  ),
                ),
              ],
            ),
          ),

          /// IDENTIFICATION
          FlatCard(
            title: 'Identification',
            child: Column(
              children: [
                _dropdown('Category', category, ['Flora', 'Fauna'], (v) {
                  setState(() {
                    category = v;
                    floraType = '';
                    faunaType = '';
                    selectedFloraStatuses.clear();
                  });
                }),

                CompositedTransformTarget(
                  link: _scientificLink,
                  child: TextField(
                    focusNode: scientificFocus,
                    controller: scientificCtrl,
                    decoration: _dec('Scientific Name').copyWith(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.list),
                        tooltip: 'Browse species list',
                        onPressed: () async {
                          if (category.isEmpty) return;

                          final result = await showSpeciesSearchModal(
                            context,
                            category,
                          );

                          if (result != null) {
                            final clean = (result['scientificName'] ?? '')
                                .split(',')
                                .first;
                            scientificCtrl.text = clean;
                            scientificName = clean;
                          }

                          _scientificOverlay?.remove();
                          _scientificOverlay = null;
                        },
                      ),
                    ),
                    onChanged: (v) {
                      scientificName = v;

                      if (v.isEmpty) {
                        _scientificOverlay?.remove();
                        _scientificOverlay = null;
                        return;
                      }

                      searchScientificNames(v);
                    },
                  ),
                ),

                const SizedBox(height: 12),

                CompositedTransformTarget(
                  link: _commonLink,
                  child: TextField(
                    focusNode: commonFocus,
                    controller: commonCtrl,
                    decoration: _dec('Common Name'),
                    onTap: () {
                      // 🔥 KILL SCIENTIFIC OVERLAY WHEN USER TAPS HERE
                      _scientificOverlay?.remove();
                      _scientificOverlay = null;
                    },
                    onChanged: searchCommonNames,
                  ),
                ),
              ],
            ),
          ),

          if (category == 'Flora')
            FlatCard(
              title: 'Flora Status',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: floraStatuses.map((status) {
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(status),
                    value: selectedFloraStatuses.contains(status),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          // 🔒 SPECIAL RULE: Not observed = exclusive
                          if (status == 'Not observed') {
                            selectedFloraStatuses.clear();
                            selectedFloraStatuses.add(status);
                          } else {
                            selectedFloraStatuses.remove('Not observed');
                            selectedFloraStatuses.add(status);
                          }
                        } else {
                          selectedFloraStatuses.remove(status);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),

          FlatCard(
            title: 'Observation Details',
            child: Column(
              children: [
                _dropdown('Habitat Type', habitatType, [
                  'Forest',
                  'Riparian',
                  'Grassland',
                  'Agroforest',
                  'Mangrove',
                  'Coastal',
                  'Pygmy Forest',
                  'Montane Forest',
                  'Ultramafic Forest',
                  'Mossy Forest',
                  'Karst/Limestone',
                  'Open ridge',
                  'Wetland',
                  'Fresh Water/Stream',
                  'Others',
                ], (v) => setState(() => habitatType = v)),
                _dropdown(
                  'Detection Type',
                  detectionType,
                  detectionTypes,
                  (v) => setState(() => detectionType = v),
                ),

                TextField(
                  decoration: _dec('Observer Name'),
                  onChanged: (v) => observerName = v,
                ),
              ],
            ),
          ),

          /// COUNT & NOTES
          FlatCard(
            title: 'Number of Individuals',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🔥 PROMINENT SWITCH
                SwitchListTile(
                  title: const Text('Prominent (abundant / dominant species)'),
                  value: isProminent,
                  onChanged: (v) {
                    setState(() {
                      isProminent = v;
                      if (v) countCtrl.clear(); // clear number if prominent
                    });
                  },
                ),

                /// 🔢 COUNT FIELD (ONLY IF NOT PROMINENT)
                if (!isProminent)
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dec('Enter No. of individuals'),
                  ),

                const SizedBox(height: 12),

                TextField(
                  controller: remarksCtrl,
                  maxLines: 3,
                  decoration: _dec('Remarks'),
                ),
              ],
            ),
          ),

          /// OBSERVATION DETAILS (NEW CARD)

          /// SAVE
          Builder(
            builder: (ctx) {
              final t = TransectService();
              if (!hasGpsFix) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Waiting for GPS fix…',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final dynamic finalCount = isProminent
                  ? 'Prominent'
                  : int.tryParse(countCtrl.text.trim());

              if (observerName.isNotEmpty &&
                  !t.observers.contains(observerName)) {
                t.observers.add(observerName);
              }

              return SpeciesSaveButton(
                scaffoldContext: ctx,

                // 🔥 DIRI JUD IBUTANG ANG GPS CODE
                onBeforeSave: () async {
                  final pos = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.bestForNavigation,
                    timeLimit: const Duration(seconds: 15),
                  );

                  if (pos.accuracy > 30) {
                    throw 'GPS accuracy too low (${pos.accuracy.toStringAsFixed(1)} m).';
                  }

                  return {
                    'latitude': pos.latitude,
                    'longitude': pos.longitude,

                    // 🔥 ELEVATION FIX
                    'elevation_m_asl': pos.altitude,

                    'accuracy': pos.accuracy,
                    'observedAt': DateTime.now().toIso8601String(),
                    'coordinateSource': 'gps',
                  };
                },

                // ✅ PAYLOAD = WALAY GPS
                payload: {
                  'transectId': t.selectedTransectId ?? t.activeTransectId,
                  'bmsLocation': t.bmsLocation,
                  'assessmentPeriod': t.assessmentPeriod,
                  'assessmentYear': t.assessmentYear,

                  'station': station,
                  'category': category,
                  'scientificName': scientificCtrl.text.trim(),
                  'commonName': commonCtrl.text.trim(),

                  'floraType': floraType,
                  'detectionType': detectionType,

                  'habitatType': habitatType,
                  'observerName': observerName,
                  'remarks': remarksCtrl.text,
                  'count': finalCount,

                  'localPhotoPaths': localPhotoPaths,
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

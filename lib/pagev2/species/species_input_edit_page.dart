import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/local_photo_service.dart';
import '../../widgets/flat_card.dart';
import '../../pagev2/species/widgets/species_save_button.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SpeciesInputEditPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> existingData;

  const SpeciesInputEditPage({
    super.key,
    required this.docId,
    required this.existingData,
  });

  @override
  State<SpeciesInputEditPage> createState() => _SpeciesInputEditPageState();
}

class _SpeciesInputEditPageState extends State<SpeciesInputEditPage> {
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

  // ================= STATE =================
  String station = '';
  String category = '';
  String floraType = '';
  String habitatType = '';
  String detectionType = '';
  OverlayEntry? _scientificOverlay;
  final LayerLink _scientificLink = LayerLink();
  List<String> scientificSuggestions = [];
  Set<String> selectedFloraStatuses = {};

  bool isProminent = false;

  double? latitude;
  double? longitude;
  double? elevation;
  String gpsStatus = '—';

  // ================= CONTROLLERS =================
  final scientificCtrl = TextEditingController();
  final commonCtrl = TextEditingController();
  final remarksCtrl = TextEditingController();
  final countCtrl = TextEditingController();
  final observerCtrl = TextEditingController();
  final List<String> photoUrls = [];
  final List<String> localPhotoPaths = [];
  // =========================================================
  // INIT
  // =========================================================
  @override
  void initState() {
    super.initState();
    _loadExisting(widget.existingData);
  }

  @override
  void dispose() {
    _scientificOverlay?.remove();
    scientificCtrl.dispose();
    commonCtrl.dispose();
    remarksCtrl.dispose();
    countCtrl.dispose();
    observerCtrl.dispose();
    super.dispose();
  }

  void _loadExisting(Map<String, dynamic> d) {
    station = d['station'] ?? '';
    category = d['category'] ?? '';
    floraType = d['floraType'] ?? '';
    habitatType = d['habitatType'] ?? '';
    detectionType = d['detectionType'] ?? '';

    observerCtrl.text = d['observerName'] ?? '';
    scientificCtrl.text = d['scientificName'] ?? '';
    commonCtrl.text = d['commonName'] ?? '';
    remarksCtrl.text = d['remarks'] ?? '';

    if (d['floraStatus'] is List) {
      selectedFloraStatuses = Set<String>.from(d['floraStatus']);
    }

    if (d['count'] == 'Prominent') {
      isProminent = true;
    } else if (d['count'] is int) {
      countCtrl.text = d['count'].toString();
    }

    if (d['photoUrls'] is List) {
      photoUrls.addAll(List<String>.from(d['photoUrls']));
    }

    if (d['localPhotoPaths'] is List) {
      localPhotoPaths.addAll(List<String>.from(d['localPhotoPaths']));
    }

    latitude = d['latitude'];
    longitude = d['longitude'];
    elevation = d['elevation_m_asl'];

    gpsStatus = (latitude != null && longitude != null)
        ? 'GPS Loaded'
        : 'No GPS';
  }

  void _searchScientific(String query) {
    if (query.isEmpty) {
      _removeScientificOverlay();
      return;
    }

    final box = Hive.box('species');

    final results = box.values
        .whereType<Map>()
        .map((e) => e['scientificName']?.toString() ?? '')
        .where(
          (name) =>
              name.isNotEmpty &&
              name.toLowerCase().contains(query.toLowerCase()),
        )
        .toSet() // 🔥 REMOVE DUPLICATES
        .take(8)
        .toList();

    if (results.isEmpty) {
      _removeScientificOverlay();
      return;
    }

    scientificSuggestions = results;
    _showScientificOverlay();
  }

  // =========================================================
  // PHOTO
  // =========================================================
  Future<void> _addPhoto() async {
    final path = await LocalPhotoService.captureAndSave(prefix: 'species');
    if (path != null && mounted) {
      setState(() => localPhotoPaths.add(path));
    }
  }

  void _showImageViewer(BuildContext context, String pathOrUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: pathOrUrl.startsWith('http')
                  ? Image.network(pathOrUrl, fit: BoxFit.contain)
                  : Image.file(File(pathOrUrl), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final dynamic finalCount = isProminent
        ? 'Prominent'
        : int.tryParse(countCtrl.text.trim());

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text('Edit Species'),
        backgroundColor: const Color(0xFF7FBF7F),
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 140),
        children: [
          /// ================= GPS (READ-ONLY) =================
          FlatCard(
            title: 'GPS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gpsStatus,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (latitude != null && longitude != null) ...[
                  const SizedBox(height: 6),
                  Text('Lat: ${latitude!.toStringAsFixed(6)}'),
                  Text('Lng: ${longitude!.toStringAsFixed(6)}'),
                  Text('Elevation: ${elevation?.toStringAsFixed(2)} m'),
                ],
              ],
            ),
          ),

          /// ================= PHOTO =================
          FlatCard(
            title: 'Photo Evidence',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                /// 🌐 CLOUD PHOTOS (FROM FIREBASE)
                ...photoUrls.map((url) {
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _showImageViewer(context, url),
                        child: Image.network(
                          url,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => photoUrls.remove(url));
                          },
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                /// 📂 LOCAL PHOTOS (NEWLY ADDED)
                ...localPhotoPaths.map((p) {
                  return Stack(
                    children: [
                      Image.file(
                        File(p),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => localPhotoPaths.remove(p));
                          },
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                /// ➕ ADD PHOTO
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
                    child: const Icon(Icons.camera_alt),
                  ),
                ),
              ],
            ),
          ),

          /// ================= IDENTIFICATION =================
          FlatCard(
            title: 'Identification',
            child: Column(
              children: [
                _dropdown(
                  'Station',
                  station,
                  stations,
                  (v) => setState(() => station = v),
                ),
                _dropdown('Category', category, ['Flora', 'Fauna'], (v) {
                  setState(() {
                    category = v;
                    selectedFloraStatuses.clear(); // 🔥 important
                  });
                }),
                if (category == 'Flora')
                  _dropdown('Flora Type', floraType, [
                    'Tree',
                    'Shrub',
                    'Herb',
                    'Orchid',
                    'Fern',
                    'Carnivorous plant',
                    'Grass',
                    'Others',
                  ], (v) => setState(() => floraType = v)),

                CompositedTransformTarget(
                  link: _scientificLink,
                  child: TextField(
                    controller: scientificCtrl,
                    decoration: _dec('Scientific Name'),
                    onChanged: _searchScientific, // 🔥 HERE
                    onTap: _removeScientificOverlay,
                  ),
                ),

                const SizedBox(height: 10),
                TextField(
                  controller: commonCtrl,
                  decoration: _dec('Common Name'),
                ),
              ],
            ),
          ),

          /// ================= FLORA STATUS =================
          if (category == 'Flora')
            FlatCard(
              title: 'Flora Status',
              child: Column(
                children: floraStatuses.map((s) {
                  return CheckboxListTile(
                    dense: true,
                    title: Text(s),
                    value: selectedFloraStatuses.contains(s),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          if (s == 'Not observed') {
                            selectedFloraStatuses.clear();
                            selectedFloraStatuses.add(s);
                          } else {
                            selectedFloraStatuses.remove('Not observed');
                            selectedFloraStatuses.add(s);
                          }
                        } else {
                          selectedFloraStatuses.remove(s);
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
                  [
                    'Seen',
                    'Heard',
                    'Tracks',
                    'Droppings',
                    'Nest',
                    'Camera trap',
                    'Dead specimen',
                  ],
                  (v) => setState(() => detectionType = v),
                ),

                TextField(
                  controller: observerCtrl,
                  decoration: _dec('Observer Name'),
                  onChanged: (_) {}, // 🔥 para sure rebuild-safe
                ),
              ],
            ),
          ),

          /// ================= COUNT =================
          FlatCard(
            title: 'Number of Individuals',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Prominent'),
                  value: isProminent,
                  onChanged: (v) {
                    setState(() {
                      isProminent = v;
                      if (v) countCtrl.clear();
                    });
                  },
                ),
                if (!isProminent)
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dec('Count'),
                  ),
              ],
            ),
          ),

          /// ================= REMARKS =================
          FlatCard(
            title: 'Remarks',
            child: TextField(
              controller: remarksCtrl,
              maxLines: 3,
              decoration: _dec('Remarks'),
            ),
          ),

          /// ================= SAVE (UPDATE ONLY) =================
          SpeciesSaveButton(
            isEdit: true,
            docId: widget.docId,
            scaffoldContext: context,
            payload: {
              'speciesId': widget.existingData['speciesId'],
              'station': station,
              'category': category,
              'scientificName': scientificCtrl.text.trim(),
              'commonName': commonCtrl.text.trim(),

              'floraType': floraType,
              'floraStatus': selectedFloraStatuses.toList(),

              'habitatType': habitatType,
              'detectionType': detectionType,
              'observerName': observerCtrl.text.trim(),

              'remarks': remarksCtrl.text.trim(),
              'count': finalCount,

              // 🔥 GPS FIELDS (para mu-refresh summary / map)
              'latitude': latitude,
              'longitude': longitude,
              'elevation_m_asl': elevation,
              'photoUrls': photoUrls,
              'localPhotoPaths': localPhotoPaths,
              'baseUpdatedAt': widget.existingData['updatedAt'],
            },

            onBeforeSave: null, // ❌ NO GPS / NO TRANSECT
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================
  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
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
        value: value.isEmpty ? null : value,
        decoration: _dec(label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  void _showScientificOverlay() {
    _scientificOverlay?.remove();

    final overlay = Overlay.of(context);

    _scientificOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _scientificLink,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: scientificSuggestions.map((name) {
                return ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    scientificCtrl.text = name;
                    _removeScientificOverlay();
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

  void _removeScientificOverlay() {
    _scientificOverlay?.remove();
    _scientificOverlay = null;
  }
}

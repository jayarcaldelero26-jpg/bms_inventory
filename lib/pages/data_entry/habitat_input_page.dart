import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../widgets/flat_card.dart';
import '../../services/local_photo_service.dart';
import '../../pagev2/habitat/widgets/habitat_save_button.dart';

//////////////////////////////////////////////////////////////
///                 HABITAT INPUT PAGE                     ///
//////////////////////////////////////////////////////////////

class HabitatInputPage extends StatefulWidget {
  const HabitatInputPage({super.key});

  @override
  State<HabitatInputPage> createState() => _HabitatInputPageState();
}

class _HabitatInputPageState extends State<HabitatInputPage> {
  static const Color kHabitatBrown = Color(0xFFD7B899);

  // ================= OPTIONS =================
  final assessmentPeriods = ['1st Assessment', '2nd Assessment'];

  final stations = [
    'Station 0','Station 1','Station 2','Station 3',
    'Station 4','Station 5','Station 6','Station 7','Station 8'
  ];

  final bmsLocations = ['San Isidro','Governor Generoso','Mati City'];

  final habitatTypes = [
    'Lowland Forest','Montane Forest','Mossy Forest','Ultramafic Forest',
    'Pygmy Forest','Riparian','Grassland','Agroforest','Mangrove',
    'Coastal Forest','Wetland','Freshwater','Karst','Open Ridge','Others'
  ];

  final forestCovers = [
    'Intact','Moderately Disturbed','Heavily Disturbed','Cleared / Open'
  ];

  final canopyCovers = [
    '>75% (Closed)','50–75%','25–50%','<25%','No Canopy'
  ];

  final waterConditions = [
    'Clear','Slightly Turbid','Turbid','Polluted','Dry','Not Applicable'
  ];

  final degradationSigns = [
    'Logging','Kaingin','Charcoal pits','Trail erosion','Garbage',
    'Settlement','Hunting signs','Mining','Fire','None','Others'
  ];

  final habitatConditions = [
    'Intact','Slightly Disturbed','Moderately Disturbed',
    'Heavily Disturbed','Degraded'
  ];

  final vegetationStructures = [
    'Closed Forest','Open Forest','Shrubland','Grassland',
    'Mixed Vegetation','Sparse Vegetation','Bare / None'
  ];

  // ================= STATE =================
  String assessmentPeriod = '';
  String assessmentYear = '';
  String station = '';
  String bmsLocation = '';

  String habitatType = '';
  String forestCover = '';
  String canopyCover = '';
  String waterCondition = '';
  String habitatCondition = '';
  String vegetationStructure = '';

  bool invasivePresent = false;
  List<String> degradationObserved = [];

  String observerName = '';

  double? latitude;
  double? longitude;
  double? accuracy;
  double? elevation;
  DateTime? observedAt;

  bool gettingGps = true;
  bool hasGpsFix = false;
  String gpsStatus = 'Searching GPS…';

  final invasiveCtrl = TextEditingController();
  final remarksCtrl = TextEditingController();

  final List<String> localPhotoPaths = [];
  bool _savingPhoto = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    invasiveCtrl.dispose();
    remarksCtrl.dispose();
    super.dispose();
  }

  // ================= GPS =================
  Future<void> _getLocation() async {
    setState(() {
      gettingGps = true;
      gpsStatus = 'Searching GPS…';
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw 'GPS disabled';

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
    _savingPhoto = true;
    try {
      final path = await LocalPhotoService.captureAndSave(prefix: 'habitat');
      if (path != null && mounted) {
        setState(() => localPhotoPaths.add(path));
      }
    } finally {
      _savingPhoto = false;
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
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
    ),
  );

  Widget _dropdown(String label,String value,List<String> items,ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        isExpanded: true,
        itemHeight: null,
        decoration: _dec(label).copyWith(
            hintText: 'Select $label',
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        items: items.map((e)=>DropdownMenuItem(
          value: e,
          child: Text(e,maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
            ),
          )
        ).toList(),
        onChanged: (v)=>onChanged(v!),
      ),
    );
  }

  String _fmtObserved(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} '
           '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text('Habitat Assessment'),
        backgroundColor: kHabitatBrown,
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 120,
        ),
        children: [

          /// GPS
          FlatCard(
            title: 'GPS Status',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gpsStatus,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
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
                          'OBSERVED Date&Time ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(Icons.schedule, size: 16),
                      ],
                    ),
                    Text(
                      observedAt != null
                          ? _fmtObserved(observedAt)
                          : '—',
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// Assessment
          FlatCard(title: 'Assessment', child: Column(children: [
            _dropdown('Assessment Period', assessmentPeriod, assessmentPeriods,(v)=>setState(()=>assessmentPeriod=v)),
            _dropdown('Assessment Year', assessmentYear,[DateTime.now().year.toString(),(DateTime.now().year-1).toString()],(v)=>setState(()=>assessmentYear=v)),
            _dropdown('Station', station, stations,(v)=>setState(()=>station=v)),
            _dropdown('BMS Location', bmsLocation, bmsLocations,(v)=>setState(()=>bmsLocation=v)),
          ])),

          /// Photos
          FlatCard(title:'Photo Documentation',child:Wrap(
            spacing:8,runSpacing:8,
            children:[
              ...localPhotoPaths.map((p)=>Image.file(File(p),width:90,height:90,fit:BoxFit.cover)),
              GestureDetector(
                onTap:_addPhoto,
                child:Container(
                  width:90,height:90,
                  decoration:BoxDecoration(border:Border.all(color:kHabitatBrown),borderRadius:BorderRadius.circular(10)),
                  child:_savingPhoto
                  ?const CircularProgressIndicator()
                  :const Icon(Icons.camera_alt),
                ),
              )
            ],
          )),

          /// Habitat Details
          FlatCard(title:'Habitat Details',child:Column(children:[
            _dropdown('Habitat Type',habitatType,habitatTypes,(v)=>setState(()=>habitatType=v)),
            _dropdown('Habitat Condition',habitatCondition,habitatConditions,(v)=>setState(()=>habitatCondition=v)),
            _dropdown('Vegetation Structure',vegetationStructure,vegetationStructures,(v)=>setState(()=>vegetationStructure=v)),
            _dropdown('Forest Cover',forestCover,forestCovers,(v)=>setState(()=>forestCover=v)),
            _dropdown('Canopy Cover',canopyCover,canopyCovers,(v)=>setState(()=>canopyCover=v)),
            _dropdown('Water Condition',waterCondition,waterConditions,(v)=>setState(()=>waterCondition=v)),
          ])),

          /// Degradation
          FlatCard(title:'Degradation Signs',child:Wrap(
            spacing:8,runSpacing:8,
            children:degradationSigns.map((e){
              final s = degradationObserved.contains(e);
              return FilterChip(
                label:Text(e),
                selected:s,
                selectedColor:kHabitatBrown.withOpacity(0.25),
                onSelected:(v)=>setState(()=>v?degradationObserved.add(e):degradationObserved.remove(e)),
              );
            }).toList(),
          )),

          /// Invasive
          FlatCard(title:'Invasive Species',child:Column(children:[
            SwitchListTile(
              title: const Text('Invasive Present'),
              value: invasivePresent,
              activeColor: kHabitatBrown,
              onChanged:(v)=>setState(()=>invasivePresent=v),
            ),
            if(invasivePresent)
              TextField(controller: invasiveCtrl,decoration:_dec('Invasive Species'))
          ])),
          FlatCard(
            title:'Observer',
            child:Column(
              children:[
                    TextField(
                      decoration:_dec('Observer Name'),
                      onChanged:(v)=>observerName=v),
                  ]
        )
      ),

          /// Remarks
          FlatCard(
            title:'Remarks',
            child:Column(
              children:[
            TextField(
              controller:remarksCtrl,
              maxLines:3,
              decoration: _dec('Remarks').copyWith(
                  ),
              ),
          ]
        )
      ),

          /// SAVE
          Builder(builder:(ctx){
            return HabitatSaveButton(
              scaffoldContext: ctx,
              payload:{
                'assessmentPeriod':assessmentPeriod,
                'assessmentYear':assessmentYear,
                'station':station,
                'bmsLocation':bmsLocation,
                'habitatType':habitatType,
                'habitatCondition':habitatCondition,
                'vegetationStructure':vegetationStructure,
                'forestCover':forestCover,
                'canopyCover':canopyCover,
                'waterCondition':waterCondition,
                'invasivePresent':invasivePresent,
                'invasiveDetails':invasiveCtrl.text,
                'degradationObserved':degradationObserved,
                'remarks':remarksCtrl.text,
                'observerName':observerName,
                'latitude':latitude,
                'longitude':longitude,
                'accuracy':accuracy,
                'elevation_m_asl':elevation,
                'observedAt':observedAt?.toIso8601String(),
                'localPhotoPaths':localPhotoPaths,
              },
            );
          })
        ],
      ),
    );
  }
}

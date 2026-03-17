import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../widgets/flat_card.dart';
import '../../services/local_photo_service.dart';
import '../../pagev2/human/widgets/human_save_button.dart';

//////////////////////////////////////////////////////////////
///                HUMAN ACTIVITY INPUT                  ///
//////////////////////////////////////////////////////////////

class HumanActivityInputPage extends StatefulWidget {
  const HumanActivityInputPage({super.key});

  @override
  State<HumanActivityInputPage> createState() =>
      _HumanActivityInputPageState();
}

class _HumanActivityInputPageState extends State<HumanActivityInputPage> {

  static const Color kHumanColor = Color(0xFFFFF3CD);

  // ================= OPTIONS =================
  final assessmentPeriods = ['1st Assessment', '2nd Assessment'];

  final stations = [
    'Station 0','Station 1','Station 2','Station 3',
    'Station 4','Station 5','Station 6','Station 7','Station 8'
  ];

  final bmsLocations = ['San Isidro','Governor Generoso','Mati City'];

  final activityTypes = [
    'Farming / Agriculture',
    'Fishing',
    'Hunting',
    'Logging',
    'Charcoal Making',
    'Settlement / Housing',
    'Tourism Activity',
    'Trail Use / Trekking',
    'Others',
  ];

  final intensities = ['Low', 'Moderate', 'High'];
  final frequencies = ['Occasional', 'Regular', 'Seasonal'];

  final actors = [
    'Local Resident',
    'Outsider',
    'Tourist',
    'Tribal / IP',
    'Business / Commercial',
    'Unknown',
  ];

  final legalStatuses = [
    'Allowed',
    'With Permit',
    'Illegal',
    'Suspected Illegal',
    'Unknown',
  ];

  final scales = [
    'Small (1–2 persons)',
    'Medium (group)',
    'Large (many people / wide area)',
  ];

  final impacts = ['Low', 'Moderate', 'High', 'Severe'];

  final statuses = [
    'Ongoing',
    'Stopped',
    'Seasonal',
    'Abandoned',
  ];

  final actionsTaken = [
    'None',
    'Warning Given',
    'Reported to DENR',
    'Reported to LGU',
    'For Monitoring',
  ];

  // ================= STATE =================
  String assessmentPeriod = '';
  String assessmentYear = '';
  String station = '';
  String bmsLocation = '';

  String activityType = '';
  String intensity = '';
  String frequency = '';

  String actor = '';
  String legalStatus = '';
  String scale = '';
  String impact = '';
  String activityStatus = '';
  String actionTaken = '';

  String observerName = '';

  double? latitude;
  double? longitude;
  double? accuracy;
  double? elevation;
  DateTime? observedAt;

  bool gettingGps = true;
  bool hasGpsFix = false;
  String gpsStatus = 'Searching GPS…';

  final locationCtrl = TextEditingController();
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
    locationCtrl.dispose();
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
      final path = await LocalPhotoService.captureAndSave(prefix: 'human');
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
    hintText: 'Select $label',
    hintStyle: TextStyle(color: Colors.grey.shade500,fontStyle: FontStyle.italic),
    filled: true,
    isDense: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _dropdown(String label,String value,List<String> items,ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        isExpanded: true,
        itemHeight: null,
        decoration: _dec(label),
        items: items.map((e)=>DropdownMenuItem(
          value: e,
          child: Text(e,maxLines: 2,overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (v)=>onChanged(v!),
      ),
    );
  }

  String _fmt(DateTime? d){
    if(d==null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} '
           '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text('Human Activity'),
        backgroundColor: kHumanColor,
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
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gpsStatus,style: const TextStyle(fontWeight: FontWeight.w600)),
                    if(hasGpsFix)...[
                      const SizedBox(height:6),
                      Text('Lat: ${latitude!.toStringAsFixed(5)}'),
                      Text('Lng: ${longitude!.toStringAsFixed(5)}'),
                      Text('Accuracy: ${accuracy?.toStringAsFixed(1)} m'),
                    ],
                    ElevatedButton.icon(
                      onPressed: gettingGps?null:_getLocation,
                      icon: const Icon(Icons.gps_fixed),
                      label: const Text('Refresh GPS'),
                    )
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ELEVATION',style: TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
                    Text(elevation!=null?'${elevation!.toStringAsFixed(1)} m':'—'),
                    const SizedBox(height:12),
                    const Text('OBSERVED',style: TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
                    Text(_fmt(observedAt)),
                  ],
                )
              ],
            ),
          ),

          /// Assessment
          FlatCard(title:'Assessment',child:Column(children:[
            _dropdown('Assessment Period',assessmentPeriod,assessmentPeriods,(v)=>setState(()=>assessmentPeriod=v)),
            _dropdown('Assessment Year',assessmentYear,[DateTime.now().year.toString(),(DateTime.now().year-1).toString()],(v)=>setState(()=>assessmentYear=v)),
            _dropdown('Station',station,stations,(v)=>setState(()=>station=v)),
            _dropdown('BMS Location',bmsLocation,bmsLocations,(v)=>setState(()=>bmsLocation=v)),
          ])),

          /// Photos
          FlatCard(title:'Photo Evidence',child:Wrap(
            spacing:8,runSpacing:8,
            children:[
              ...localPhotoPaths.map((p)=>Image.file(File(p),width:90,height:90,fit:BoxFit.cover)),
              GestureDetector(
                onTap:_addPhoto,
                child:Container(
                  width:90,height:90,
                  decoration:BoxDecoration(border:Border.all(color:Colors.orange),borderRadius:BorderRadius.circular(10)),
                  child:_savingPhoto?const CircularProgressIndicator():const Icon(Icons.camera_alt),
                ),
              )
            ],
          )),

          /// Activity
          FlatCard(title:'Activity Details',child:Column(children:[
            _dropdown('Activity Type',activityType,activityTypes,(v)=>setState(()=>activityType=v)),
            _dropdown('Intensity',intensity,intensities,(v)=>setState(()=>intensity=v)),
            _dropdown('Frequency',frequency,frequencies,(v)=>setState(()=>frequency=v)),
          ])),

          /// Assessment
          FlatCard(title:'Human Assessment',child:Column(children:[
            _dropdown('Actor',actor,actors,(v)=>setState(()=>actor=v)),
            _dropdown('Legal Status',legalStatus,legalStatuses,(v)=>setState(()=>legalStatus=v)),
            _dropdown('Activity Scale',scale,scales,(v)=>setState(()=>scale=v)),
            _dropdown('Impact Level',impact,impacts,(v)=>setState(()=>impact=v)),
            _dropdown('Activity Status',activityStatus,statuses,(v)=>setState(()=>activityStatus=v)),
            _dropdown('Action Taken',actionTaken,actionsTaken,(v)=>setState(()=>actionTaken=v)),
            TextField(decoration:_dec('Observer Name'),onChanged:(v)=>observerName=v),
          ])),

          /// Notes
          FlatCard(title:'Location & Remarks',child:Column(children:[
            TextField(controller:locationCtrl,decoration:_dec('Location Description')),
            const SizedBox(height:12),
            TextField(controller:remarksCtrl,maxLines:3,decoration:_dec('Remarks')),
          ])),

          /// SAVE
          Builder(builder:(ctx){
            return HumanActivitySaveButton(
              scaffoldContext: ctx,
              payload:{
                'assessmentPeriod':assessmentPeriod,
                'assessmentYear':assessmentYear,
                'station':station,
                'bmsLocation':bmsLocation,
                'activityType':activityType,
                'intensity':intensity,
                'frequency':frequency,
                'actor':actor,
                'legalStatus':legalStatus,
                'scale':scale,
                'impact':impact,
                'activityStatus':activityStatus,
                'actionTaken':actionTaken,
                'observerName':observerName,
                'locationDescription':locationCtrl.text,
                'remarks':remarksCtrl.text,
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

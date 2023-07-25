import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors/sensors.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  late final WatchConnectivityBase _watch;

  var _supported = false;
  var _paired = false;
  var _reachable = false;
  var _context = <String, dynamic>{};
  var _receivedContexts = <Map<String, dynamic>>[];
  final _log = <String>[];
  List<List<dynamic>> datalist = [];
  Timer? timer;

  AccelerometerEvent? _accelerometerEvent;
  GyroscopeEvent? _gyroscopeEvent;
  PedestrianStatus? _pedestrianStatus;
  int? _stepCount;
  StreamSubscription<AccelerometerEvent>? _accelerometerStream;
  StreamSubscription<GyroscopeEvent>? _gyroscopeStream;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusStream;
  StreamSubscription<StepCount>? _stepCountStream;

  @override
  void initState() {
    super.initState();
    _watch = WatchConnectivity();
    _watch.messageStream
        .listen((e) => setState(() => _log.add('Received message: $e')));
    initPlatformState();
    initSensors();
    initPedometer();
  }

  @override
  void dispose() {
    _accelerometerStream?.cancel();
    _gyroscopeStream?.cancel();
    _pedestrianStatusStream?.cancel();
    _stepCountStream?.cancel();
    timer?.cancel();
    super.dispose();
  }

  void initPlatformState() async {
    _supported = await _watch.isSupported;
    _paired = await _watch.isPaired;
    _reachable = await _watch.isReachable;
    setState(() {});
  }

  void initSensors() {
    _accelerometerStream =
        accelerometerEvents.listen((AccelerometerEvent event) {
          setState(() {
            _accelerometerEvent = event;
          });
        });

    _gyroscopeStream = gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _gyroscopeEvent = event;
      });
    });
  }

  void initPedometer() {
    _pedestrianStatusStream =
        Pedometer.pedestrianStatusStream.listen((PedestrianStatus event) {
          setState(() {
            _pedestrianStatus = event;
          });
        });

    _stepCountStream = Pedometer.stepCountStream.listen((StepCount event) {
      setState(() {
        _stepCount = event.steps;
      });
    });
  }

  Future<void> _generateCsvFile() async {
    // Request storage permission
    PermissionStatus status = await Permission.storage.request();
    if (!status.isGranted) {
      print('Permission denied');
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
      ].request();
      print(statuses[Permission.storage]);
    }

    final csvData = datalist.map((list) => list.join(',')).join('\n');
    final csvString =
        'accelerometer_x,accelerometer_y,accelerometer_z,gyroscope_x,gyroscope_y,gyroscope_z,step_count,status\n' +
            csvData;

    final dir = await getExternalStorageDirectory();
    final filePath = '${dir?.path}/data.csv';

    final file = File(filePath);
    await file.writeAsString(csvString);

    print('CSV file saved in external storage: $dir');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smartwatch App'),
        centerTitle: true,
        leading: Icon(Icons.watch),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Smartwatch Status',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      buildStatusCard(
                        'Supported',
                        _supported ? 'Yes' : 'No',
                        Icons.check_circle_outline,
                      ),
                      buildStatusCard(
                        'Paired',
                        _paired ? 'Yes' : 'No',
                        Icons.link,
                      ),
                      buildStatusCard(
                        'Reachable',
                        _reachable ? 'Yes' : 'No',
                        Icons.bluetooth,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: initPlatformState,
                    child: Text('Refresh'),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Send Sensor Data',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => toggleBackgroundMessaging(context),
                        child: Text(
                          '${timer == null ? 'Start' : 'Stop'} \n Background Messaging',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _generateCsvFile,
                        child: Text('Generate CSV'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Log',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  buildLogList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildStatusCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 16)),
            SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget buildLogList() {
    return Container(
      height: 200,
      child: ListView.builder(
        reverse: true,
        itemCount: _log.length,
        itemBuilder: (context, index) {
          final log = _log[index];
          return ListTile(
            title: Text(log),
            dense: true,
            visualDensity: VisualDensity(horizontal: 0, vertical: -4),
          );
        },
      ),
    );
  }

  void toggleBackgroundMessaging(BuildContext context) {
    // try {
    //   if (_reachable && _supported && _paired) {
    //     if (timer == null) {
    //       timer =
    //           Timer.periodic(const Duration(seconds: 1), (_) => sendMessage());
    //     } else {
    //       timer?.cancel();
    //       timer = null;
    //     }
    //   }
    // } catch (e) {
    //   print(e);
    //   showDialog(
    //     context: context,
    //     builder: (BuildContext context) {
    //       return AlertDialog(
    //         title: Text('Please connect a device'),
    //         actions: [
    //           ElevatedButton(
    //             onPressed: () => Navigator.pop(context),
    //             child: Text('OK'),
    //           ),
    //         ],
    //       );
    //     },
    //   );
    // }
    if (_reachable && _supported && _paired) {
      if (timer == null) {
        timer =
            Timer.periodic(const Duration(seconds: 1), (_) => sendMessage());
      } else {
        timer?.cancel();
        timer = null;
      }
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Please connect a device'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
    setState(() {});
  }

  void sendMessage() {
    final message = {
      'accelerometer': {
        'x': _accelerometerEvent?.x,
        'y': _accelerometerEvent?.y,
        'z': _accelerometerEvent?.z,
      },
      'gyroscope': {
        'x': _gyroscopeEvent?.x,
        'y': _gyroscopeEvent?.y,
        'z': _gyroscopeEvent?.z,
      },
      'pedometer': {
        'step_count': _stepCount,
        'status': _pedestrianStatus?.status.toString(),
      },
    };
    _watch.sendMessage(message);
    List l = [
      _accelerometerEvent?.x,
      _accelerometerEvent?.y,
      _accelerometerEvent?.z,
      _gyroscopeEvent?.x,
      _gyroscopeEvent?.y,
      _gyroscopeEvent?.z,
      _stepCount,
      _pedestrianStatus?.status.toString(),
    ];
    datalist.add(l);
    setState(() => _log.add('Sent message: $message'));
  }
}

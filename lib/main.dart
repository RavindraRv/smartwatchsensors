import 'package:flutter/material.dart';
import 'package:is_wear/is_wear.dart';

import 'package:wear/wear.dart';

import 'package:wear_os/home.dart';

late final bool isWear;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  isWear = (await IsWear().check()) ?? false;

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: isWear
          ? AmbientMode(
          builder: (context, mode, child) => child!, child: const Home())
          : const Home(),
    );
  }
}

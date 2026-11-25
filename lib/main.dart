import 'dart:io';

import 'package:duonsdk/duonsdk.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android emulator cannot reach the host via localhost — use 10.0.2.2.
/// iOS Simulator can use localhost as-is.
/// Physical devices should set DUON_API_URL to your machine's LAN IP.
String resolveApiUrl(String raw) {
  if (!Platform.isAndroid) return raw;
  return raw
      .replaceAll('://localhost', '://10.0.2.2')
      .replaceAll('://127.0.0.1', '://10.0.2.2');
}

const _rawApiUrl = String.fromEnvironment(
  'DUON_API_URL',
  defaultValue: 'http://localhost:8080',
);
const _apiKey = String.fromEnvironment(
  'DUON_API_KEY',
  defaultValue: 'duon_sk_test_mapviewer_dev000000000001',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DuonSdkDemoApp());
}

class DuonSdkDemoApp extends StatelessWidget {
  const DuonSdkDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuonSDK Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF111827)),
        useMaterial3: true,
      ),
      home: const WayfindingScreen(),
    );
  }
}

class WayfindingScreen extends StatefulWidget {
  const WayfindingScreen({super.key});

  @override
  State<WayfindingScreen> createState() => _WayfindingScreenState();
}

class _WayfindingScreenState extends State<WayfindingScreen>
    with WidgetsBindingObserver {
  List<DuonMall> malls = [];
  DuonMall? selectedMall;
  bool loading = true;
  String? error;
  bool permissionsReady = false;
  bool locationGranted = false;

  String get apiUrl => resolveApiUrl(_rawApiUrl);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadMalls();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DuonWayfinding.endTelemetrySession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      DuonWayfinding.flush();
    }
  }

  /// Situm native setup: request location before DuonMapView mounts.
  /// Android 12+ also needs Bluetooth scan for beacon positioning.
  Future<void> _requestLocation() async {
    try {
      final statuses = await [
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      var granted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
      if (granted &&
          Platform.isIOS &&
          await Geolocator.getLocationAccuracy() ==
              LocationAccuracyStatus.reduced) {
        await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: 'PreciseLocationPurpose',
        );
      }
      if (!mounted) return;
      setState(() {
        locationGranted = granted;
        permissionsReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        locationGranted = false;
        permissionsReady = true;
      });
    }
  }

  Future<void> loadMalls() async {
    setState(() {
      loading = true;
      error = null;
      permissionsReady = false;
    });
    await _requestLocation();
    try {
      DuonWayfinding.initialize(
        apiBaseUrl: apiUrl,
        apiKey: _apiKey,
      );
      final list = await DuonWayfinding.fetchMalls();
      if (!mounted) return;
      setState(() {
        malls = list;
        final previousId = selectedMall?.buildingId;
        if (previousId == null) {
          selectedMall = list.isEmpty ? null : list.first;
        } else {
          final matches =
              list.where((m) => m.buildingId == previousId).toList();
          selectedMall = matches.isNotEmpty
              ? matches.first
              : (list.isEmpty ? null : list.first);
        }
        loading = false;
      });
    } on DuonAuthError {
      _fail("This app's Duon API key is invalid. Please contact support.");
    } on DuonForbiddenError {
      _fail("This app's Duon API key is missing map access.");
    } on DuonConfigError catch (err) {
      _fail(err.message);
    } on DuonNetworkError {
      _fail('Could not reach the map service. Check your connection.');
    } catch (err) {
      _fail(err.toString());
    }
  }

  void _fail(String message) {
    setState(() {
      error = message;
      malls = [];
      selectedMall = null;
      loading = false;
    });
  }

  void _selectMall(DuonMall mall) {
    setState(() {
      selectedMall = mall;
    });
  }

  Widget _map() {
    final mall = selectedMall;
    if (mall == null) {
      return Center(
        child: Text(
          loading ? 'Loading…' : 'Select a mall to view its map',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
        ),
      );
    }

    if (!permissionsReady) {
      return const Center(
        child: Text(
          'Loading…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
        ),
      );
    }

    // Native Situm when location is granted. Otherwise the web viewer,
    // so a denied permission still shows the floor plan.
    return locationGranted
        ? DuonMapView(mall: mall)
        : DuonMapView(url: mall.viewerUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DuonMallSelector(
              malls: malls,
              selectedMall: selectedMall,
              onSelect: _selectMall,
              loading: loading,
              error: error,
              onRetry: loadMalls,
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                child: _map(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

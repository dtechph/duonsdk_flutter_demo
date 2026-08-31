import 'dart:io';

import 'package:duonsdk/duonsdk.dart';
import 'package:flutter/material.dart';
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

  Future<void> _requestLocation() async {
    try {
      final statuses = await [
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      final granted =
          statuses[Permission.locationWhenInUse]?.isGranted ?? false;
      if (!mounted) return;
      setState(() => locationGranted = granted);
    } catch (_) {
      // Tests and hosts without the native plugin still render the web viewer.
    }
  }

  Future<void> loadMalls() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await _requestLocation();
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
      _fail('Invalid API key. Create one in CMS → SDK Keys.');
    } on DuonForbiddenError {
      _fail('API key lacks Map Viewer scope.');
    } on DuonNetworkError catch (err) {
      _fail('Network error: ${err.message}');
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

    // Native Situm needs a runtime location grant. Fall back to the web
    // viewer so kiosk malls and denied-permission Situm malls still render.
    final useNativeSitum =
        locationGranted && mall.mapType == MallMapType.situm;
    return DuonMapView(
      mall: useNativeSitum ? mall : null,
      url: useNativeSitum ? null : mall.viewerUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DuonSDK Flutter Demo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'CMS malls via pub.dev duonsdk',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            DuonMallSelector(
              malls: malls,
              selectedMall: selectedMall,
              onSelect: (mall) => setState(() => selectedMall = mall),
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

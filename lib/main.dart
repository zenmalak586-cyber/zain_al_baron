import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() {
  runApp(const ZainAlBaronApp());
}

class ZainAlBaronApp extends StatelessWidget {
  const ZainAlBaronApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zain Al-Baron',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
        primaryColor: const Color(0xFF00FFCC),
      ),
      home: const NetworkScannerScreen(),
    );
  }
}

class DeviceModel {
  final String ip;
  final String hostName;
  final String timeDetected;

  DeviceModel({
    required this.ip,
    required this.hostName,
    required this.timeDetected,
  });
}

class NetworkScannerScreen extends StatefulWidget {
  const NetworkScannerScreen({super.key});

  @override
  State<NetworkScannerScreen> createState() => _NetworkScannerScreenState();
}

class _NetworkScannerScreenState extends State<NetworkScannerScreen> {
  final List<DeviceModel> _devices = [];
  bool _isScanning = false;
  double _progress = 0.0;
  String _wifiName = "غير متصل";
  String _myIp = "0.0.0.0";

  @override
  void initState() {
    super.initState();
    _getNetworkInfo();
  }

  Future<void> _getNetworkInfo() async {
    final info = NetworkInfo();
    final wifiName = await info.getWifiName();
    final wifiIP = await info.getWifiIP();

    setState(() {
      _wifiName = wifiName?.replaceAll('"', '') ?? "شبكة Wi-Fi";
      _myIp = wifiIP ?? "192.168.1.1";
    });
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    await _getNetworkInfo();
    if (_myIp == "0.0.0.0" || !_myIp.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى الاتصال بشبكة Wi-Fi أولاً")),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
      _progress = 0.0;
    });

    final String subnet = _myIp.substring(0, _myIp.lastIndexOf('.'));
    int scannedCount = 0;

    const int batchSize = 25;
    for (int i = 1; i <= 254; i += batchSize) {
      List<Future<void>> batchFutures = [];

      for (int j = i; j < i + batchSize && j <= 254; j++) {
        String targetIp = '$subnet.$j';
        batchFutures.add(_checkDevice(targetIp).then((_) {
          scannedCount++;
          if (mounted) {
            setState(() {
              _progress = scannedCount / 254;
            });
          }
        }));
      }
      await Future.wait(batchFutures);
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _checkDevice(String ip) async {
    try {
      final result = await Process.run('ping', ['-c', '1', '-W', '1', ip]);
      if (result.exitCode == 0) {
        String host = "جهاز متصل";
        if (ip == _myIp) {
          host = "هذا الجهاز (هاتفك)";
        } else if (ip.endsWith('.1')) {
          host = "الراوتر الرئيسي (Gateway)";
        } else {
          try {
            final address = await InternetAddress(ip).reverse();
            host = address.host;
          } catch (_) {}
        }

        final now = DateTime.now();
        final timeStr =
            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

        if (mounted) {
          setState(() {
            _devices.add(DeviceModel(
              ip: ip,
              hostName: host,
              timeDetected: timeStr,
            ));
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Zain Al-Baron",
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF181825),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF28283D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "الشبكة: $_wifiName",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "عنوان IP الخاص بك: $_myIp",
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  const Icon(Icons.wifi_tethering, color: Color(0xFF00FFCC), size: 32),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: Icon(
                  _isScanning ? Icons.hourglass_top : Icons.radar,
                  color: const Color(0xFF1E1E2E),
                ),
                label: Text(
                  _isScanning ? "جاري فحص الشبكة..." : "فحص الأجهزة المتصلة",
                  style: const TextStyle(
                    color: Color(0xFF1E1E2E),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFCC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            if (_isScanning) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey,
                color: const Color(0xFF00FFCC),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "الأجهزة المكتشفة (${_devices.length}):",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: Text(
                        _isScanning
                            ? "يتم البحث عن الأجهزة..."
                            : "اضغط على زر الفحص لاكتشاف الأجهزة",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return Card(
                          color: const Color(0xFF28283D),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF00FFCC).withOpacity(0.2),
                              child: Icon(
                                device.ip.endsWith('.1')
                                    ? Icons.router
                                    : Icons.smartphone,
                                color: const Color(0xFF00FFCC),
                              ),
                            ),
                            title: Text(
                              device.hostName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("IP: ${device.ip}"),
                            trailing: Text(
                              device.timeDetected,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

import '../ble/ble_service.dart';
import '../data/settings_store.dart';
import 'qr_scan_screen.dart';

/// Spec §1 Device Pairing. Three entry points:
/// - **QR scan** → camera-decoded device identifier (mobile_scanner).
/// - **NFC tap** → device identifier from an NFC tag (flutter_nfc_kit).
/// - **BLE scan** → pick from nearby BLE devices.
class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  final _ble = BleService.instance;
  List<ScanResult> _results = const [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    void soft(Object e) {
      if (mounted) _snack('BLE unavailable: $e');
    }

    _ble.scanResults.listen(
      (r) => mounted ? setState(() => _results = r) : null,
      onError: soft,
    );
    _ble.isScanning.listen(
      (s) => mounted ? setState(() => _scanning = s) : null,
      onError: soft,
    );
  }

  Future<void> _startScan() async {
    if (!await _ble.isSupported) {
      _snack('Bluetooth is not supported on this device.');
      return;
    }
    if (!await _ble.ensurePermissions()) {
      _snack('Bluetooth permissions are required to pair.');
      return;
    }
    try {
      await _ble.startScan();
    } catch (e) {
      _snack('Scan failed: $e');
    }
  }

  Future<void> _scanQr() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (id == null || id.isEmpty) return;
    _registerById(id, source: 'QR');
  }

  Future<void> _readNfc() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      _snack('NFC is only available on mobile.');
      return;
    }
    try {
      final avail = await FlutterNfcKit.nfcAvailability;
      if (avail != NFCAvailability.available) {
        _snack('NFC not available: ${avail.name}');
        return;
      }
      _snack('Hold the phone against the device tag…');
      final tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 15),
        iosAlertMessage: 'Hold the phone against the MediTracker tag',
      );
      await FlutterNfcKit.finish(iosAlertMessage: 'Done');
      _registerById(tag.id, source: 'NFC');
    } catch (e) {
      _snack('NFC read failed: $e');
    }
  }

  void _registerById(String id, {required String source}) {
    final settings = SettingsStore.instance;
    settings.pairedDeviceId = id;
    _snack('Paired via $source · device id $id');
    Navigator.of(context).pop();
  }

  void _pairBle(ScanResult r) {
    final id = r.device.remoteId.str;
    final name = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : r.advertisementData.advName;
    SettingsStore.instance
      ..pairedDeviceId = id
      ..deviceName = name.isEmpty ? 'MediTracker' : name;
    _snack('Paired with ${SettingsStore.instance.deviceName}');
    Navigator.of(context).pop();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._results]..sort((a, b) => b.rssi.compareTo(a.rssi));
    return Scaffold(
      appBar: AppBar(title: const Text('Pair device')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _MethodButton(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan QR',
                    onTap: _scanQr,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MethodButton(
                    icon: Icons.nfc,
                    label: 'Tap NFC',
                    onTap: _readNfc,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Nearby devices',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _scanning ? _ble.stopScan : _startScan,
                  icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
                  label: Text(_scanning ? 'Stop' : 'Scan'),
                ),
              ],
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      _scanning
                          ? 'Scanning…'
                          : 'Tap Scan to find your device.',
                    ),
                  )
                : ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = sorted[i];
                      final name = r.device.platformName.isNotEmpty
                          ? r.device.platformName
                          : (r.advertisementData.advName.isNotEmpty
                              ? r.advertisementData.advName
                              : '(unknown)');
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(name),
                        subtitle: Text(
                          '${r.device.remoteId.str}  ·  ${r.rssi} dBm',
                        ),
                        trailing: FilledButton(
                          onPressed: () => _pairBle(r),
                          child: const Text('Pair'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
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
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
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

  void _registerById(String id, {required String source, String? name}) {
    final resolvedName = (name == null || name.isEmpty) ? 'MediTracker' : name;
    final settings = SettingsStore.instance;
    settings
      ..pairedDeviceId = id
      ..deviceName = resolvedName
      ..rememberDevice(id: id, name: resolvedName);
    _snack('Paired via $source · $resolvedName');
    Navigator.of(context).pop();
  }

  void _pairBle(ScanResult r) {
    final id = r.device.remoteId.str;
    final name = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : r.advertisementData.advName;
    _registerById(id, source: 'BLE', name: name);
  }

  void _pairKnown(KnownDevice d) {
    final settings = SettingsStore.instance;
    settings
      ..pairedDeviceId = d.id
      ..deviceName = d.name
      ..rememberDevice(id: d.id, name: d.name); // refresh lastConnected
    _snack('Reconnected to ${d.name}');
    Navigator.of(context).pop();
  }

  Future<void> _confirmForget(KnownDevice d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Forget ${d.name}?'),
        content: const Text('Remove this device from connection history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      SettingsStore.instance.forgetDevice(d.id);
      setState(() {});
    }
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
    final known = SettingsStore.instance.knownDevices;
    return Scaffold(
      appBar: AppBar(title: const Text('Pair device')),
      body: AnimatedBuilder(
        animation: SettingsStore.instance,
        builder: (context, _) {
          return Column(
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
          if (known.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Previously connected',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in known)
                    InputChip(
                      avatar: const Icon(Icons.bluetooth, size: 18),
                      label: Text(
                        '${d.name} · ${_relativeTime(d.lastConnected)}',
                      ),
                      onPressed: () => _pairKnown(d),
                      onDeleted: () => _confirmForget(d),
                      deleteIconColor:
                          Theme.of(context).colorScheme.outline,
                    ),
                ],
              ),
            ),
          ],
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
      );
        },
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
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

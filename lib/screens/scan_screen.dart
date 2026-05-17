import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/ble_service.dart';
import 'device_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _ble = BleService.instance;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  List<ScanResult> _results = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    // Subscribing can throw on platforms where the plugin has no
    // implementation (e.g. the headless test VM). Fail soft so the
    // screen still renders and the user gets a clear message.
    void onStreamError(Object e) {
      if (mounted) {
        setState(() =>
            _error = 'Bluetooth is unavailable on this platform: $e');
      }
    }

    _ble.adapterState.listen(
      (s) {
        if (mounted) setState(() => _adapterState = s);
      },
      onError: onStreamError,
    );
    _ble.scanResults.listen(
      (r) {
        if (mounted) setState(() => _results = r);
      },
      onError: onStreamError,
    );
    _ble.isScanning.listen(
      (_) {
        if (mounted) setState(() {});
      },
      onError: onStreamError,
    );
  }

  Future<void> _onScanPressed() async {
    setState(() => _error = null);

    if (!await _ble.isSupported) {
      _showMessage('Bluetooth is not supported on this device.');
      return;
    }
    if (!await _ble.ensurePermissions()) {
      _showMessage(
        'Bluetooth permissions were denied. Enable them in system settings.',
      );
      return;
    }
    if (_adapterState != BluetoothAdapterState.on) {
      await _ble.turnOn();
    }

    try {
      await _ble.startScan();
    } catch (e) {
      _showMessage('Failed to start scan: $e');
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scanning = _ble.isScanningNow;
    final sorted = [..._results]
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scanner'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _AdapterBadge(state: _adapterState)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      scanning
                          ? 'Scanning…'
                          : 'No devices yet.\nTap the button to scan.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _DeviceTile(result: sorted[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: scanning ? _ble.stopScan : _onScanPressed,
        icon: Icon(scanning ? Icons.stop : Icons.bluetooth_searching),
        label: Text(scanning ? 'Stop' : 'Scan'),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : (result.advertisementData.advName.isNotEmpty
            ? result.advertisementData.advName
            : '(unknown device)');

    return ListTile(
      leading: const Icon(Icons.bluetooth),
      title: Text(name),
      subtitle: Text(result.device.remoteId.str),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_rssiIcon(result.rssi), size: 20),
          Text('${result.rssi} dBm',
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DeviceScreen(device: result.device),
          ),
        );
      },
    );
  }

  IconData _rssiIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_cellular_alt;
    if (rssi >= -80) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }
}

class _AdapterBadge extends StatelessWidget {
  const _AdapterBadge({required this.state});
  final BluetoothAdapterState state;

  @override
  Widget build(BuildContext context) {
    final on = state == BluetoothAdapterState.on;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          on ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(state.name),
      ],
    );
  }
}

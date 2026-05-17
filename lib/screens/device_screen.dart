import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Turns a BLE exception into a short, human message.
///
/// The raw `FlutterBluePlusException | function | android-code: N` text is
/// meaningless to users, so we map the common Android GATT status codes to
/// what they actually mean and what to try next.
String friendlyBleError(String action, Object e) {
  if (e is FlutterBluePlusException && e.code != null) {
    final hint = switch (e.code) {
      1 => 'invalid handle — this attribute isn\'t accessible, or the '
          'cached service table is stale. Tap Refresh to clear the cache.',
      2 => 'read not permitted on this characteristic.',
      3 => 'write not permitted on this characteristic.',
      5 || 15 || 137 =>
        'the device requires pairing/bonding before this works.',
      6 => 'request not supported by this device.',
      13 => 'invalid value length for this attribute.',
      19 => 'the device closed the connection.',
      133 => 'generic GATT error (133) — flaky link; reconnect or move '
          'closer, then try again.',
      _ => e.description ?? 'GATT error ${e.code}.',
    };
    return '$action failed (code ${e.code}): $hint';
  }
  return '$action failed: $e';
}

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key, required this.device});
  final BluetoothDevice device;

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  BluetoothConnectionState _state = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = const [];
  bool _busy = false;
  StreamSubscription<BluetoothConnectionState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.device.connectionState.listen((s) async {
      if (!mounted) return;
      setState(() => _state = s);
      if (s == BluetoothConnectionState.connected) {
        await _afterConnect();
      } else if (s == BluetoothConnectionState.disconnected) {
        if (mounted) setState(() => _services = const []);
      }
    });
    _connect();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      await widget.device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      _snack(friendlyBleError('Connect', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      await widget.device.disconnect();
      if (mounted) setState(() => _services = const []);
    } catch (e) {
      _snack(friendlyBleError('Disconnect', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs once a connection is established: a larger MTU lets longer
  /// characteristic values be read in one go, then discover services.
  Future<void> _afterConnect() async {
    try {
      await widget.device.requestMtu(512);
    } catch (_) {
      // android-only / unsupported — harmless to skip.
    }
    await _discover();
  }

  Future<void> _discover() async {
    setState(() => _busy = true);
    try {
      // subscribeToServicesChanged:false — otherwise discoverServices
      // internally subscribes to the "Service Changed" characteristic,
      // and peripherals that reject that CCCD write make the whole
      // discovery throw (e.g. Android status 13 / INVALID_ATTRIBUTE_LENGTH).
      final services = await widget.device.discoverServices(
        subscribeToServicesChanged: false,
      );
      if (mounted) setState(() => _services = services);
    } catch (e) {
      _snack(friendlyBleError('Service discovery', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Clears Android's cached GATT table and reconnects. This is the cure
  /// for stale-handle errors (code 1 / GATT_INVALID_HANDLE) where the
  /// cached service list no longer matches the device.
  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      try {
        await widget.device.clearGattCache();
      } catch (_) {
        // android-only; ignore elsewhere.
      }
      await widget.device.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await widget.device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );
      // _afterConnect() runs from the connectionState listener.
      _snack('Cache cleared — reconnecting…');
    } catch (e) {
      _snack(friendlyBleError('Refresh', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final connected = _state == BluetoothConnectionState.connected;
    final name = widget.device.platformName.isNotEmpty
        ? widget.device.platformName
        : widget.device.remoteId.str;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          if (connected)
            IconButton(
              tooltip: 'Clear cache & reconnect',
              icon: const Icon(Icons.refresh),
              onPressed: _busy ? null : _refresh,
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: connected ? _disconnect : _connect,
              child: Text(
                connected ? 'Disconnect' : 'Connect',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: Icon(
              connected ? Icons.link : Icons.link_off,
              color: connected ? Colors.green : Colors.grey,
            ),
            title: Text('Status: ${_state.name}'),
            subtitle: Text(widget.device.remoteId.str),
          ),
          const Divider(height: 1),
          Expanded(
            child: _services.isEmpty
                ? Center(
                    child: Text(
                      connected
                          ? 'Discovering services…'
                          : 'Not connected.',
                    ),
                  )
                : ListView(
                    children: [
                      for (final s in _services)
                        _ServiceTile(service: s, onError: _snack),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onError});
  final BluetoothService service;
  final void Function(String) onError;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('Service ${service.uuid.str}'),
      subtitle: Text('${service.characteristics.length} characteristic(s)'),
      children: [
        for (final c in service.characteristics)
          _CharacteristicTile(characteristic: c, onError: onError),
      ],
    );
  }
}

class _CharacteristicTile extends StatefulWidget {
  const _CharacteristicTile({
    required this.characteristic,
    required this.onError,
  });
  final BluetoothCharacteristic characteristic;
  final void Function(String) onError;

  @override
  State<_CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<_CharacteristicTile> {
  List<int>? _value;
  StreamSubscription<List<int>>? _sub;
  bool _notifying = false;
  bool _busy = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _read() async {
    setState(() => _busy = true);
    try {
      final v = await widget.characteristic.read();
      if (mounted) setState(() => _value = v);
      widget.onError(v.isEmpty ? 'Read OK: (empty)' : 'Read OK');
    } catch (e) {
      widget.onError(friendlyBleError('Read', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleNotify() async {
    setState(() => _busy = true);
    try {
      final next = !_notifying;
      try {
        await widget.characteristic.setNotifyValue(next);
      } catch (e) {
        // Some peripherals reject the plain notify CCCD write but accept
        // indications. If this characteristic supports indicate, retry
        // forcing indications (Android only) before giving up.
        if (next && widget.characteristic.properties.indicate) {
          await widget.characteristic
              .setNotifyValue(true, forceIndications: true);
        } else {
          rethrow;
        }
      }
      _sub?.cancel();
      if (next) {
        _sub = widget.characteristic.lastValueStream.listen((v) {
          if (mounted) setState(() => _value = v);
        });
      }
      if (mounted) setState(() => _notifying = next);
    } catch (e) {
      widget.onError(friendlyBleError('Notify', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _format(List<int> v) {
    final hex = v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final ascii = v
        .map((b) => (b >= 32 && b < 127) ? String.fromCharCode(b) : '.')
        .join();
    return '$hex   "$ascii"';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.characteristic.properties;
    final v = _value;
    final valueText = v == null
        ? '—'
        : (v.isEmpty ? '(empty)' : _format(v));

    return ListTile(
      dense: true,
      title: Text('Char ${widget.characteristic.uuid.str}'),
      subtitle: Text('Value: $valueText'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            if (p.read)
              IconButton(
                tooltip: 'Read',
                icon: const Icon(Icons.download),
                onPressed: _read,
              ),
            if (p.notify || p.indicate)
              IconButton(
                tooltip: _notifying ? 'Stop notify' : 'Notify',
                icon: Icon(
                  _notifying
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                ),
                onPressed: _toggleNotify,
              ),
          ],
        ],
      ),
    );
  }
}

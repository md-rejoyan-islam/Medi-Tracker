import 'dart:async';

import 'package:flutter/material.dart';

/// Forces its child to rebuild every [interval] regardless of upstream
/// state changes — used by screens that show time-sensitive labels
/// (overdue, due-now, "n minutes ago") so they tick along with the wall
/// clock without the user having to leave and come back.
///
/// Pauses while the app is in the background (no point burning a frame
/// every 30 s if the user can't see it).
class MinuteTicker extends StatefulWidget {
  const MinuteTicker({
    super.key,
    required this.child,
    this.interval = const Duration(seconds: 30),
  });

  final Widget child;
  final Duration interval;

  @override
  State<MinuteTicker> createState() => _MinuteTickerState();
}

class _MinuteTickerState extends State<MinuteTicker>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _arm();
      if (mounted) setState(() {}); // immediate refresh on resume
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

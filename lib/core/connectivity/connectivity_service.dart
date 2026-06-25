import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Watches network availability and broadcasts online/offline transitions so
/// the UI can surface the offline SOS path the moment internet drops.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  ConnectivityResult _currentStatus = ConnectivityResult.wifi;
  final StreamController<ConnectivityResult> _controller = StreamController.broadcast();

  Stream<ConnectivityResult> get statusStream => _controller.stream;
  bool get isOnline => _currentStatus != ConnectivityResult.none;
  ConnectivityResult get currentStatus => _currentStatus;

  Future<void> initialize() async {
    _currentStatus = await _connectivity.checkConnectivity();
    _controller.add(_currentStatus);

    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _currentStatus != ConnectivityResult.none;
      _currentStatus = result;
      _controller.add(result);
      final isNowOnline = result != ConnectivityResult.none;

      if (wasOnline && !isNowOnline) {
        debugPrint('📵 Device went OFFLINE');
      } else if (!wasOnline && isNowOnline) {
        debugPrint('📶 Device came back ONLINE');
      }
    });
  }

  /// connectivity_plus only reports the network interface, not real reachability.
  /// A lightweight DNS lookup confirms the internet actually works.
  Future<bool> hasRealConnectivity() async {
    try {
      final result =
          await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String getStatusText() {
    switch (_currentStatus) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.none:
        return 'No Connection';
      default:
        return 'Unknown';
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

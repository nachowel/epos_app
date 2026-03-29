import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

abstract class SyncConnectivityService {
  Future<bool> isOnline();

  Stream<bool> watchOnlineStatus();
}

class ConnectivityPlusSyncConnectivityService
    implements SyncConnectivityService {
  ConnectivityPlusSyncConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async {
    try {
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity();
      return _hasConnection(results);
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Stream<bool> watchOnlineStatus() {
    return _connectivity.onConnectivityChanged
        .map(_hasConnection)
        .handleError((Object _) => false)
        .distinct();
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((ConnectivityResult result) {
      return result != ConnectivityResult.none;
    });
  }
}

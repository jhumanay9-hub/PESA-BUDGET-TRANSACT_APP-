import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final StreamController<List<ConnectivityResult>> _connectivityController = StreamController<List<ConnectivityResult>>.broadcast();

  NetworkService._internal() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _connectivityController.add(result);
    });
  }

  Stream<List<ConnectivityResult>> get onConnectivityChanged => _connectivityController.stream;

  Future<List<ConnectivityResult>> checkConnectivity() async {
    return await _connectivity.checkConnectivity();
  }

  static String getStatusString(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'Offline';
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return 'WiFi';
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return 'Mobile';
    }
    return 'Online';
  }

  bool isOnline(List<ConnectivityResult> results) {
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }
}

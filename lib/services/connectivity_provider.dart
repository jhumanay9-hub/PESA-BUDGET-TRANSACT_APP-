import 'dart:async';
import 'package:flutter/material.dart';
import 'package:transaction_app/services/connectivity_service.dart';
import 'package:transaction_app/core/logger.dart';

/// ============================================================================
/// CONNECTIVITY PROVIDER - APP-WIDE CONNECTIVITY ACCESS
/// ============================================================================
/// This widget provides connectivity status to the entire app via InheritedWidget.
/// Any widget can access connectivity status without direct service instantiation.
///
/// Usage:
/// 1. Wrap your app with ConnectivityProvider (already done in main.dart)
/// 2. Access via: ConnectivityProvider.of(context)
/// 3. Listen to changes via: ConnectivityProvider.watch(context)
/// ============================================================================

class ConnectivityProvider extends StatefulWidget {
  final Widget child;

  const ConnectivityProvider({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityProvider> createState() => _ConnectivityProviderState();

  /// Get the provider state from context (for listening to changes)
  static _ConnectivityProviderState of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<_ConnectivityProviderInherited>();
    if (provider == null) {
      throw FlutterError(
        'ConnectivityProvider.of() called with a context that does not contain a ConnectivityProvider.\n'
        'This usually happens when ConnectivityProvider is not in the widget tree.\n'
        'Make sure you wrapped your app with ConnectivityProvider.',
      );
    }
    return provider._state;
  }

  /// Watch for connectivity changes (rebuilds widget on change)
  static ConnectivityStatus watch(BuildContext context) {
    return of(context)._status;
  }
}

class _ConnectivityProviderState extends State<ConnectivityProvider> {
  final ConnectivityService _connectivityService = ConnectivityService();

  // Current connectivity state
  ConnectivityStatus _status = ConnectivityStatus.connected;
  NetworkQuality _quality = NetworkQuality.good;

  // Stream subscription
  StreamSubscription<ConnectivityStatus>? _subscription;

  @override
  void initState() {
    super.initState();
    // Start listening to connectivity changes
    _subscription = _connectivityService.connectivityStream.listen((status) {
      _status = status;
      _updateQuality();
      // Notify widgets to rebuild
      setState(() {});
    });

    // Initial status check
    _initializeStatus();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectivityService.dispose();
    super.dispose();
  }

  /// Initialize connectivity status on startup
  Future<void> _initializeStatus() async {
    _status = await _connectivityService.getConnectivityStatus();
    _quality = await _connectivityService.getNetworkQuality();
    AppLogger.logInfo(
        'ConnectivityProvider: Initial status = ${_status.name}, quality = ${_quality.name}');
  }

  /// Update network quality based on status
  Future<void> _updateQuality() async {
    if (_status == ConnectivityStatus.offline ||
        _status == ConnectivityStatus.noInternet) {
      _quality = NetworkQuality.none;
    } else {
      _quality = await _connectivityService.getNetworkQuality();
    }
  }

  /// Get connectivity service instance
  ConnectivityService get service => _connectivityService;

  /// Get current connectivity status
  ConnectivityStatus get status => _status;

  /// Get current network quality
  NetworkQuality get quality => _quality;

  /// Check if device is online
  bool get isOnline =>
      _status == ConnectivityStatus.connected ||
      _status == ConnectivityStatus.unstable;

  /// Check if Supabase is reachable
  bool get isSupabaseReachable =>
      _status != ConnectivityStatus.supabaseUnreachable;

  /// Get user-friendly status message
  String get statusMessage {
    switch (_status) {
      case ConnectivityStatus.offline:
        return 'Offline';
      case ConnectivityStatus.noInternet:
        return 'No Internet';
      case ConnectivityStatus.supabaseUnreachable:
        return 'Server Unreachable';
      case ConnectivityStatus.unstable:
        return 'Unstable Connection';
      case ConnectivityStatus.connected:
        return 'Online';
    }
  }

  /// Get status icon
  IconData get statusIcon {
    switch (_status) {
      case ConnectivityStatus.offline:
      case ConnectivityStatus.noInternet:
        return Icons.cloud_off;
      case ConnectivityStatus.supabaseUnreachable:
        return Icons.cloud_queue;
      case ConnectivityStatus.unstable:
        return Icons.signal_cellular_connected_no_internet_4_bar;
      case ConnectivityStatus.connected:
        return Icons.cloud_done;
    }
  }

  /// Get status color
  Color get statusColor {
    switch (_status) {
      case ConnectivityStatus.offline:
      case ConnectivityStatus.noInternet:
        return Colors.red;
      case ConnectivityStatus.supabaseUnreachable:
        return Colors.orange;
      case ConnectivityStatus.unstable:
        return Colors.yellow[700]!;
      case ConnectivityStatus.connected:
        return Colors.green;
    }
  }

  /// Force refresh connectivity status
  Future<void> refresh() async {
    await _connectivityService.refreshConnectivity();
    _status = await _connectivityService.getConnectivityStatus();
    _quality = await _connectivityService.getNetworkQuality();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _ConnectivityProviderInherited(
      state: this,
      child: widget.child,
    );
  }
}

/// InheritedWidget wrapper for ConnectivityProvider
class _ConnectivityProviderInherited extends InheritedWidget {
  final _ConnectivityProviderState _state;

  const _ConnectivityProviderInherited({
    required _ConnectivityProviderState state,
    required super.child,
  }) : _state = state;

  @override
  bool updateShouldNotify(_ConnectivityProviderInherited oldWidget) {
    return _state._status != oldWidget._state._status ||
        _state._quality != oldWidget._state._quality;
  }
}

/// Extension to get provider from context
extension ConnectivityProviderExtension on BuildContext {
  _ConnectivityProviderState get connectivityProvider =>
      ConnectivityProvider.of(this);
}

/// ============================================================================
/// CONNECTIVITY STATUS BUILDER
/// ============================================================================
/// A convenient widget builder that rebuilds when connectivity status changes.
/// ============================================================================

class ConnectivityStatusBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    ConnectivityStatus status,
    NetworkQuality quality,
  ) builder;

  const ConnectivityStatusBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final provider = ConnectivityProvider.of(context);
    return builder(context, provider.status, provider.quality);
  }
}

/// ============================================================================
/// OFFLINE DETECTOR
/// ============================================================================
/// Shows a widget when device is offline, hides when online.
/// ============================================================================

class OfflineDetector extends StatelessWidget {
  final Widget offlineWidget;
  final Widget onlineWidget;

  const OfflineDetector({
    super.key,
    this.offlineWidget = const SizedBox.shrink(),
    this.onlineWidget = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final provider = ConnectivityProvider.of(context);

    if (!provider.isOnline) {
      return offlineWidget;
    }

    return onlineWidget;
  }
}

/// ============================================================================
/// SYNC AVAILABILITY INDICATOR
/// ============================================================================
/// Shows whether sync is available based on connectivity and network quality.
/// ============================================================================

class SyncAvailabilityIndicator extends StatelessWidget {
  final Widget Function(bool canSync, NetworkQuality quality) builder;

  const SyncAvailabilityIndicator({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final provider = ConnectivityProvider.of(context);
    final canSync = provider.isOnline &&
        provider.isSupabaseReachable &&
        provider.quality != NetworkQuality.none &&
        provider.quality != NetworkQuality.poor;

    return builder(canSync, provider.quality);
  }
}

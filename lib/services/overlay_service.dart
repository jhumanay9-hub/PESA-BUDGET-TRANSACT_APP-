import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:transaction_app/models/transaction_model.dart';
import 'package:transaction_app/core/logger.dart';

class OverlayService {
  /// Displays the M-PESA quick-action overlay with safe Isolate Data Transfer
  static Future<void> showTransactionOverlay(TransactionModel tx) async {
    // 1. Silent Permission Guard
    // We check but DO NOT request here. Requesting permissions from a background
    // service often causes the OS to silently crash the process.
    bool isAllowed = await FlutterOverlayWindow.isPermissionGranted();

    if (!isAllowed) {
      AppLogger.logWarning(
          "Overlay: Permission missing. User must enable 'Display over other apps'.");
      return;
    }

    AppLogger.logInfo("Overlay: Launching for transaction from ${tx.sender}");

    // 2. Launch the Window with Safe Dimensions
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "New M-PESA Detected",
      overlayContent: "Tap to categorize Ksh ${tx.amount}",
      height:
          500, // CRITICAL: Fixed height prevents the 'Invisible Wall' touch bug
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.center,
      visibility: NotificationVisibility.visibilityPublic,
      flag: OverlayFlag.defaultFlag,
      positionGravity: PositionGravity.auto,
    );
  }

  static void closeOverlay() {
    FlutterOverlayWindow.closeOverlay();
  }
}

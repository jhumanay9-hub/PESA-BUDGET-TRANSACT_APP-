import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayManager {
  static Future<void> show({required double amount, required String merchant}) async {
    try {
      final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      if (!hasPermission) return;

      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        await FlutterOverlayWindow.shareData({
          'amount': amount,
          'merchant': merchant,
        });
      } else {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: "Transaction Detected",
          overlayContent: "New spending found",
          flag: OverlayFlag.defaultFlag,
          width: 400,
          height: 200,
          alignment: OverlayAlignment.center,
        );
        
        // Wait a bit for the overlay to stabilize then share data
        await Future.delayed(const Duration(milliseconds: 200));
        await FlutterOverlayWindow.shareData({
          'amount': amount,
          'merchant': merchant,
        });
      }
    } catch (e) {
      debugPrint("OverlayManager.show error: $e");
    }
  }

  static Future<void> close() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint("OverlayManager.close error: $e");
    }
  }
}

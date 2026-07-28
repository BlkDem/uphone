import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:win_toast/win_toast.dart';

class WindowsTrayService {
  static final WindowsTrayService _instance = WindowsTrayService._();
  static WindowsTrayService get instance => _instance;
  WindowsTrayService._();

  final SystemTray _tray = SystemTray();
  final AppWindow _appWindow = AppWindow();
  final WindowManager _windowManager = WindowManager.instance;
  bool _isInitialized = false;
  bool _isQuitting = false;

  // GUID for the notification activator class
  static const _clsid = '2EB1AE51-98B7-4C2B-B1A0-000000000001';

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized || !Platform.isWindows) return;

    try {
      await _windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1100, 720),
        minimumSize: Size(800, 500),
        center: true,
      );
      await _windowManager.waitUntilReadyToShow(windowOptions, () async {
        await _windowManager.show();
        await _windowManager.focus();
      });

      await _windowManager.setPreventClose(true);
      _windowManager.addListener(_WindowCloseListener(_onWindowClose));

      // Init tray with Flutter asset (system_tray resolves relative to flutter_assets/)
      await _tray.initSystemTray(
        title: 'UPhone',
        iconPath: 'assets/tray_icon.ico',
        toolTip: 'UPhone Messenger',
      );

      final menu = [
        MenuItem(
          label: 'Show',
          onClicked: _showWindow,
        ),
        MenuItem(
          label: 'Hide',
          onClicked: _hideWindow,
        ),
        MenuSeparator(),
        MenuItem(
          label: 'Quit',
          onClicked: _quit,
        ),
      ];

      await _tray.setContextMenu(menu);

      _tray.registerSystemTrayEventHandler((eventName) {
        if (eventName == 'leftMouseUp' || eventName == 'leftMouseDblClk') {
          _showWindow();
        } else if (eventName == 'rightMouseUp') {
          _tray.popUpContextMenu();
        }
      });

      // Initialize WinToast for native Windows notifications
      try {
        final toast = WinToast.instance();
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final iconPath = '$exeDir\\data\\flutter_assets\\assets\\tray_icon.ico';
        await toast.initialize(
          aumId: 'com.uphone.messenger',
          displayName: 'UPhone Messenger',
          iconPath: iconPath,
          clsid: _clsid,
        );
        debugPrint('WinToast initialized');
      } catch (e) {
        debugPrint('WinToast init failed: $e');
      }

      _isInitialized = true;
      debugPrint('Windows tray initialized');
    } catch (e) {
      debugPrint('Failed to initialize Windows tray: $e');
    }
  }

  void _onWindowClose() async {
    if (_isQuitting) {
      await _windowManager.setPreventClose(false);
      await _windowManager.close();
      exit(0);
    }
    await _windowManager.hide();
  }

  void _showWindow() {
    _appWindow.show();
    _windowManager.focus();
  }

  void _hideWindow() {
    _windowManager.hide();
  }

  Future<void> showNotification(String title, String body) async {
    try {
      final toast = WinToast.instance();
      await toast.showToast(
        toast: Toast(
          children: [
            ToastChildVisual(
              binding: ToastVisualBinding(
                children: [
                  ToastVisualBindingChildText(text: title, id: 0),
                  ToastVisualBindingChildText(text: body, id: 1),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('WinToast show failed: $e');
    }
  }

  Future<void> _quit() async {
    _isQuitting = true;
    await _windowManager.close();
  }

  void dispose() {
    _windowManager.removeListener(_WindowCloseListener(_onWindowClose));
  }
}

class _WindowCloseListener extends WindowListener {
  final VoidCallback onClose;
  _WindowCloseListener(this.onClose);

  @override
  void onWindowClose() => onClose();
}

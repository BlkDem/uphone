import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class WindowsTrayService {
  static final WindowsTrayService _instance = WindowsTrayService._();
  static WindowsTrayService get instance => _instance;
  WindowsTrayService._();

  final SystemTray _tray = SystemTray();
  final AppWindow _appWindow = AppWindow();
  final WindowManager _windowManager = WindowManager.instance;
  bool _isInitialized = false;
  bool _isQuitting = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized || !Platform.isWindows) return;

    try {
      await _windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(420, 720),
        minimumSize: Size(360, 500),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
      );
      await _windowManager.waitUntilReadyToShow(windowOptions, () async {
        await _windowManager.show();
        await _windowManager.focus();
      });

      _windowManager.addListener(_WindowCloseListener(_onWindowClose));

      final iconPath = await _getIconPath();
      await _tray.initSystemTray(
        title: 'UPhone',
        iconPath: iconPath,
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

      _isInitialized = true;
      debugPrint('Windows tray initialized');
    } catch (e) {
      debugPrint('Failed to initialize Windows tray: $e');
    }
  }

  Future<String> _getIconPath() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final iconPath = '$exeDir\\data\\flutter_assets\\windows\\runner\\resources\\app_icon.ico';
    if (await File(iconPath).exists()) {
      return iconPath;
    }
    final fallback = '$exeDir\\app_icon.ico';
    if (await File(fallback).exists()) {
      return fallback;
    }
    return '';
  }

  void _onWindowClose() async {
    if (_isQuitting) {
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

  void showNotification(String title, String body) {
    // system_tray v0.1.1 doesn't support balloon notifications
    // For Windows notifications, use a native MethodChannel or upgrade package
    debugPrint('Notification: $title - $body');
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

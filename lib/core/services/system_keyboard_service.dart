import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SystemKeyboardService {
  SystemKeyboardService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'epos/system_keyboard';

  static final SystemKeyboardService instance = SystemKeyboardService();
  @visibleForTesting
  static bool? debugSupportsSelectiveSystemKeyboardOverride;

  final MethodChannel _channel;

  bool get supportsSelectiveSystemKeyboard =>
      debugSupportsSelectiveSystemKeyboardOverride ??
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<bool> openSystemKeyboard() async {
    return _invoke('show');
  }

  Future<bool> closeSystemKeyboard() async {
    return _invoke('hide');
  }

  Future<bool> ensureSystemKeyboardForTextInput({
    required FocusNode focusNode,
  }) async {
    if (!supportsSelectiveSystemKeyboard) {
      return false;
    }
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
      await SchedulerBinding.instance.endOfFrame;
      if (!focusNode.hasFocus) {
        return false;
      }
    }
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    return openSystemKeyboard();
  }

  Future<bool> _invoke(String method) async {
    if (!supportsSelectiveSystemKeyboard) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

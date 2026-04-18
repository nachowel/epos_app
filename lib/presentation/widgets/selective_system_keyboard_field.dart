import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/system_keyboard_service.dart';

class SelectiveSystemKeyboardTextField extends StatelessWidget {
  const SelectiveSystemKeyboardTextField({
    Key? key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.style,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
  }) : _fieldKey = key,
       super(key: null);

  final Key? _fieldKey;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SelectiveSystemKeyboardActivator(
      focusNode: focusNode,
      enabled: enabled,
      builder:
          (
            BuildContext context,
            FocusNode effectiveFocusNode,
            GestureTapCallback handleTap,
            TapRegionCallback handleTapOutside,
          ) => TextField(
            key: _fieldKey,
            controller: controller,
            focusNode: effectiveFocusNode,
            decoration: decoration,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: style,
            autofocus: autofocus,
            enabled: enabled,
            maxLines: maxLines,
            obscureText: obscureText,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onTap: () {
              handleTap();
              onTap?.call();
            },
            onTapAlwaysCalled: true,
            onTapOutside: handleTapOutside,
          ),
    );
  }
}

class SelectiveSystemKeyboardTextFormField extends StatelessWidget {
  const SelectiveSystemKeyboardTextFormField({
    Key? key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.style,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.onTap,
  }) : _fieldKey = key,
       super(key: null);

  final Key? _fieldKey;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SelectiveSystemKeyboardActivator(
      focusNode: focusNode,
      enabled: enabled,
      builder:
          (
            BuildContext context,
            FocusNode effectiveFocusNode,
            GestureTapCallback handleTap,
            TapRegionCallback handleTapOutside,
          ) => TextFormField(
            key: _fieldKey,
            controller: controller,
            initialValue: initialValue,
            focusNode: effectiveFocusNode,
            decoration: decoration,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: style,
            autofocus: autofocus,
            enabled: enabled,
            maxLines: maxLines,
            onChanged: onChanged,
            onFieldSubmitted: onFieldSubmitted,
            validator: validator,
            onTap: () {
              handleTap();
              onTap?.call();
            },
            onTapAlwaysCalled: true,
            onTapOutside: handleTapOutside,
          ),
    );
  }
}

class _SelectiveSystemKeyboardActivator extends StatefulWidget {
  const _SelectiveSystemKeyboardActivator({
    required this.focusNode,
    required this.enabled,
    required this.builder,
  });

  final FocusNode? focusNode;
  final bool enabled;
  final Widget Function(
    BuildContext context,
    FocusNode effectiveFocusNode,
    GestureTapCallback handleTap,
    TapRegionCallback handleTapOutside,
  )
  builder;

  @override
  State<_SelectiveSystemKeyboardActivator> createState() =>
      _SelectiveSystemKeyboardActivatorState();
}

class _SelectiveSystemKeyboardActivatorState
    extends State<_SelectiveSystemKeyboardActivator> {
  FocusNode? _internalFocusNode;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    _ensureInternalFocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(_SelectiveSystemKeyboardActivator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) {
      return;
    }
    final FocusNode previousFocusNode =
        oldWidget.focusNode ?? _internalFocusNode!;
    previousFocusNode.removeListener(_handleFocusChanged);
    if (oldWidget.focusNode == null && widget.focusNode != null) {
      _internalFocusNode?.dispose();
      _internalFocusNode = null;
    } else if (oldWidget.focusNode != null && widget.focusNode == null) {
      _ensureInternalFocusNode();
    }
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _focusNode, _handleTap, _handleTapOutside);
  }

  void _ensureInternalFocusNode() {
    _internalFocusNode ??= FocusNode(
      debugLabel: 'selective-system-keyboard-field',
    );
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus || !widget.enabled) {
      return;
    }
    _ensureSystemKeyboard();
  }

  void _handleTap() {
    if (!widget.enabled) {
      return;
    }
    _ensureSystemKeyboard();
  }

  void _handleTapOutside(PointerDownEvent event) {
    if (!_focusNode.hasFocus) {
      return;
    }
    _focusNode.unfocus();
    unawaited(SystemKeyboardService.instance.closeSystemKeyboard());
  }

  void _ensureSystemKeyboard() {
    unawaited(
      SystemKeyboardService.instance.ensureSystemKeyboardForTextInput(
        focusNode: _focusNode,
      ),
    );
  }
}

import '../../../../domain/models/order_modifier.dart';
import '../../../../domain/services/breakfast_modifier_renderer.dart';

const BreakfastModifierRenderer _renderer = BreakfastModifierRenderer();

/// Formats an [OrderModifier] into a user-facing label for the order detail UI.
///
/// Delegates to [BreakfastModifierRenderer] so that the detail screen, kitchen
/// ticket, and receipt all share the same semantic classification vocabulary.
String formatOrderModifierLabel(OrderModifier modifier) {
  final BreakfastModifierRendered rendered =
      _renderer.renderAll(<OrderModifier>[modifier]).first;
  return rendered.label;
}

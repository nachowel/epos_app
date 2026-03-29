import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/pos_interaction_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/section_app_bar.dart';
import 'widgets/cart_panel.dart';
import 'widgets/category_bar.dart';
import 'widgets/checkout_sheet.dart';
import 'widgets/interaction_lock_shell.dart';
import 'widgets/modifier_popup.dart';
import 'widgets/payment_dialog.dart';
import 'widgets/product_grid.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(productsNotifierProvider.notifier).loadCatalog();
      await ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
      await ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
    });
  }

  Future<void> _onTapProduct(Product product) async {
    final PosInteractionPolicy interactionPolicy = ref.read(
      posInteractionProvider,
    );
    final PosInteractionController interactionController = ref.read(
      posInteractionControllerProvider,
    );
    if (!interactionPolicy.canOpenModifierDialog) {
      return;
    }

    if (!product.hasModifiers) {
      interactionController.addProduct(product);
      return;
    }

    final List<CartModifier>? selectedModifiers =
        await showDialog<List<CartModifier>>(
          context: context,
          builder: (_) {
            return ModifierPopup(
              productId: product.id,
              productName: product.name,
            );
          },
        );
    if (!mounted || selectedModifiers == null) {
      return;
    }

    interactionController.addProduct(product, modifiers: selectedModifiers);
  }

  Future<bool> _createOrderFromCart() async {
    final PosInteractionPolicy interactionPolicy = ref.read(
      posInteractionProvider,
    );
    final PosInteractionController interactionController = ref.read(
      posInteractionControllerProvider,
    );
    final authState = ref.read(authNotifierProvider);
    final user = authState.currentUser;
    if (user == null) {
      _showMessage(AppStrings.loginFailed);
      return false;
    }
    if (interactionPolicy.isInteractionLocked) {
      _showMessage(
        interactionController.currentBlockMessage ?? AppStrings.accessDenied,
      );
      return false;
    }

    final createdTransaction = await interactionController.createOrderFromCart(
      currentUser: user,
    );

    if (!mounted) {
      return false;
    }

    if (createdTransaction == null) {
      final String fallback = AppStrings.loginFailed;
      final String message =
          ref.read(ordersNotifierProvider).errorMessage ?? fallback;
      _showMessage(message);
      return false;
    }

    _showMessage(
      '${AppStrings.orderCreated} ${AppStrings.orderNumber(createdTransaction.id)}',
    );
    return true;
  }

  Future<bool> _payNowFromCart(PaymentMethod method) async {
    final PosInteractionPolicy interactionPolicy = ref.read(
      posInteractionProvider,
    );
    final authState = ref.read(authNotifierProvider);
    final user = authState.currentUser;
    if (user == null) {
      _showMessage(AppStrings.loginFailed);
      return false;
    }
    if (interactionPolicy.isInteractionLocked) {
      _showMessage(
        ref.read(posInteractionControllerProvider).currentBlockMessage ??
            AppStrings.accessDenied,
      );
      return false;
    }

    final PosInteractionController interactionController = ref.read(
      posInteractionControllerProvider,
    );
    final bool paid = await _showPaymentDialog(
      totalAmountMinor: ref.read(cartNotifierProvider).totalMinor,
      initialPaymentMethod: method,
      onSubmit: (paymentMethod) async {
        final Transaction? transaction = await interactionController
            .payNowFromCart(currentUser: user, method: paymentMethod);
        if (transaction != null) {
          return null;
        }
        return interactionController.currentBlockMessage ??
            ref.read(ordersNotifierProvider).errorMessage ??
            AppStrings.paymentFailedOrderOpen;
      },
    );
    if (!mounted) {
      return false;
    }
    if (paid) {
      _showMessage(AppStrings.paymentCompleted);
    }
    return paid;
  }

  Future<bool> _showPaymentDialog({
    required int totalAmountMinor,
    required PaymentMethod initialPaymentMethod,
    required Future<String?> Function(PaymentMethod paymentMethod) onSubmit,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PaymentDialog(
          totalAmountMinor: totalAmountMinor,
          initialPaymentMethod: initialPaymentMethod,
          onSubmit: onSubmit,
          isSubmissionBlocked: !ref.read(posInteractionProvider).canTakePayment,
          blockedMessage: ref.read(posInteractionProvider).lockMessage,
        );
      },
    );

    return result ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCheckoutSheet() async {
    final CartState cartState = ref.read(cartNotifierProvider);
    if (cartState.isEmpty) {
      return;
    }
    final PosInteractionPolicy interactionPolicy = ref.read(
      posInteractionProvider,
    );

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: AppStrings.checkout,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return CheckoutSheet(
          cartTotalMinor: cartState.totalMinor,
          subtotalMinor: cartState.subtotalMinor,
          modifierTotalMinor: cartState.modifierTotalMinor,
          canPayNow: interactionPolicy.canTakePayment,
          canCreateOrder: interactionPolicy.canCreateOrder,
          canClearCart: interactionPolicy.canClearCart,
          isBusy: interactionPolicy.isCheckoutBusy,
          onPay: _payNowFromCart,
          onCreateOrder: _createOrderFromCart,
          onClearCart: () async {
            final bool cleared = ref
                .read(posInteractionControllerProvider)
                .clearCart();
            return cleared;
          },
        );
      },
      transitionBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final Animation<Offset> offsetAnimation = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final productsState = ref.watch(productsNotifierProvider);
    final cartState = ref.watch(cartNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final PosInteractionPolicy interactionPolicy = ref.watch(
      posInteractionProvider,
    );
    final PosInteractionController interactionController = ref.read(
      posInteractionControllerProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.navPos,
        currentRoute: '/pos',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        compactVisual: true,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (productsState.errorMessage != null)
              Container(
                width: double.infinity,
                color: AppColors.error.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(AppSizes.spacingSm),
                child: Text(
                  productsState.errorMessage!,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.error,
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double cartPanelWidth = AppSizes
                      .responsiveCartPanelWidth(constraints.maxWidth);

                  return Row(
                    children: <Widget>[
                      Expanded(
                        child: InteractionLockShell(
                          isLocked: interactionPolicy.isInteractionLocked,
                          message:
                              interactionPolicy.lockMessage ??
                              AppStrings.accessDenied,
                          child: Column(
                            children: <Widget>[
                              CategoryBar(
                                categories: productsState.categories,
                                selectedCategoryId:
                                    productsState.selectedCategoryId,
                                isLoading: productsState.isLoading,
                                onSelectCategory: (int? categoryId) {
                                  ref
                                      .read(productsNotifierProvider.notifier)
                                      .selectCategory(categoryId);
                                },
                              ),
                              Expanded(
                                child: ProductGrid(
                                  products: productsState.products,
                                  isLoading: productsState.isLoading,
                                  viewportWidth: constraints.maxWidth,
                                  onTapProduct:
                                      interactionPolicy.isInteractionLocked
                                      ? null
                                      : _onTapProduct,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cartPanelWidth,
                        child: InteractionLockShell(
                          isLocked: interactionPolicy.isInteractionLocked,
                          message:
                              interactionPolicy.lockMessage ??
                              AppStrings.accessDenied,
                          child: CartPanel(
                            panelWidth: cartPanelWidth,
                            cartState: cartState,
                            canCheckout:
                                !cartState.isEmpty &&
                                (interactionPolicy.canCreateOrder ||
                                    interactionPolicy.canTakePayment ||
                                    interactionPolicy.canClearCart),
                            isCheckoutLoading: interactionPolicy.isCheckoutBusy,
                            onIncreaseQuantity: (String localId) {
                              interactionController.increaseQuantity(localId);
                            },
                            onDecreaseQuantity: (String localId) {
                              interactionController.decreaseQuantity(localId);
                            },
                            onRemoveLine: (String localId) {
                              interactionController.removeItem(localId);
                            },
                            onCheckout: _openCheckoutSheet,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

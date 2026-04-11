import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/providers/app_providers.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/transaction.dart';
import '../../../domain/models/meal_customization.dart';
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
import 'widgets/semantic_bundle_editor_dialog.dart';
import 'widgets/standard_meal_customization_dialog.dart';
import '../../../domain/services/breakfast_pos_service.dart';
import '../../../domain/models/breakfast_cart_selection.dart';
import '../../../domain/services/meal_customization_pos_service.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({this.initialCategoryId, super.key});

  final int? initialCategoryId;

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  static const Map<String, String?> _breakfastChoiceDefaults =
      <String, String?>{'drink': 'Cappuccino/Latte', 'bread': 'Toast'};
  bool _shouldReturnToCategoryEntryAfterPayment = false;
  bool _isCompletingSuccessfulPaymentTransition = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadScreenState);
  }

  @override
  void didUpdateWidget(covariant PosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategoryId != widget.initialCategoryId) {
      Future<void>.microtask(_loadScreenState);
    }
  }

  Future<void> _loadScreenState() async {
    // Route-driven POS entry should always resolve the active category from the
    // shared ordered catalog, not from stale in-memory sidebar state.
    await ref
        .read(productsNotifierProvider.notifier)
        .loadCatalog(
          preferredCategoryId: widget.initialCategoryId,
          preserveVisibleSelection: false,
        );
    await ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
    await ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
    _prefetchMealSuggestions();
  }

  void _prefetchMealSuggestions() {
    _prefetchMealSuggestionsForProducts(
      ref.read(productsNotifierProvider).products,
    );
  }

  /// Prefetches meal suggestions for the given product list.
  /// Called on init and on category switch. Visibility-scoped:
  /// only products present in the provided list are prefetched.
  void _prefetchMealSuggestionsForProducts(List<Product> products) {
    final List<int> mealProductIds = products
        .where((Product p) => p.mealAdjustmentProfileId != null)
        .map((Product p) => p.id)
        .toList(growable: false);
    if (mealProductIds.isEmpty) return;
    final Map<int, String> productNamesById = <int, String>{
      for (final Product p in products) p.id: p.name,
    };
    // Fire-and-forget — prefetch is best-effort.
    ref
        .read(mealInsightsServiceProvider)
        .prefetchSuggestions(
          productIds: mealProductIds,
          productNamesById: productNamesById,
        );
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

    final PosProductSelectionPath selectionPath = await ref
        .read(breakfastPosServiceProvider)
        .getSelectionPath(product);
    if (!mounted) {
      return;
    }

    switch (selectionPath) {
      case PosProductSelectionPath.standard:
        if (product.mealAdjustmentProfileId != null) {
          final MealCustomizationPosEditorData editorData;
          try {
            editorData = await ref
                .read(mealCustomizationPosServiceProvider)
                .loadEditorData(product: product);
          } catch (error, stackTrace) {
            if (!mounted) {
              return;
            }
            _showMessage(
              ErrorMapper.toUserMessageAndLog(
                error,
                logger: ref.read(appLoggerProvider),
                eventType: 'meal_customization_editor_open_failed',
                stackTrace: stackTrace,
              ),
            );
            return;
          }
          List<MealQuickSuggestion> suggestions = const <MealQuickSuggestion>[];
          try {
            suggestions = await ref
                .read(mealInsightsServiceProvider)
                .loadSuggestionsForProduct(
                  productId: product.id,
                  productNamesById: editorData.productNamesById,
                  limit: 5,
                );
          } catch (_) {
            // Suggestions are optional — fail silently.
          }
          final MealCustomizationCartSelection? selection =
              await showDialog<MealCustomizationCartSelection>(
                context: context,
                barrierDismissible: false,
                builder: (_) => StandardMealCustomizationDialog(
                  product: product,
                  initialEditorData: editorData,
                  suggestions: suggestions,
                ),
              );
          if (!mounted || selection == null) {
            return;
          }
          interactionController.addProduct(
            product,
            mealCustomizationSelection: selection,
          );
          return;
        }
        interactionController.addProduct(product);
        return;
      case PosProductSelectionPath.legacyFlat:
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
        return;
      case PosProductSelectionPath.semanticBundle:
        final BreakfastPosEditorData editorData;
        try {
          editorData = await ref
              .read(breakfastPosServiceProvider)
              .loadEditorData(product: product);
        } catch (error, stackTrace) {
          if (!mounted) {
            return;
          }
          _showMessage(
            ErrorMapper.toUserMessageAndLog(
              error,
              logger: ref.read(appLoggerProvider),
              eventType: 'semantic_bundle_editor_open_failed',
              stackTrace: stackTrace,
            ),
          );
          return;
        }
        final BreakfastCartSelection? selection =
            await showDialog<BreakfastCartSelection>(
              context: context,
              barrierDismissible: false,
              builder: (_) => SemanticBundleEditorDialog(
                product: product,
                initialEditorData: editorData,
                choiceDefaults: _breakfastChoiceDefaults,
              ),
            );
        if (!mounted || selection == null) {
          return;
        }
        interactionController.addProduct(
          product,
          breakfastSelection: selection,
        );
        return;
    }
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
      _shouldReturnToCategoryEntryAfterPayment = true;
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
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );

    if (!mounted || !_shouldReturnToCategoryEntryAfterPayment) {
      return;
    }

    await _completeSuccessfulPaymentTransition();
  }

  Future<void> _completeSuccessfulPaymentTransition() async {
    if (_isCompletingSuccessfulPaymentTransition) {
      return;
    }

    _isCompletingSuccessfulPaymentTransition = true;
    _shouldReturnToCategoryEntryAfterPayment = false;

    _navigateToCategoryEntryAfterReset(message: AppStrings.paymentCompleted);
  }

  void _resetPosSessionToPreOrder() {
    ref.read(cartNotifierProvider.notifier).clearCart();
    ref.read(productsNotifierProvider.notifier).resetToPreOrder();
    ref.read(ordersNotifierProvider.notifier).resetPosSessionContext();
  }

  void _navigateToCategoryEntryAfterReset({String? message}) {
    _resetPosSessionToPreOrder();
    if (message != null) {
      _showMessage(message);
    }
    context.go('/pos/categories');
  }

  Future<void> _handleNavbarDestination(String route) async {
    if (route != '/pos/categories') {
      context.go(route);
      return;
    }

    final CartState cartState = ref.read(cartNotifierProvider);
    final OrdersState ordersState = ref.read(ordersNotifierProvider);
    final bool hasActiveOrderContext =
        !cartState.isEmpty || ordersState.selectedOrderId != null;

    if (!hasActiveOrderContext) {
      context.go(route);
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Start new order?'),
          content: const Text('Current order will be cleared.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    _navigateToCategoryEntryAfterReset();
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
    final String selectedCategoryTitle = _resolveSelectedCategoryTitle(
      categories: productsState.categories,
      selectedCategoryId: productsState.selectedCategoryId,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.navPos,
        currentRoute: '/pos',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        compactVisual: true,
        onSelectDestination: _handleNavbarDestination,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (productsState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.spacingMd,
                  AppSizes.spacingSm,
                  AppSizes.spacingMd,
                  0,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.spacingSm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    productsState.errorMessage!,
                    style: const TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double shellPadding = constraints.maxWidth >= 1400
                      ? AppSizes.spacingLg
                      : AppSizes.spacingMd;
                  final double columnGap = constraints.maxWidth >= 1280
                      ? 14
                      : 12;
                  final double cartPanelWidth =
                      AppSizes.responsiveCartPanelWidth(constraints.maxWidth);
                  final double categoryPanelWidth = _resolveCategoryPanelWidth(
                    viewportWidth: constraints.maxWidth,
                    cartPanelWidth: cartPanelWidth,
                    shellPadding: shellPadding,
                    columnGap: columnGap,
                  );

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      shellPadding,
                      AppSizes.spacingMd,
                      shellPadding,
                      AppSizes.spacingMd,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          width: categoryPanelWidth,
                          child: InteractionLockShell(
                            isLocked: interactionPolicy.isInteractionLocked,
                            message:
                                interactionPolicy.lockMessage ??
                                AppStrings.accessDenied,
                            child: CategoryBar(
                              categories: productsState.categories,
                              categoryProductCounts:
                                  productsState.categoryProductCounts,
                              selectedCategoryId:
                                  productsState.selectedCategoryId,
                              isLoading: productsState.isLoading,
                              onSelectCategory: (int? categoryId) async {
                                await ref
                                    .read(productsNotifierProvider.notifier)
                                    .selectCategory(categoryId);
                                _prefetchMealSuggestionsForProducts(
                                  ref.read(productsNotifierProvider).products,
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: columnGap),
                        Expanded(
                          child: InteractionLockShell(
                            isLocked: interactionPolicy.isInteractionLocked,
                            message:
                                interactionPolicy.lockMessage ??
                                AppStrings.accessDenied,
                            child: ProductGrid(
                              title: selectedCategoryTitle,
                              productCount: productsState.products.length,
                              products: productsState.products,
                              isLoading: productsState.isLoading,
                              viewportWidth: constraints.maxWidth,
                              onTapProduct:
                                  interactionPolicy.isInteractionLocked
                                  ? null
                                  : _onTapProduct,
                            ),
                          ),
                        ),
                        SizedBox(width: columnGap),
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
                              isCheckoutLoading:
                                interactionPolicy.isCheckoutBusy,
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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveSelectedCategoryTitle({
    required List<Category> categories,
    required int? selectedCategoryId,
  }) {
    if (selectedCategoryId == null) {
      return AppStrings.allCategories;
    }

    for (final Category category in categories) {
      if (category.id == selectedCategoryId) {
        return category.name;
      }
    }

    return AppStrings.products;
  }

  double _resolveCategoryPanelWidth({
    required double viewportWidth,
    required double cartPanelWidth,
    required double shellPadding,
    required double columnGap,
  }) {
    final double remainingWidth =
        viewportWidth - cartPanelWidth - (shellPadding * 2) - (columnGap * 2);
    final double targetWidth = remainingWidth * 0.20;
    return targetWidth.clamp(168.0, 212.0).toDouble();
  }
}

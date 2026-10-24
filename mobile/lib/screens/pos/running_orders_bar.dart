import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pos_debug_log.dart';
import '../../models/cart_item.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/tab_refresh_bus.dart';
import '../../services/order_service.dart';

/// Saves the cart as an open (unbilled) order on the server, or updates the
/// open order it already belongs to. On a first save the cart is linked to
/// the new order (cart.openOrderId).
Future<Order> saveCartAsOpenOrder(CartProvider cart) async {
  final service = OrderService();

  if (cart.openOrderId != null) {
    await service.updateOpenOrderItems(
      cart.openOrderId!,
      items: cart.items,
      discount: cart.discount,
      notes: cart.notes,
      customerId: cart.selectedCustomer?.id,
      tableCustomerLabel: cart.customerNameInput,
    );
    return service.getById(cart.openOrderId!);
  }

  final order = await service.startOpenOrder(
    orderType: cart.orderType,
    tableId: cart.tableId,
    tableCustomerLabel: cart.effectiveCustomerLabel,
    customerId: cart.selectedCustomer?.id,
    notes: cart.notes,
    deliveryInfo: cart.orderType == 'delivery'
        ? {
            'address': cart.deliveryAddress.trim(),
            'phone': cart.deliveryPhone.trim(),
          }
        : null,
  );
  await service.updateOpenOrderItems(
    order.id,
    items: cart.items,
    discount: cart.discount,
    notes: cart.notes,
    customerId: cart.selectedCustomer?.id,
  );
  cart.configureContext(
    orderType: cart.orderType,
    tableId: cart.tableId,
    tableName: cart.tableName,
    tableCustomerLabel: cart.effectiveCustomerLabel,
    openOrderId: order.id,
  );
  return order;
}

/// [saveCartAsOpenOrder] with a snackbar for the result. Returns true on
/// success, so callers never throw away a cart that failed to save.
Future<bool> saveCartWithFeedback(BuildContext context) async {
  final cart = context.read<CartProvider>();
  if (cart.isEmpty) return false;

  final messenger = ScaffoldMessenger.of(context);
  final refreshBus = context.read<TabRefreshBus>();
  try {
    final order = await saveCartAsOpenOrder(cart);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Order #${order.orderNumber} saved')));
    refreshBus.bumpDashboard();
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not save the order. Please try again.')),
    );
  }
  return false;
}

/// Running (unbilled) Takeaway / Delivery orders, like customers on a
/// dine-in table: several customers can be served before any of them is
/// billed. "New customer" saves the current cart as an open order on the
/// server and starts an empty one; tapping a customer's chip saves the
/// current cart and loads that customer back. Open orders live on the
/// server, so they survive app restarts and show on every device.
class RunningOrdersBar extends StatefulWidget {
  /// 'takeaway' or 'delivery'.
  final String orderType;

  const RunningOrdersBar({super.key, required this.orderType});

  @override
  State<RunningOrdersBar> createState() => RunningOrdersBarState();
}

class RunningOrdersBarState extends State<RunningOrdersBar> {
  List<Order> _orders = const [];
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  @override
  void didUpdateWidget(RunningOrdersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderType != widget.orderType) {
      setState(() => _orders = const []);
      unawaited(refresh());
    }
  }

  /// Reloads the list from the server (e.g. after saving or billing).
  Future<void> refresh() async {
    final type = widget.orderType;
    try {
      final orders = await OrderService().list(
        orderType: type,
        status: 'active',
        limit: 50,
      );
      if (!mounted || type != widget.orderType) return;
      setState(() {
        _orders = orders.where((o) => o.paymentStatus != 'paid').toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
    } catch (e) {
      posLog('Could not load running $type orders: $e');
    }
  }

  Future<bool> _parkCurrentCart() async {
    if (context.read<CartProvider>().isEmpty) return true;
    return saveCartWithFeedback(context);
  }

  Future<void> _startNewCustomer() async {
    if (_switching) return;
    setState(() => _switching = true);
    try {
      if (!await _parkCurrentCart() || !mounted) return;
      final cart = context.read<CartProvider>();
      cart.clearItems();
      cart.configureContext(orderType: widget.orderType);
    } finally {
      if (mounted) setState(() => _switching = false);
      unawaited(refresh());
    }
  }

  Future<void> _resume(Order order) async {
    final cart = context.read<CartProvider>();
    if (_switching || cart.openOrderId == order.id) return;
    setState(() => _switching = true);
    try {
      if (!await _parkCurrentCart() || !mounted) return;

      // Re-read so the cart has the latest items from any device.
      final latest = await OrderService().getById(order.id);
      if (!mounted) return;

      cart.configureContext(
        orderType: latest.orderType,
        tableCustomerLabel: latest.tableCustomerLabel,
        openOrderId: latest.id,
      );
      cart.hydrateFromOpenOrder(
        items: latest.items
            .map(
              (oi) => CartItem(
                product: Product(
                  id: oi.productId,
                  name: oi.name,
                  categoryId: '',
                  sellingPrice: oi.price,
                  imageUrl: oi.imageUrl,
                ),
                quantity: oi.quantity,
              ),
            )
            .toList(),
        discount: latest.discount,
        customer: latest.customerId == null
            ? null
            : Customer(
                id: latest.customerId!,
                name: latest.customerName ?? '',
                phone: latest.customerPhone ?? '',
              ),
      );
      if (latest.orderType == 'delivery') {
        cart.deliveryAddress = latest.deliveryInfo?.address ?? '';
        cart.deliveryPhone = latest.deliveryInfo?.phone ?? '';
      }
      cart.notes = latest.notes ?? '';
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that order. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
      unawaited(refresh());
    }
  }

  String _label(Order order) {
    final label = order.tableCustomerLabel?.trim() ?? '';
    final customer = order.customerName?.trim() ?? '';
    final name = label.isNotEmpty ? label : (customer.isNotEmpty ? customer : null);
    return [
      '#${order.orderNumber}',
      if (name != null) name,
      Formatters.currency(order.grandTotal),
    ].join(' · ');
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: onTap == null ? null : (_) => onTap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final isNewOrder = cart.openOrderId == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _orders.isEmpty ? 'Running orders' : 'Running orders (${_orders.length})',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                  label: isNewOrder && !cart.isEmpty ? 'New customer (current)' : 'New customer',
                  icon: Icons.person_add_alt_1_outlined,
                  selected: isNewOrder,
                  onTap: _switching ? null : _startNewCustomer,
                ),
                for (final order in _orders)
                  _chip(
                    label: _label(order),
                    selected: cart.openOrderId == order.id,
                    onTap: _switching ? null : () => _resume(order),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

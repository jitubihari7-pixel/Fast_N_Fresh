import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../pos/direct_order_screen.dart';
import '../tables/table_detail_screen.dart';
import 'order_detail_screen.dart';

/// Opens [order] where the cashier can work on it. A pending (unbilled)
/// Takeaway/Delivery order opens in its order screen with the cart ready to
/// pay, a pending dine-in order opens its table; both end on the bill
/// receipt once paid. Paid bills and QR orders open the bill details.
Future<void> openBill(BuildContext context, Order order) {
  final pending = order.paymentStatus != 'paid' &&
      const ['open', 'preparing', 'ready'].contains(order.status);

  final Widget page;
  if (pending && !order.isQrOrder && (order.orderType == 'takeaway' || order.orderType == 'delivery')) {
    page = DirectOrderScreen(orderType: order.orderType, resumeOrderId: order.id, autoOpenCart: true);
  } else if (pending && !order.isQrOrder && order.orderType == 'dine_in' && order.tableId != null) {
    page = TableDetailScreen(tableId: order.tableId!);
  } else {
    page = OrderDetailScreen(orderId: order.id);
  }
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pwp_pos/models/order.dart';

Map<String, dynamic> orderJson({Object? customer, Map<String, dynamic>? qr}) => {
      '_id': 'o1',
      'orderNumber': 15,
      'items': const [],
      'tableCustomerLabel': 'Customer 1',
      if (customer != null) 'customer': customer,
      if (qr != null) 'qrCustomerContact': qr,
      'createdAt': '2026-10-23T05:58:00.000Z',
    };

void main() {
  test('bill/KOT show the selected customer, not the table label', () {
    final order = Order.fromJson(orderJson(customer: {'_id': 'c1', 'name': 'Raju', 'phone': '1238786358'}));
    expect(order.printCustomerName, 'Raju');
  });

  test('QR order uses the name the customer typed', () {
    final order = Order.fromJson(orderJson(qr: {'name': 'Priya', 'phone': ''}));
    expect(order.printCustomerName, 'Priya');
  });

  test('falls back to the table label when no customer was chosen', () {
    expect(Order.fromJson(orderJson()).printCustomerName, 'Customer 1');
  });

  test('an unpopulated customer id still falls back to the table label', () {
    expect(Order.fromJson(orderJson(customer: 'c1')).printCustomerName, 'Customer 1');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pwp_pos/providers/cart_provider.dart';

void main() {
  test('typed name replaces the automatic table label', () {
    final cart = CartProvider()
      ..configureContext(orderType: 'dine_in', tableCustomerLabel: 'Customer 1');
    expect(cart.effectiveCustomerLabel, 'Customer 1');

    cart.setCustomerNameInput('  Raju ');
    expect(cart.effectiveCustomerLabel, 'Raju');

    cart.setCustomerNameInput('   ');
    expect(cart.effectiveCustomerLabel, 'Customer 1');
  });

  test('takeaway order uses the typed name, or nothing when left blank', () {
    final cart = CartProvider()..configureContext(orderType: 'takeaway');
    expect(cart.effectiveCustomerLabel, isNull);
    cart.setCustomerNameInput('Priya');
    expect(cart.effectiveCustomerLabel, 'Priya');
  });

  test('takeaway/delivery slot keeps its tag in front of the typed name', () {
    final cart = CartProvider()
      ..configureContext(orderType: 'takeaway', tableCustomerLabel: 'T2');
    expect(cart.hasSlot, isTrue);
    expect(cart.effectiveCustomerLabel, 'T2');
    expect(cart.openOrderLabelUpdate, 'T2');

    cart.setCustomerNameInput(' Rahul ');
    expect(cart.effectiveCustomerLabel, 'T2 · Rahul');
    expect(cart.openOrderLabelUpdate, 'T2 · Rahul');

    cart.configureContext(orderType: 'delivery', tableCustomerLabel: 'D11');
    expect(cart.effectiveCustomerLabel, 'D11');
  });

  test('dine-in and plain labels are not treated as slots', () {
    final cart = CartProvider()
      ..configureContext(orderType: 'dine_in', tableCustomerLabel: 'T1');
    expect(cart.hasSlot, isFalse);
    expect(cart.openOrderLabelUpdate, isEmpty);

    cart.configureContext(orderType: 'takeaway', tableCustomerLabel: 'Rahul');
    expect(cart.hasSlot, isFalse);
  });

  test('a typed name does not leak into the next order', () {
    final cart = CartProvider()..setCustomerNameInput('Raju');
    cart.clear();
    expect(cart.customerNameInput, isEmpty);

    cart
      ..setCustomerNameInput('Raju')
      ..configureContext(orderType: 'dine_in', tableCustomerLabel: 'Customer 2');
    expect(cart.effectiveCustomerLabel, 'Customer 2');
  });
}

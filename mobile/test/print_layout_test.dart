import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwp_pos/models/misc_models.dart';
import 'package:pwp_pos/models/order.dart';
import 'package:pwp_pos/services/kot_service.dart';
import 'package:pwp_pos/services/receipt_service.dart';

const longName = 'Double Patty with Double Cheese Burger';
const pizza = 'BBQ Paneer and Onion Pizza (Regular)';

Order order() => Order.fromJson({
      '_id': 'o1',
      'orderNumber': 22,
      'orderType': 'dine_in',
      'tableCustomerLabel': 'Customer 1',
      'items': [
        {'product': 'p1', 'name': pizza, 'price': 199, 'quantity': 1, 'total': 199},
        {'product': 'p2', 'name': longName, 'price': 149, 'quantity': 2, 'total': 298},
        {'product': 'p3', 'name': 'Aloo Tikki Burger', 'price': 49, 'quantity': 1, 'total': 49},
      ],
      'createdAt': '2026-10-23T12:58:00.000Z',
    });

final settings = BusinessSettings(cafeName: 'FAST N FRESH CAFE');

/// Printable text of an ESC/POS job, one entry per printed line.
/// ESC (0x1B) / GS (0x1D) / FS (0x1C) commands and their parameters are dropped.
List<String> printedLines(List<int> bytes) {
  // Parameter byte count after ESC/GS + command letter.
  const escParams = {0x24: 2, 0x61: 1, 0x45: 1, 0x21: 1, 0x4D: 1, 0x2D: 1, 0x74: 1, 0x64: 1, 0x40: 0, 0x47: 1, 0x7B: 1, 0x52: 1, 0x33: 1, 0x32: 0};
  const gsParams = {0x21: 1, 0x56: 1, 0x42: 1, 0x4C: 2, 0x57: 2};
  final text = <int>[];
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    // FS + one command byte (e.g. FS '.' = cancel Kanji mode).
    if (b == 0x1C && i + 1 < bytes.length) {
      i += 1;
      continue;
    }
    if ((b == 0x1B || b == 0x1D) && i + 1 < bytes.length) {
      final params = (b == 0x1B ? escParams : gsParams)[bytes[i + 1]] ?? 0;
      i += 1 + params;
      // GS V 'A'/'B' cut takes an extra feed byte.
      if (b == 0x1D && bytes[i - params] == 0x56 && i < bytes.length && (bytes[i] == 0x41 || bytes[i] == 0x42)) i++;
      continue;
    }
    text.add(b);
  }
  return latin1
      .decode(text, allowInvalid: true)
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[\x00-\x1F]'), '').trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

/// Words of [name] appear, in order, across the printed lines.
bool printsFullName(List<String> lines, String name) {
  final text = lines.join(' ').replaceAll(RegExp(r'\s+'), ' ');
  return text.contains(name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [58.0, 80.0]) {
    test('KOT prints full item names on ${width.toInt()}mm', () async {
      final lines = printedLines(
        await KotService().buildBluetoothTicket(order(), settings, widthMm: width),
      );
      expect(lines.any((l) => l.contains('...')), isFalse, reason: lines.join('\n'));
      expect(printsFullName(lines, pizza), isTrue, reason: lines.join('\n'));
      expect(printsFullName(lines, longName), isTrue, reason: lines.join('\n'));
      expect(lines, contains('FAST N FRESH CAFE'));
    });

    test('customer bill prints full item names on ${width.toInt()}mm', () async {
      final lines = printedLines(
        await ReceiptService().buildThermalTicketBytes(order(), settings, widthMm: width),
      );
      expect(lines.any((l) => l.contains('...')), isFalse, reason: lines.join('\n'));
      // Name wraps inside the ITEM column; qty/amount stay on its first line.
      final first = lines.firstWhere((l) => l.startsWith('Double'));
      expect(first, endsWith('298.00'));
      final itemWords = lines
          .skipWhile((l) => !l.startsWith('BBQ'))
          .takeWhile((l) => !l.startsWith('-'))
          .map((l) => l.replaceAll(RegExp(r'\s+\d+\s+\d+\.\d\d$'), ''))
          .join(' ');
      expect(itemWords.replaceAll(RegExp(r'\s+'), ' '), contains(pizza));
      expect(itemWords.replaceAll(RegExp(r'\s+'), ' '), contains(longName));
    });
  }

  test('58mm KOT cafe name is not double-width (would wrap "E")', () async {
    final bytes = await KotService().buildBluetoothTicket(order(), settings, widthMm: 58);
    // ESC/POS GS ! n sets character size; 0x11 = double width + height.
    final gsBang = <int>[];
    for (var i = 0; i + 2 < bytes.length; i++) {
      if (bytes[i] == 0x1D && bytes[i + 1] == 0x21) gsBang.add(bytes[i + 2]);
    }
    expect(gsBang.contains(0x11), isFalse);
  });
}

import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../theme/app_colors.dart';
import 'formatters.dart';

/// Size variants (e.g. pizzas) are stored as separate products named
/// "<Base> (Regular)" and "<Base> (Large)" -- see backend syncMenu2026.js.
/// The full name (with size) is what reaches the cart, KOT and bill; these
/// helpers only collapse the variants into a single card on the menu grid
/// and ask which size to add.
class ProductSizes {
  ProductSizes._();

  static const _sizeOrder = ['regular', 'large'];
  static final _sizePattern =
      RegExp(r'^(.*\S)\s*\((Regular|Large)\)$', caseSensitive: false);

  static String baseName(Product product) =>
      _sizePattern.firstMatch(product.name.trim())?.group(1) ?? product.name;

  static String? sizeOf(Product product) =>
      _sizePattern.firstMatch(product.name.trim())?.group(2);

  static bool hasSizes(Product product) => sizeOf(product) != null;

  static String _key(Product product) =>
      '${product.categoryId}|${baseName(product).toLowerCase()}';

  /// All size variants of [product] from [catalog], Regular first.
  static List<Product> variantsOf(Product product, List<Product> catalog) {
    if (!hasSizes(product)) return [product];
    final key = _key(product);
    final variants =
        catalog.where((p) => hasSizes(p) && _key(p) == key).toList();
    if (variants.isEmpty) return [product];
    variants.sort((a, b) => _sizeOrder
        .indexOf(sizeOf(a)!.toLowerCase())
        .compareTo(_sizeOrder.indexOf(sizeOf(b)!.toLowerCase())));
    return variants;
  }

  /// Keeps one entry per sized product (the first seen), so each pizza shows
  /// as a single card.
  static List<Product> collapse(List<Product> products) {
    final seen = <String>{};
    return products.where((p) => !hasSizes(p) || seen.add(_key(p))).toList();
  }

  /// "₹129 / ₹229" for sized products, the plain price otherwise.
  static String priceLabel(Product product, List<Product> catalog) =>
      variantsOf(product, catalog)
          .map((p) => Formatters.currency(p.sellingPrice))
          .join(' / ');

  static Set<String> variantIds(Product product, List<Product> catalog) =>
      variantsOf(product, catalog).map((p) => p.id).toSet();

  /// Returns [product] directly when it has no sizes; otherwise asks which
  /// size to add. Returns null if the sheet is dismissed.
  static Future<Product?> pick(
    BuildContext context,
    Product product,
    List<Product> catalog,
  ) async {
    final variants = variantsOf(product, catalog);
    if (variants.length < 2) return product;

    return showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                baseName(product),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose size',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              for (final variant in variants)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SizeOption(
                    product: variant,
                    onTap: () => Navigator.of(sheetContext).pop(variant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SizeOption extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _SizeOption({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = !product.isAvailable ||
        (product.trackInventory && product.stock <= 0);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ProductSizes.sizeOf(product) ?? product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: disabled ? AppColors.textMuted : null,
                  ),
                ),
              ),
              Text(
                disabled
                    ? 'Unavailable'
                    : Formatters.currency(product.sellingPrice),
                style: TextStyle(
                  color: disabled ? AppColors.danger : AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

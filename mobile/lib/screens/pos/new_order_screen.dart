import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fresh_ui.dart';
import '../tables/tables_screen.dart';
import 'direct_order_screen.dart';

/// Entry point for starting any new order.
///
/// Dine-In -> Table selection
/// Takeaway -> POS
/// Delivery -> POS
class NewOrderScreen extends StatelessWidget {
  const NewOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            FreshHeader(
              title: 'New Order',
              showBack: Navigator.of(context).canPop(),
            ),

            const SizedBox(height: 16),

            Text(
              'What type of order is this?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              'Choose how this customer is being served.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // DINE-IN
            // --------------------------------------------------
            _OrderTypeCard(
              icon: Icons.restaurant_rounded,
              title: 'Dine-In',
              subtitle: 'Customer is seated at a table',
              color: FreshUi.mint,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TablesScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // --------------------------------------------------
            // TAKEAWAY
            // --------------------------------------------------
            _OrderTypeCard(
              icon: Icons.shopping_bag_outlined,
              title: 'Takeaway',
              subtitle: 'Customer will pick up the order',
              color: const Color(0xFF3B82F6),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DirectOrderScreen(orderType: 'takeaway'),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // --------------------------------------------------
            // DELIVERY
            // --------------------------------------------------
            _OrderTypeCard(
              icon: Icons.delivery_dining_outlined,
              title: 'Delivery',
              subtitle: 'Order will be delivered to the customer',
              color: FreshUi.amber,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DirectOrderScreen(orderType: 'delivery'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ORDER TYPE CARD
// ============================================================

class _OrderTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OrderTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: FreshUi.card(tint: color),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 22),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 1),

                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: color,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

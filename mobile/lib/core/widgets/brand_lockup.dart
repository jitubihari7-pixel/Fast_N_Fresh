import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Premium, consistent brand lockup used across the staff app.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.compact = false,
    this.showTagline = false,
  });

  final bool compact;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 38.0 : 72.0;
    final titleSize = compact ? 15.0 : 18.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 11 : 18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/app_icon.png',
            fit: BoxFit.cover,
          ),
        ),
        if (!compact) const SizedBox(height: 14),
        if (!compact)
          Text(
            'PWP POS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.7,
              color: AppColors.textPrimary,
            ),
          ),
        if (showTagline && !compact) ...[
          const SizedBox(height: 5),
          Text(
            'PERSONALIZE WEB PAGE • POS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class PWPMark extends StatelessWidget {
  const PWPMark({super.key, this.label = 'PWP'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const Text(
            'G',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

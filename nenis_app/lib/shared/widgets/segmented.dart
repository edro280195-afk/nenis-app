import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';

class SegmentedItem {
  const SegmentedItem({required this.label, this.icon});
  final String label;
  final IconData? icon;
}

class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<SegmentedItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.segTrack,
        borderRadius: BorderRadius.circular(AppRadii.segmented),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final isOn = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 42,
                decoration: BoxDecoration(
                  color: isOn ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    AppRadii.segmentedItem,
                  ),
                  boxShadow: isOn ? AppShadows.small : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (items[i].icon != null) ...[
                      Icon(
                        items[i].icon,
                        size: 18,
                        color: isOn ? AppColors.ink : AppColors.ink2,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      items[i].label,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13.5,
                        color: isOn ? AppColors.ink : AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class TabChip extends StatelessWidget {
  const TabChip({
    super.key,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppColors.ink : const Color(0x0D3A2233),
          borderRadius: AppRadii.pillRadius,
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            fontSize: 13.5,
            color: isActive ? AppColors.surface : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow({super.key, required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.eyebrow(color ?? AppColors.neniDeep),
    );
  }
}

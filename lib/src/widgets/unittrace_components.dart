import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.backgroundColor = AppColors.warmSurface,
    this.borderColor = AppColors.line,
    this.radius = 16,
    this.shadowBlurRadius = 22,
    this.showShadow = true,
    this.gradientOverlay = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;
  final double shadowBlurRadius;
  final bool showShadow;
  final bool gradientOverlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradientOverlay
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  backgroundColor,
                  backgroundColor.withValues(alpha: 0.98),
                ],
                stops: const [0, 0.12, 1],
              )
            : null,
        color: gradientOverlay ? null : backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0x14000000),
                  blurRadius: shadowBlurRadius,
                  offset: Offset(0, 10),
                ),
                const BoxShadow(
                  color: Color(0x0D0D3F3A),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0x00000000)],
            stops: [0.02, 1],
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle case final String subtitleText) ...[
                const SizedBox(height: 3),
                Text(
                  subtitleText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (trailing case final Widget trailingWidget) trailingWidget,
      ],
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.expanded = false,
    this.backgroundColor = Colors.white,
    this.borderColor = AppColors.line,
    this.iconColor = AppColors.deepEmerald,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool expanded;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFFAF6EE)],
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x120D3F3A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
          const BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: AppSpacing.xs + 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );

    if (expanded) {
      return Expanded(child: tile);
    }
    return tile;
  }
}

class TrustPill extends StatelessWidget {
  const TrustPill({
    super.key,
    required this.icon,
    required this.label,
    this.backgroundColor = AppColors.mist,
    this.iconColor = AppColors.deepEmerald,
    this.textColor = AppColors.deepEmerald,
    this.borderColor = AppColors.hairline,
    this.emphasis,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final Color borderColor;
  final bool? emphasis;

  @override
  Widget build(BuildContext context) {
    final isVerified = emphasis ?? false;
    final surfaceColor = isVerified ? AppColors.brassSoft : backgroundColor;
    final labelTextColor = isVerified ? AppColors.graphite : textColor;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0D3F3A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isVerified ? AppColors.brass : iconColor),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            isVerified ? label.toUpperCase() : label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: labelTextColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStatePanel extends StatelessWidget {
  const EmptyStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.backgroundColor = AppColors.warmSurface,
    this.borderColor = AppColors.line,
    this.iconColor = AppColors.deepEmerald,
    this.iconBackgroundColor = AppColors.mist,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color iconBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return Surface(
      padding: padding,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final PreferredSizeWidget? bottom;
  const GradientHeader({super.key, required this.title, this.subtitle, this.trailing, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.teal, AppColors.tealDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (bottom != null) ...[const SizedBox(height: 12), bottom!],
            ],
          ),
        ),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  const StatusBadge({super.key, required this.label});

  Color get _bg {
    switch (label.toLowerCase()) {
      case 'actif':
      case 'validée':
      case 'permanent':
        return AppColors.success.withOpacity(0.12);
      case 'suspendu':
      case 'rejetée':
        return AppColors.danger.withOpacity(0.12);
      case 'en attente':
      case 'vacataire':
        return AppColors.info.withOpacity(0.12);
      default:
        return AppColors.textMuted.withOpacity(0.12);
    }
  }

  Color get _fg {
    switch (label.toLowerCase()) {
      case 'actif':
      case 'validée':
      case 'permanent':
        return AppColors.success;
      case 'suspendu':
      case 'rejetée':
        return AppColors.danger;
      case 'en attente':
      case 'vacataire':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: _fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class Avatar extends StatelessWidget {
  final String initials;
  final Color? color;
  final double size;
  const Avatar({super.key, required this.initials, this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.teal;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: c.withOpacity(0.15), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials.toUpperCase(),
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: size * 0.38)),
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      padding: padding,
      child: child,
    );
  }
}

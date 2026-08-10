import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';

class PresenceScreen extends StatelessWidget {
  const PresenceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        GradientHeader(
            title: 'Présence', subtitle: 'Suivi des présences en cours'),
        Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Module de présence bientôt disponible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMutedLight)),
            ),
          ),
        ),
      ],
    );
  }
}


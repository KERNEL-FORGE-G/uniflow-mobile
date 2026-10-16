import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../widgets/common.dart';
import '../widgets/phosphor.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Centre d\'aide', subtitle: 'Support et documentation UniFlow'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  child: Column(
                    children: [
                      _buildHelpItem(context, PhosphorIconsDuotone.question, 'Guide de démarrage',
                          'Apprenez à utiliser les fonctions de base'),
                      const Divider(),
                      _buildHelpItem(context, PhosphorIconsDuotone.qrCode, 'Comment scanner ma présence ?',
                          'Astuces pour un émargement réussi'),
                      const Divider(),
                      _buildHelpItem(context, PhosphorIconsDuotone.shieldCheck, 'Sécurité des données',
                          'Comment vos données sont protégées'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Besoin d\'assistance ?'),
                // Le bouton annonçait « support@kernelforge.codes », une
                // adresse qui n'existe pas : le support passe par le WhatsApp
                // et le courriel officiels, les mêmes que sur le web.
                PrimaryButton(
                  label: 'Écrire sur WhatsApp ($contactPhoneDisplay)',
                  icon: PhosphorIconsFill.whatsappLogo,
                  onPressed: () => _ouvrir(
                    context,
                    '$contactWhatsappUrl?text=${Uri.encodeComponent('Bonjour KERNEL FORGE, j’ai besoin d’aide sur l’application mobile UniFlow.')}',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      _ouvrir(context, '$contactMailUrl?subject=${Uri.encodeComponent('Support UniFlow mobile')}'),
                  icon: const PhosphorIcon(PhosphorIconsBold.envelope),
                  label: const Text('Par courriel · $contactEmail', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(BuildContext context, IconData icon, String title, String desc) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: PhosphorIcon(icon, color: AppColors.primaryBlue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
      trailing: const PhosphorIcon(PhosphorIconsBold.caretRight, size: 18),
      onTap: () {},
    );
  }

  Future<void> _ouvrir(BuildContext context, String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucune application ne peut ouvrir ce lien. Contact : $contactPhoneDisplay · $contactEmail')),
      );
    }
  }
}

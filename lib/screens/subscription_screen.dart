import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../services/flutterwave_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/phosphor.dart';

/// Écran complet de gestion des abonnements et paiements Flutterwave.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isAnnual = false;
  String _selectedPlanCode = 'PRO_STUDENT';

  void _openPaymentSheet(SubscriptionPlanInfo plan) {
    if (plan.monthlyAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette formule académique standard est déjà active sur votre compte.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaymentModalSheet(
        plan: plan,
        isAnnual: _isAnnual,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final service = ref.watch(flutterwaveServiceProvider);
    final plans = service.getAvailablePlans();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            GradientHeader(
              title: 'Abonnements & Pro',
              subtitle: 'Propulsé par la passerelle Flutterwave',
              leading: IconButton(
                icon: const PhosphorIcon(PhosphorIconsBold.arrowLeft, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // ── Carte Statut Actuel ──
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: PhosphorIcon(PhosphorIconsFill.crown, color: Color(0xFFFBBF24), size: 26),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Compte Utilisateur',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Formule active : Étudiant Campus (Standard)',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Actif',
                            style: TextStyle(
                              color: Color(0xFF0D9488),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Bascule Mensuel / Annuel ──
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isAnnual = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isAnnual ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: !_isAnnual
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Mensuel',
                                style: TextStyle(
                                  color: !_isAnnual ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _isAnnual = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isAnnual ? const Color(0xFF1E3A8A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: _isAnnual
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Annuel',
                                    style: TextStyle(
                                      color: _isAnnual ? Colors.white : const Color(0xFF64748B),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _isAnnual ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      '-17%',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Liste des Formules ──
                  for (final plan in plans) ...[
                    _PlanCard(
                      plan: plan,
                      isAnnual: _isAnnual,
                      isSelected: _selectedPlanCode == plan.code,
                      onTap: () {
                        setState(() => _selectedPlanCode = plan.code);
                        _openPaymentSheet(plan);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Note de Sécurité Flutterwave ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        PhosphorIcon(PhosphorIconsDuotone.shieldCheck, color: Color(0xFF0D9488), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Paiements cryptés et certifiés PCI-DSS via Flutterwave. '
                            'Supporte Orange Money, MTN MoMo, Visa et Mastercard.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte présentant une formule d'abonnement.
class _PlanCard extends StatelessWidget {
  final SubscriptionPlanInfo plan;
  final bool isAnnual;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isAnnual,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = isAnnual ? plan.annualAmount : plan.monthlyAmount;
    final period = isAnnual ? '/ an' : '/ mois';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.isPopular ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
          width: plan.isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: plan.isPopular
                ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: const BoxDecoration(
                color: Color(0xFF0D9488),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: const Text(
                'RECOMMANDÉ POUR RÉUSSIR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (price == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'INCLUS',
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plan.description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price == 0 ? 'Gratuit' : '$price ${plan.currency}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    if (price > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        period,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                for (final feat in plan.features) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PhosphorIcon(
                          PhosphorIconsFill.checkCircle,
                          color: Color(0xFF0D9488),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feat,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.isPopular ? const Color(0xFF1E3A8A) : const Color(0xFFF1F5F9),
                      foregroundColor: plan.isPopular ? Colors.white : const Color(0xFF1E3A8A),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      price == 0 ? 'Utiliser la formule' : 'Choisir cette formule →',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Feuille modale de règlement Flutterwave (Orange Money, MoMo, Carte).
class _PaymentModalSheet extends ConsumerStatefulWidget {
  final SubscriptionPlanInfo plan;
  final bool isAnnual;

  const _PaymentModalSheet({
    required this.plan,
    required this.isAnnual,
  });

  @override
  ConsumerState<_PaymentModalSheet> createState() => _PaymentModalSheetState();
}

class _PaymentModalSheetState extends ConsumerState<_PaymentModalSheet> {
  FlutterwavePaymentMethod _method = FlutterwavePaymentMethod.orangeMoney;
  final _phoneController = TextEditingController(text: '+237 6');
  final _cardController = TextEditingController(text: '4111 2222 3333 4444');
  final _expController = TextEditingController(text: '12/28');
  final _cvvController = TextEditingController(text: '123');

  bool _loading = false;
  String? _successMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _cardController.dispose();
    _expController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _payDirect() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final service = ref.read(flutterwaveServiceProvider);

    setState(() => _loading = true);

    try {
      if (_method == FlutterwavePaymentMethod.card) {
        final res = await service.processCardDirect(
          plan: widget.plan,
          isAnnual: widget.isAnnual,
          user: user,
          cardNumber: _cardController.text.trim(),
          expiryDate: _expController.text.trim(),
          cvv: _cvvController.text.trim(),
        );
        setState(() => _successMessage = res.message);
      } else {
        final res = await service.processMobileMoneyDirect(
          plan: widget.plan,
          isAnnual: widget.isAnnual,
          user: user,
          phoneNumber: _phoneController.text.trim(),
          method: _method,
        );
        setState(() => _successMessage = res.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur paiement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payViaWebCheckout() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final service = ref.read(flutterwaveServiceProvider);

    setState(() => _loading = true);
    await service.openHostedPayment(
      plan: widget.plan,
      isAnnual: widget.isAnnual,
      user: user,
      phoneNumber: _phoneController.text.trim(),
    );
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.isAnnual ? widget.plan.annualAmount : widget.plan.monthlyAmount;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paiement Flutterwave',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '${widget.plan.name} · $amount ${widget.plan.currency}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0D9488), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const PhosphorIcon(PhosphorIconsBold.x, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                children: [
                  const PhosphorIcon(PhosphorIconsFill.checkCircle, color: Color(0xFF16A34A), size: 40),
                  const SizedBox(height: 10),
                  Text(
                    _successMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Fermer et retourner'),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Sélecteur de méthode
            Row(
              children: [
                _MethodPill(
                  label: 'Orange Money',
                  icon: PhosphorIconsFill.deviceMobile,
                  selected: _method == FlutterwavePaymentMethod.orangeMoney,
                  onTap: () => setState(() => _method = FlutterwavePaymentMethod.orangeMoney),
                ),
                const SizedBox(width: 8),
                _MethodPill(
                  label: 'MTN MoMo',
                  icon: PhosphorIconsFill.deviceMobile,
                  selected: _method == FlutterwavePaymentMethod.mtnMomo,
                  onTap: () => setState(() => _method = FlutterwavePaymentMethod.mtnMomo),
                ),
                const SizedBox(width: 8),
                _MethodPill(
                  label: 'Carte Bancaire',
                  icon: PhosphorIconsFill.creditCard,
                  selected: _method == FlutterwavePaymentMethod.card,
                  onTap: () => setState(() => _method = FlutterwavePaymentMethod.card),
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (_method != FlutterwavePaymentMethod.card) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone mobile money',
                  hintText: '+237 6...',
                  prefixIcon: const PhosphorIcon(PhosphorIconsBold.deviceMobile),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ] else ...[
              TextField(
                controller: _cardController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Numéro de carte Visa / Mastercard',
                  prefixIcon: const PhosphorIcon(PhosphorIconsBold.creditCard),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expController,
                      decoration: InputDecoration(
                        labelText: 'Exp (MM/AA)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _cvvController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _payDirect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Payer $amount ${widget.plan.currency} via Flutterwave',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: TextButton.icon(
                onPressed: _loading ? null : _payViaWebCheckout,
                icon: const PhosphorIcon(PhosphorIconsBold.arrowSquareOut, size: 16),
                label: const Text(
                  'Ouvrir le guichet web sécurisé Flutterwave',
                  style: TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w700),
                ),
              ),
            ),

            const SizedBox(height: 4),

            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;
                  await ref.read(flutterwaveServiceProvider).openWhatsAppBilling(
                    plan: widget.plan,
                    isAnnual: widget.isAnnual,
                    user: user,
                  );
                },
                icon: const PhosphorIcon(PhosphorIconsFill.whatsappLogo, color: Color(0xFF16A34A), size: 18),
                label: const Text(
                  'Payer par WhatsApp (+237 657 635 644)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodPill extends StatelessWidget {
  final String label;
  final PhosphorIconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                icon,
                size: 20,
                color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/theme/navia_tokens.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/navia_buttons.dart';
import 'widgets/fuel_prices_section.dart';

/// The daily fuel prices, downloaded on their own: they cover all of Italy
/// and have nothing to do with the zones of the offline maps.
class FuelPricesScreen extends StatelessWidget {
  const FuelPricesScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const FuelPricesScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const NaviaBackButton(),
        title: const Text(AppStrings.fuelPricesScreen),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                NaviaSpacing.lg,
                NaviaSpacing.sm,
                NaviaSpacing.lg,
                NaviaSpacing.xxl,
              ),
              children: const [FuelDataCard()],
            ),
          ),
        ),
      ),
    );
  }
}

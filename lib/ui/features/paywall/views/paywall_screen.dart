import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../subscription/views/premium_paywall_sheet.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PremiumPaywallSheet(isFullPage: true);
  }
}

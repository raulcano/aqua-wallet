import 'package:aqua/features/shared/shared.dart';

class DebitCardOnboardingScreen extends StatelessWidget {
  const DebitCardOnboardingScreen({super.key});

  static const routeName = '/debitCardOnboardingScreen';

  @override
  Widget build(BuildContext context) => const _DebitCardPlaceholderScaffold(
        title: 'Debit Card Onboarding',
      );
}

class DebitCardMyCardScreen extends StatelessWidget {
  const DebitCardMyCardScreen({super.key});

  static const routeName = '/debitCardMyCardScreen';

  @override
  Widget build(BuildContext context) =>
      const _DebitCardPlaceholderScaffold(title: 'Debit Card');
}

class DebitCardTopUpScreen extends StatelessWidget {
  const DebitCardTopUpScreen({super.key});

  static const routeName = '/debitCardTopUpScreen';

  @override
  Widget build(BuildContext context) =>
      const _DebitCardPlaceholderScaffold(title: 'Top Up Card');
}

class DebitCardStyleSelectionScreen extends StatelessWidget {
  const DebitCardStyleSelectionScreen({super.key});

  static const routeName = '/debitCardStyleSelectionScreen';

  @override
  Widget build(BuildContext context) =>
      const _DebitCardPlaceholderScaffold(title: 'Card Style');
}

class _DebitCardPlaceholderScaffold extends StatelessWidget {
  const _DebitCardPlaceholderScaffold({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text('Feature unavailable in this build'),
      ),
    );
  }
}

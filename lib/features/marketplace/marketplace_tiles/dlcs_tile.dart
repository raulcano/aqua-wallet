import 'package:aqua/features/dlc/dlc.dart';
import 'package:aqua/features/marketplace/widgets/marketplace_tile.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:ui_components/ui_components.dart';

class DlcsTile extends StatelessWidget {
  const DlcsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return MarketplaceTile(
      title: 'DLCs',
      subtitle: 'Bitcoin PUT and CALL options via DLCs',
      iconBuilder: ({color, required size}) =>
          AquaIcon.chart(color: color, size: size),
      onPressed: () => context.push(DlcScreen.routeName),
    );
  }
}

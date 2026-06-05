import 'dart:convert';
import 'dart:typed_data';

import 'package:aqua/features/dlc/utils/dlc_explorer_utils.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DlcExplorerScreenArgs {
  const DlcExplorerScreenArgs({
    required this.dashboardUrl,
    required this.walletToken,
    required this.dlcId,
  });

  final String dashboardUrl;
  final String walletToken;
  final String dlcId;
}

class DlcExplorerScreen extends HookWidget {
  const DlcExplorerScreen({super.key, required this.args});

  static const routeName = '/dlc-explorer';

  final DlcExplorerScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(true);

    final controller = useMemoized(
      () => WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => isLoading.value = false,
            onWebResourceError: (_) => isLoading.value = false,
          ),
        ),
      [args.dashboardUrl, args.walletToken, args.dlcId],
    );

    useEffect(() {
      final body = buildDlcExplorerPostBody(
        walletToken: args.walletToken,
        dlcId: args.dlcId,
      );
      controller.loadRequest(
        Uri.parse(args.dashboardUrl),
        method: LoadRequestMethod.post,
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: Uint8List.fromList(utf8.encode(body)),
      );
      return null;
    }, [controller, args.dashboardUrl, args.walletToken, args.dlcId]);

    return Scaffold(
      appBar: const AquaAppBar(
        title: 'DLC Explorer',
        showActionButton: false,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading.value)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

void openDlcExplorerScreen(
  BuildContext context, {
  required String dashboardUrl,
  required String walletToken,
  required String dlcId,
}) {
  context.push(
    DlcExplorerScreen.routeName,
    extra: DlcExplorerScreenArgs(
      dashboardUrl: dashboardUrl,
      walletToken: walletToken,
      dlcId: dlcId,
    ),
  );
}

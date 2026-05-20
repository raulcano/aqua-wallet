import 'dart:async';

import 'package:aqua/data/data.dart';
import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/models/dlc_trade_models.dart';
import 'package:aqua/features/dlc/services/dlc_api_exception.dart';
import 'package:aqua/features/dlc/services/dlc_negotiation_utils.dart';
import 'package:aqua/features/dlc/services/dlc_repository.dart';
import 'package:aqua/features/dlc/utils/dlc_instrument_utils.dart';
import 'package:aqua/features/dlc/utils/dlc_orderbook_utils.dart';
import 'package:aqua/features/dlc/utils/dlc_order_utils.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:aqua/features/wallet/wallet.dart';

class DlcState {
  const DlcState({
    this.activeWalletId,
    this.activeWalletName,
    this.auth,
    this.readiness,
    this.coordinatorHint,
    this.instruments = const <DlcInstrument>[],
    this.orders = const <DlcOrder>[],
    this.balances,
    this.isLoading = false,
    this.actionInProgress = false,
    this.selectedTabIndex = 0,
    this.errorMessage,
    this.infoMessage,
    this.optionRight = 'C',
    this.templateInstrumentId,
    this.selectedStrike,
    this.suggestedStrikes = const [],
    this.btcUsdSpot,
    this.strikeOrderbooks = const [],
    this.isLoadingTradeData = false,
    this.payoutSimulation,
    this.isSimulating = false,
    this.simulationRole = 'maker',
    this.createSide = 'buy',
    this.walletPnlSats,
    this.createOrderMatchIntent = false,
    this.processingOrder = false,
  });

  final String? activeWalletId;
  final String? activeWalletName;
  final DlcWalletAuth? auth;
  final DlcSystemReadiness? readiness;
  final String? coordinatorHint;
  final List<DlcInstrument> instruments;
  final List<DlcOrder> orders;
  final DlcWalletSyncResult? balances;
  final bool isLoading;
  final bool actionInProgress;
  final int selectedTabIndex;
  final String? errorMessage;
  final String? infoMessage;
  final String createSide;
  final String optionRight;
  final String? templateInstrumentId;
  final num? selectedStrike;
  final List<num> suggestedStrikes;
  final num? btcUsdSpot;
  final List<DlcStrikeOrderbookSnapshot> strikeOrderbooks;
  final bool isLoadingTradeData;
  final DlcOptionPayoutSimulationResult? payoutSimulation;
  final bool isSimulating;
  final String simulationRole;
  final num? walletPnlSats;
  final bool createOrderMatchIntent;
  final bool processingOrder;

  bool get isRegistered =>
      auth != null && auth!.walletToken.isNotEmpty && !auth!.isExpired;

  bool get isTradingBlocked {
    final hint = coordinatorHint?.toLowerCase() ?? '';
    if (hint.isEmpty) {
      return false;
    }
    return hint.contains('mismatch') ||
        hint.contains('regtest') ||
        (hint.contains('testnet') && hint.contains('mainnet'));
  }

  ({int open, int live, int closed}) get orderCounts =>
      countDlcOrdersBySection(orders);

  DlcState copyWith({
    String? activeWalletId,
    String? activeWalletName,
    DlcWalletAuth? auth,
    DlcSystemReadiness? readiness,
    String? coordinatorHint,
    List<DlcInstrument>? instruments,
    List<DlcOrder>? orders,
    DlcWalletSyncResult? balances,
    bool? isLoading,
    bool? actionInProgress,
    int? selectedTabIndex,
    String? errorMessage,
    String? createSide,
    String? infoMessage,
    String? optionRight,
    String? templateInstrumentId,
    num? selectedStrike,
    List<num>? suggestedStrikes,
    num? btcUsdSpot,
    List<DlcStrikeOrderbookSnapshot>? strikeOrderbooks,
    bool? isLoadingTradeData,
    DlcOptionPayoutSimulationResult? payoutSimulation,
    bool? isSimulating,
    String? simulationRole,
    num? walletPnlSats,
    bool? createOrderMatchIntent,
    bool? processingOrder,
    bool clearError = false,
    bool clearInfo = false,
    bool clearPayoutSimulation = false,
    bool clearWalletPnl = false,
    bool clearCreateOrderMatchIntent = false,
  }) {
    return DlcState(
      activeWalletId: activeWalletId ?? this.activeWalletId,
      activeWalletName: activeWalletName ?? this.activeWalletName,
      auth: auth ?? this.auth,
      readiness: readiness ?? this.readiness,
      coordinatorHint: coordinatorHint ?? this.coordinatorHint,
      instruments: instruments ?? this.instruments,
      orders: orders ?? this.orders,
      balances: balances ?? this.balances,
      isLoading: isLoading ?? this.isLoading,
      actionInProgress: actionInProgress ?? this.actionInProgress,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createSide: createSide ?? this.createSide,
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      optionRight: optionRight ?? this.optionRight,
      templateInstrumentId:
          templateInstrumentId ?? this.templateInstrumentId,
      selectedStrike: selectedStrike ?? this.selectedStrike,
      suggestedStrikes: suggestedStrikes ?? this.suggestedStrikes,
      btcUsdSpot: btcUsdSpot ?? this.btcUsdSpot,
      strikeOrderbooks: strikeOrderbooks ?? this.strikeOrderbooks,
      isLoadingTradeData: isLoadingTradeData ?? this.isLoadingTradeData,
      payoutSimulation: clearPayoutSimulation
          ? null
          : (payoutSimulation ?? this.payoutSimulation),
      isSimulating: isSimulating ?? this.isSimulating,
      simulationRole: simulationRole ?? this.simulationRole,
      walletPnlSats: clearWalletPnl ? null : (walletPnlSats ?? this.walletPnlSats),
      createOrderMatchIntent: clearCreateOrderMatchIntent
          ? false
          : (createOrderMatchIntent ?? this.createOrderMatchIntent),
      processingOrder: processingOrder ?? this.processingOrder,
    );
  }

  List<DlcInstrument> get tradeInstruments =>
      dlcFilterInstrumentsByOptionRight(instruments, optionRight);

  String? get resolvedInstrumentId {
    final template = templateInstrumentId;
    final strike = selectedStrike;
    if (template == null) {
      return null;
    }
    if (!dlcInstrumentHasStrikePlaceholder(template)) {
      return template;
    }
    if (strike == null) {
      return null;
    }
    return dlcResolveInstrumentId(
      templateOrId: template,
      strikeToken: dlcNormalizeStrikeToken(strike),
      instruments: instruments,
      allowUnresolvedInCatalog: true,
    );
  }
}

class DlcNotifier extends StateNotifier<DlcState> {
  DlcNotifier(this._ref) : super(const DlcState()) {
    _ref.listen(storedWalletsProvider, (previous, next) {
      final previousId = previous?.valueOrNull?.currentWallet?.id;
      final nextId = next.valueOrNull?.currentWallet?.id;
      if (previousId != nextId) {
        unawaited(_onActiveWalletChanged(next.valueOrNull?.currentWallet));
      }
    }, fireImmediately: true);
  }

  final Ref _ref;
  int _sessionGeneration = 0;
  Timer? _pollTimer;

  DlcRepository get _repository => _ref.read(dlcRepositoryProvider);

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _onActiveWalletChanged(StoredWallet? wallet) async {
    _pollTimer?.cancel();
    final generation = ++_sessionGeneration;

    if (wallet == null) {
      state = const DlcState();
      return;
    }

    state = DlcState(
      activeWalletId: wallet.id,
      activeWalletName: wallet.name,
      isLoading: true,
    );

    try {
      await _ref.read(subaccountsProvider.notifier).loadSubaccounts();
      if (generation != _sessionGeneration) return;

      await _reloadWalletData(wallet);
      if (generation != _sessionGeneration) return;

      _configurePolling(generation);
    } catch (e) {
      if (generation != _sessionGeneration) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: readDlcApiErrorMessage(e),
      );
    }
  }

  void _configurePolling(int generation) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (generation != _sessionGeneration || !state.isRegistered) {
        return;
      }
      unawaited(_backgroundRefresh(showProcessing: false));
    });
  }

  Future<void> _reloadWalletData(StoredWallet wallet) async {
    final mnemonic = await _loadMnemonic(wallet.id);
    final readiness = await _repository.getSystemReadiness();
    final networkHint = _repository.networkMismatchHint(readiness);
    final config = _ref.read(dlcConfigProvider);
    final hints = <String>[
      if (config.partnerToken.isEmpty)
        'DLC partner token is not configured in .env',
      if (!readiness.tradingReady && readiness.blockers.isNotEmpty)
        readiness.blockers.join(', '),
      if (!readiness.chainBackendOk)
        readiness.chainBackendError ?? 'Coordinator chain backend is unhealthy',
      if (networkHint != null) networkHint,
    ];

    try {
      final partnerConfig = await _repository.getPartnerConfig();
      if (partnerConfig != null && !partnerConfig.tokenValid) {
        hints.add('Partner token is invalid or expired on the coordinator');
      }
    } on DlcApiException catch (e) {
      if (isDlcPartnerConfigError(e)) {
        hints.add('Partner token rejected by coordinator (${e.message})');
      }
    }

    var auth = await _repository.loadAuth(wallet.id);
    DlcWalletSyncResult? balances;
    List<DlcOrder> orders = const [];
    List<DlcInstrument> instruments = const [];

    if (auth != null && !auth.isExpired) {
      auth = await _repository.validateStoredAuth(auth);
    }

    if (auth != null && !auth.isExpired) {
      try {
        balances = await _repository.syncWalletUtxos(
          auth: auth,
          mnemonic: mnemonic,
        );
        orders = await _repository.listOrders(
          auth,
          enrichSettlement: true,
        );
        instruments = await _repository.listInstruments(auth.walletToken);
        await _repository.runNegotiationPass(auth: auth, mnemonic: mnemonic);
        orders = await _repository.listOrders(
          auth,
          enrichSettlement: true,
        );
      } on DlcApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          await _repository.clearAuth(wallet.id);
          auth = null;
        } else {
          rethrow;
        }
      }
    } else if (auth != null && auth.isExpired) {
      await _repository.clearAuth(wallet.id);
      auth = null;
    }

    instruments = await _repository.listInstruments(auth?.walletToken);

    num? walletPnl;
    if (auth != null && !auth.isExpired) {
      final spot = state.btcUsdSpot ?? await _repository.fetchBtcUsdSpotPrice();
      if (spot != null && orders.isNotEmpty) {
        walletPnl = await _repository.estimateWalletPnlSats(
          auth: auth,
          orders: orders,
          outcomePrice: spot,
        );
      }
    }

    final tradeDefaults = _initialTradeUi(instruments);

    state = state.copyWith(
      isLoading: false,
      auth: auth,
      readiness: readiness,
      coordinatorHint: hints.isEmpty ? null : hints.join('\n'),
      instruments: instruments,
      orders: orders,
      balances: balances,
      clearError: true,
      infoMessage: auth == null
          ? 'Activate your wallet on Overview to trade and sync coordinator balances.'
          : null,
      templateInstrumentId: tradeDefaults.templateInstrumentId,
      selectedStrike: tradeDefaults.selectedStrike,
      suggestedStrikes: tradeDefaults.suggestedStrikes,
      btcUsdSpot: tradeDefaults.btcUsdSpot,
      walletPnlSats: walletPnl,
    );

    if (auth != null &&
        state.selectedTabIndex == 1 &&
        tradeDefaults.templateInstrumentId != null) {
      unawaited(refreshTradeData());
    }
  }

  void clearTransientMessages() {
    state = state.copyWith(clearError: true, clearInfo: true);
  }

  void setTab(int index) {
    if (index < 0 || index > 3) {
      return;
    }
    state = state.copyWith(selectedTabIndex: index);
    if (index == 1) {
      unawaited(refreshTradeData());
    }
  }

  void setCreateSide(String side) {
    state = state.copyWith(createSide: side.toLowerCase());
  }

  Future<void> refreshCurrentTab() async {
    switch (state.selectedTabIndex) {
      case 0:
        await refreshOverviewTab();
      case 1:
        await refreshTradeData();
      case 2:
        await refreshOrdersTab();
      case 3:
        break;
    }
  }

  Future<void> refreshOverviewTab() async {
    final walletId = state.activeWalletId;
    if (walletId == null) {
      return;
    }
    final wallet = _ref.read(currentWalletProvider);
    if (wallet == null) {
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _reloadWalletData(wallet);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: readDlcApiErrorMessage(e),
      );
    }
  }

  Future<void> refreshOrdersTab() async {
    final auth = state.auth;
    final walletId = state.activeWalletId;
    if (auth == null || walletId == null) {
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final mnemonic = await _loadMnemonic(walletId);
      await _repository.runNegotiationPass(auth: auth, mnemonic: mnemonic);
      final orders = await _repository.listOrders(
        auth,
        enrichSettlement: true,
      );
      final balances = await _repository.syncWalletUtxos(
        auth: auth,
        mnemonic: mnemonic,
      );
      state = state.copyWith(
        isLoading: false,
        orders: orders,
        balances: balances,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: readDlcApiErrorMessage(e),
      );
    }
  }

  void applyCreateOrderFromDepth({
    required num strike,
    required String side,
    required num quantity,
    required num? premiumSats,
  }) {
    state = state.copyWith(
      selectedStrike: strike,
      createSide: side.toLowerCase(),
      createOrderMatchIntent: true,
      clearPayoutSimulation: true,
    );
  }

  ({String? templateInstrumentId, num? selectedStrike, List<num> suggestedStrikes, num? btcUsdSpot})
      _initialTradeUi(List<DlcInstrument> instruments) {
    final template = dlcPickDefaultTemplateInstrument(
      instruments,
      optionRight: state.optionRight,
    );
    return (
      templateInstrumentId: template?.instrumentId,
      selectedStrike: null,
      suggestedStrikes: const [],
      btcUsdSpot: null,
    );
  }

  void setOptionRight(String optionRight) {
    final normalized = optionRight.toUpperCase();
    final template = dlcPickDefaultTemplateInstrument(
      state.instruments,
      optionRight: normalized,
    );
    state = state.copyWith(
      optionRight: normalized,
      templateInstrumentId: template?.instrumentId,
      selectedStrike: null,
      strikeOrderbooks: const [],
      clearPayoutSimulation: true,
    );
    if (template != null) {
      unawaited(refreshTradeData());
    }
  }

  void setTemplateInstrumentId(String? templateInstrumentId) {
    state = state.copyWith(
      templateInstrumentId: templateInstrumentId,
      selectedStrike: null,
      strikeOrderbooks: const [],
      clearPayoutSimulation: true,
    );
    if (templateInstrumentId != null) {
      unawaited(refreshTradeData());
    }
  }

  void setSelectedStrike(num? strike) {
    state = state.copyWith(
      selectedStrike: strike,
      clearPayoutSimulation: true,
    );
    if (strike == null ||
        !state.isRegistered ||
        state.templateInstrumentId == null) {
      return;
    }
    final alreadyLoaded = state.strikeOrderbooks.any(
      (book) => book.strike == strike && !book.hasError,
    );
    if (!alreadyLoaded) {
      unawaited(_refreshOrderbooksOnly());
    }
  }

  void setSimulationRole(String role) {
    state = state.copyWith(simulationRole: role);
  }

  Future<void> refreshTradeData() async {
    state = state.copyWith(isLoadingTradeData: true, clearError: true);
    try {
      final spot = await _repository.fetchBtcUsdSpotPrice();
      final strikes = spot != null ? buildSuggestedStrikePrices(spot) : <num>[];
      var selectedStrike = state.selectedStrike;
      if (selectedStrike == null && strikes.isNotEmpty) {
        selectedStrike = strikes[strikes.length ~/ 2];
      }
      state = state.copyWith(
        btcUsdSpot: spot,
        suggestedStrikes: strikes,
        selectedStrike: selectedStrike,
        isLoadingTradeData: true,
      );
      final template = state.templateInstrumentId;
      if (template != null && strikes.isNotEmpty) {
        final books = await _repository.fetchStrikeOrderbooks(
          templateInstrumentId: template,
          strikes: strikes,
          walletToken: state.auth?.walletToken,
        );
        state = state.copyWith(
          isLoadingTradeData: false,
          strikeOrderbooks: books,
          clearError: true,
        );
      } else {
        state = state.copyWith(isLoadingTradeData: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingTradeData: false,
        errorMessage: readDlcApiErrorMessage(e),
      );
    }
  }

  Future<void> _refreshOrderbooksOnly() async {
    final template = state.templateInstrumentId;
    final strike = state.selectedStrike;
    final auth = state.auth;
    if (template == null || strike == null || auth == null) {
      state = state.copyWith(
        isLoadingTradeData: false,
        strikeOrderbooks: const [],
      );
      return;
    }

    state = state.copyWith(isLoadingTradeData: true);
    try {
      final books = await _repository.fetchStrikeOrderbooks(
        templateInstrumentId: template,
        strikes: [strike],
        walletToken: auth.walletToken,
      );
      final merged = [
        ...state.strikeOrderbooks.where((book) => book.strike != strike),
        ...books,
      ]..sort((a, b) => a.strike.compareTo(b.strike));
      state = state.copyWith(
        isLoadingTradeData: false,
        strikeOrderbooks: merged,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTradeData: false,
        errorMessage: readDlcApiErrorMessage(e),
      );
    }
  }

  Future<void> runPayoutSimulation({
    required String side,
    required String role,
    required String optionRight,
    required num quantity,
    required num strike,
    required num premiumPerContractSats,
    required num outcomePrice,
    num networkFeeSats = 0,
  }) async {
    final auth = state.auth;
    if (auth == null) {
      state = state.copyWith(
        errorMessage:
            'Activate your wallet on Overview to run coordinator simulation.',
      );
      return;
    }

    state = state.copyWith(isSimulating: true, clearError: true);
    try {
      final result = await _repository.simulateOptionPayout(
        auth: auth,
        request: DlcOptionPayoutSimulationRequest(
          side: side,
          role: role,
          optionRight: optionRight.toUpperCase(),
          numContracts: quantity,
          strike: strike,
          premiumPerContractSats: premiumPerContractSats,
          outcomePrice: outcomePrice,
          networkFeeSats: networkFeeSats,
          premiumPaidUpfront: true,
        ),
      );
      state = state.copyWith(
        isSimulating: false,
        payoutSimulation: result,
        infoMessage: 'Payout simulation updated',
      );
    } catch (e) {
      state = state.copyWith(
        isSimulating: false,
        errorMessage: readDlcApiErrorMessage(e),
      );
    }
  }

  Future<String> _loadMnemonic(String walletId) async {
    final (mnemonic, err) = await _ref
        .read(secureStorageProvider)
        .get(StorageKeys.mnemonic(walletId));
    if (err != null || mnemonic == null || mnemonic.isEmpty) {
      throw StateError('Could not load wallet keys for DLC operations');
    }
    return mnemonic;
  }

  Future<void> registerActiveWallet() async {
    final walletId = state.activeWalletId;
    final walletName = state.activeWalletName;
    if (walletId == null || walletName == null) {
      return;
    }
    state = state.copyWith(actionInProgress: true, clearError: true);
    try {
      final mnemonic = await _loadMnemonic(walletId);
      final auth = await _repository.registerWallet(
        walletOriginId: walletId,
        walletLabel: walletName,
        mnemonic: mnemonic,
      );
      final balances = await _repository.syncWalletUtxos(
        auth: auth,
        mnemonic: mnemonic,
      );
      final instruments =
          await _repository.listInstruments(auth.walletToken);
      final orders = await _repository.listOrders(auth);
      state = state.copyWith(
        actionInProgress: false,
        auth: auth,
        balances: balances,
        instruments: instruments,
        orders: orders,
        clearInfo: true,
        infoMessage:
            'Wallet activated. Coordinator balances and UTXOs are syncing.',
      );
      unawaited(refreshTradeData());
    } catch (e) {
      state = state.copyWith(
        actionInProgress: false,
        errorMessage: readDlcApiErrorMessage(e),
      );
    }
  }

  Future<void> refreshAll() => refreshCurrentTab();

  Future<void> _backgroundRefresh({required bool showProcessing}) async {
    final auth = state.auth;
    final walletId = state.activeWalletId;
    if (auth == null || walletId == null) return;
    if (showProcessing) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final mnemonic = await _loadMnemonic(walletId);
      await _repository.runNegotiationPass(auth: auth, mnemonic: mnemonic);
      final orders = await _repository.listOrders(
        auth,
        enrichSettlement: true,
      );
      final balances = await _repository.syncWalletUtxos(
        auth: auth,
        mnemonic: mnemonic,
      );
      state = state.copyWith(
        isLoading: false,
        orders: orders,
        balances: balances,
        clearError: true,
      );
    } catch (e) {
      if (showProcessing) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: readDlcApiErrorMessage(e),
        );
      }
    }
  }

  Future<void> createOrder({required num quantity}) async {
    final auth = state.auth;
    final walletId = state.activeWalletId;
    final template = state.templateInstrumentId;
    final strike = state.selectedStrike;
    final side = state.createSide;
    final matchIntent = state.createOrderMatchIntent;
    if (auth == null || walletId == null || template == null) {
      return;
    }
    if (quantity <= 0) {
      state = state.copyWith(
        errorMessage: 'Enter a valid number of contracts (min 0.01).',
      );
      return;
    }

    final resolvedId = state.resolvedInstrumentId ?? template;
    final pendingId = 'local-pending-${DateTime.now().millisecondsSinceEpoch}';
    final pendingOrder = DlcOrder(
      orderId: pendingId,
      instrumentId: resolvedId,
      side: side,
      status: 'open',
      quantity: quantity,
    );

    var books = state.strikeOrderbooks;
    if (matchIntent && strike != null) {
      books = optimisticTrimOrderbookForMatch(
        snapshots: books,
        strike: strike,
        side: side,
        quantity: quantity,
      );
    }

    state = state.copyWith(
      orders: [pendingOrder, ...state.orders],
      strikeOrderbooks: books,
      selectedTabIndex: 2,
      clearError: true,
      clearCreateOrderMatchIntent: true,
      infoMessage: matchIntent
          ? 'Order placed — likely matched. Check Live orders for signing progress.'
          : 'Order opened on the book. Check My orders for status.',
    );

    unawaited(
      _completeCreateOrderInBackground(
        auth: auth,
        walletId: walletId,
        template: template,
        strike: strike,
        side: side,
        quantity: quantity,
        pendingOrderId: pendingId,
      ),
    );
  }

  Future<void> _completeCreateOrderInBackground({
    required DlcWalletAuth auth,
    required String walletId,
    required String template,
    required num? strike,
    required String side,
    required num quantity,
    required String pendingOrderId,
  }) async {
    try {
      final mnemonic = await _loadMnemonic(walletId);
      final response = await _repository.createOrder(
        auth: auth,
        mnemonic: mnemonic,
        instrumentId: template,
        side: side,
        quantity: quantity,
        strike: dlcInstrumentHasStrikePlaceholder(template) ? strike : null,
      );
      await _repository.runNegotiationPass(auth: auth, mnemonic: mnemonic);
      final orders = await _repository.listOrders(
        auth,
        enrichSettlement: true,
      );
      state = state.copyWith(
        orders: orders,
        infoMessage:
            'Order ${response.orderId} created (${response.status}). Signing continues in the background.',
      );
      unawaited(_backgroundRefresh(showProcessing: false));
    } catch (e) {
      final message = e is DlcApiException && isDlcPartnerConfigError(e)
          ? 'DLC partner token is not accepted by the coordinator. Check .env.'
          : readDlcApiErrorMessage(e);
      state = state.copyWith(
        orders: state.orders
            .where((order) => order.orderId != pendingOrderId)
            .toList(),
        errorMessage: message,
      );
    }
  }

  Future<void> cancelOrder(String orderId) async {
    final auth = state.auth;
    final walletId = state.activeWalletId;
    if (auth == null || walletId == null) return;

    state = state.copyWith(processingOrder: true, clearError: true);
    try {
      final mnemonic = await _loadMnemonic(walletId);
      await _repository.cancelOrder(
        auth: auth,
        orderId: orderId,
        mnemonic: mnemonic,
      );
      final orders = await _repository.listOrders(auth);
      final balances = await _repository.syncWalletUtxos(
        auth: auth,
        mnemonic: mnemonic,
      );
      state = state.copyWith(
        processingOrder: false,
        orders: orders,
        balances: balances,
        infoMessage: 'Order cancelled and orderbook updated.',
      );
    } catch (e) {
      state = state.copyWith(
        processingOrder: false,
        errorMessage: readDlcApiErrorMessage(e),
      );
    }
  }
}

final dlcProvider = StateNotifierProvider.autoDispose<DlcNotifier, DlcState>(
  DlcNotifier.new,
);

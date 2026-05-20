import 'dart:convert';

import 'package:aqua/data/provider/provider.dart';
import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DlcAuthStorage {
  DlcAuthStorage(this._storage, this._config);

  final IStorage _storage;
  final DlcConfig _config;

  String get _key => 'dlc_wallet_auth_${_config.storageSuffix}';

  Future<Map<String, DlcWalletAuth>> loadAll() async {
    final (raw, err) = await _storage.get(_key);
    if (err != null || raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (walletOriginId, value) => MapEntry(
          walletOriginId,
          DlcWalletAuth.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<DlcWalletAuth?> loadForWallet(String walletOriginId) async {
    final all = await loadAll();
    return all[walletOriginId];
  }

  Future<void> store(DlcWalletAuth auth) async {
    final all = await loadAll();
    all[auth.walletOriginId] = auth;
    await _persist(all);
  }

  Future<void> remove(String walletOriginId) async {
    final all = await loadAll();
    all.remove(walletOriginId);
    await _persist(all);
  }

  Future<void> _persist(Map<String, DlcWalletAuth> all) async {
    final encoded = jsonEncode(
      all.map((key, value) => MapEntry(key, value.toJson())),
    );
    await _storage.save(key: _key, value: encoded);
  }
}

final dlcAuthStorageProvider = Provider<DlcAuthStorage>((ref) {
  return DlcAuthStorage(
    ref.read(secureStorageProvider),
    ref.watch(dlcConfigProvider),
  );
});

import 'dart:convert';
import 'dart:math';

import 'package:aqua/data/provider/provider.dart';
import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists coordinator idempotency keys across retries and app restarts.
class DlcIdempotencyStorage {
  DlcIdempotencyStorage(this._storage, this._config);

  final IStorage _storage;
  final DlcConfig _config;
  final _random = Random.secure();

  String get _key => 'dlc_idempotency_${_config.storageSuffix}';

  Future<String> getOrCreateCreateKey(String draftFingerprint) async {
    final data = await _load();
    final createByDraft =
        Map<String, String>.from(data['createByDraft'] as Map? ?? {});
    final existing = createByDraft[draftFingerprint];
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final key = _newKey('order');
    createByDraft[draftFingerprint] = key;
    data['createByDraft'] = createByDraft;
    await _save(data);
    return key;
  }

  Future<void> clearCreateKey(String draftFingerprint) async {
    final data = await _load();
    final createByDraft =
        Map<String, String>.from(data['createByDraft'] as Map? ?? {});
    createByDraft.remove(draftFingerprint);
    data['createByDraft'] = createByDraft;
    await _save(data);
  }

  Future<String> getOrCreateAcceptKey({
    required String orderId,
    required String contextFingerprint,
  }) async {
    final data = await _load();
    final acceptByOrder =
        Map<String, String>.from(data['acceptByOrder'] as Map? ?? {});
    final mapKey = '$orderId:$contextFingerprint';
    final existing = acceptByOrder[mapKey];
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final key = _newKey('accept');
    acceptByOrder[mapKey] = key;
    data['acceptByOrder'] = acceptByOrder;
    await _save(data);
    return key;
  }

  Future<void> rotateAcceptKey({
    required String orderId,
    required String contextFingerprint,
  }) async {
    final data = await _load();
    final acceptByOrder =
        Map<String, String>.from(data['acceptByOrder'] as Map? ?? {});
    acceptByOrder['$orderId:$contextFingerprint'] = _newKey('accept');
    data['acceptByOrder'] = acceptByOrder;
    await _save(data);
  }

  Future<String> getOrCreateSignKey({
    required String dlcId,
    required String contextFingerprint,
  }) async {
    final data = await _load();
    final signByDlc = Map<String, String>.from(data['signByDlc'] as Map? ?? {});
    final mapKey = '$dlcId:$contextFingerprint';
    final existing = signByDlc[mapKey];
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final key = _newKey('sign');
    signByDlc[mapKey] = key;
    data['signByDlc'] = signByDlc;
    await _save(data);
    return key;
  }

  Future<void> rotateSignKey({
    required String dlcId,
    required String contextFingerprint,
  }) async {
    final data = await _load();
    final signByDlc = Map<String, String>.from(data['signByDlc'] as Map? ?? {});
    signByDlc['$dlcId:$contextFingerprint'] = _newKey('sign');
    data['signByDlc'] = signByDlc;
    await _save(data);
  }

  Future<Map<String, dynamic>> _load() async {
    final (raw, err) = await _storage.get(_key);
    if (err != null || raw == null || raw.isEmpty) {
      return {};
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, dynamic> data) async {
    await _storage.save(key: _key, value: jsonEncode(data));
  }

  String _newKey(String prefix) {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return '$prefix-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}

final dlcIdempotencyStorageProvider = Provider<DlcIdempotencyStorage>((ref) {
  return DlcIdempotencyStorage(
    ref.read(secureStorageProvider),
    ref.watch(dlcConfigProvider),
  );
});

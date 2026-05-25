import 'package:aqua/data/models/gdk_models.dart';
import 'package:aqua/features/dlc/services/dlc_funding_key_resolve.dart';
import 'package:aqua/features/dlc/services/dlc_local_signer.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveFundingInputSigningMaterials', () {
    const signer = DlcLocalSigner();
    final mnemonic = bip39.generateMnemonic();
    const accountUserPath = [84 | 0x80000000, 0 | 0x80000000, 0 | 0x80000000];
    final accountPath = signer.accountDerivationPath(accountUserPath);
    final utxoPath = '$accountPath/0/0';
    final publicKeyHex = signer.derivePublicKeyHexAtPath(mnemonic, utxoPath);
    final addressScript = p2wpkhScriptHexFromPubkeyHex(publicKeyHex);

    test('resolves key by outpoint from GDK userPath', () {
      const txid =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final utxos = [
        GdkUnspentOutputs(
          txhash: txid,
          ptIdx: 1,
          userPath: const [84 | 0x80000000, 0 | 0x80000000, 0 | 0x80000000, 0, 0],
          script: addressScript,
        ),
      ];
      final sighashHex = '00' * 32;

      final materials = resolveFundingInputSigningMaterials(
        mnemonic: mnemonic,
        accountDerivationPath: accountPath,
        walletUtxos: utxos,
        fundingInputSighashesHex: [sighashHex],
        fundingInputAddresses: const [],
        fundingInputOutpoints: const ['$txid:1'],
        derivePrivateKeyHex: signer.derivePrivateKeyHexAtPath,
        derivePublicKeyHex: signer.derivePublicKeyHexAtPath,
      );

      expect(materials, hasLength(1));
      expect(
        materials.first.publicKeyHex,
        signer.derivePublicKeyHexAtPath(mnemonic, utxoPath),
      );
    });

    test('throws when funding input key cannot be resolved', () {
      final sighashHex = '00' * 32;
      expect(
        () => resolveFundingInputSigningMaterials(
          mnemonic: mnemonic,
          accountDerivationPath: accountPath,
          walletUtxos: const [],
          fundingInputSighashesHex: [sighashHex],
          fundingInputAddresses: const ['bc1qunknownaddress000000000000000000000'],
          fundingInputOutpoints: const ['deadbeef:0'],
          derivePrivateKeyHex: signer.derivePrivateKeyHexAtPath,
          derivePublicKeyHex: signer.derivePublicKeyHexAtPath,
        ),
        throwsStateError,
      );
    });
  });

  group('p2wpkhScriptHexFromPubkeyHex', () {
    test('returns native segwit script prefix', () {
      const signer = DlcLocalSigner();
      final mnemonic = bip39.generateMnemonic();
      const accountUserPath = [84 | 0x80000000, 0 | 0x80000000, 0 | 0x80000000];
      final path =
          '${signer.accountDerivationPath(accountUserPath)}/0/0';
      final pubkey = signer.derivePublicKeyHexAtPath(mnemonic, path);

      final script = p2wpkhScriptHexFromPubkeyHex(pubkey);

      expect(script.startsWith('0014'), isTrue);
      expect(script.length, 44);
    });
  });
}

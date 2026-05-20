import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/dleq.dart';
import 'package:convert/convert.dart';
import 'package:aqua/features/dlc/crypto/ecdsa_adaptor.dart';
import 'package:aqua/features/dlc/crypto/ecdsa_adaptor_signature.dart';
import 'package:aqua/features/dlc/crypto/low_s.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_constants.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_point.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_scalar.dart';
import 'package:aqua/features/dlc/crypto/tagged_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tagged hash', () {
    test('BIP340 challenge prefix is 64 bytes', () {
      expect(taggedHashPrefix('BIP0340/challenge').length, 64);
    });
  });

  group('DLEQ', () {
    test('round-trip on random witness', () {
      final k = BigInt.parse(
        '0b2aba63b885a0f0e96fa0f303920c7fb7431ddfa94376ad94d969fbf4109dc8',
        radix: 16,
      );
      final y = Secp256k1Point.fromCompressed(_hex(
        '02c2662c97488b07b6e819124b8989849206334a4c2fbdf691f7b34d2b16e9c293',
      ));
      final x = scalarBaseMult(k);
      final z = y.multiply(k);
      final proof = dleqProve(k, x, y, z);
      expect(dleqVerify(x, y, z, proof), isTrue);
    });

    test('fails when proof is tampered', () {
      final k = BigInt.parse(
        '0b2aba63b885a0f0e96fa0f303920c7fb7431ddfa94376ad94d969fbf4109dc8',
        radix: 16,
      );
      final y = Secp256k1Point.fromCompressed(_hex(
        '02c2662c97488b07b6e819124b8989849206334a4c2fbdf691f7b34d2b16e9c293',
      ));
      final x = scalarBaseMult(k);
      final z = y.multiply(k);
      final proof = dleqProve(k, x, y, z);
      proof[0] ^= 0x01;
      expect(dleqVerify(x, y, z, proof), isFalse);
    });
  });

  group('dlcspecs ecdsa_adaptor.json verification vectors', () {
    final vectors = _loadVerificationVectors();

    for (final vector in vectors) {
      test(vector['comment'] ?? vector['name'], () {
        final adaptorBytes = _hex(vector['adaptor_sig'] as String);
        final messageHash = _hex(vector['message_hash'] as String);
        final publicKey = Secp256k1Point.fromCompressed(
          _hex(vector['public_signing_key'] as String),
        );
        final encryptionKey = Secp256k1Point.fromCompressed(
          _hex(vector['encryption_key'] as String),
        );
        final signature = EcdsaAdaptorSignature.deserializePrimitive(
          adaptorBytes,
        );
        final expectError = vector['error'] as String?;

        if (expectError != null) {
          expect(
            adaptorVerify(
              signerPublicKey: publicKey,
              adaptorPointY: encryptionKey,
              messageHash: messageHash,
              signature: signature,
            ),
            isFalse,
          );
          return;
        }

        expect(
          adaptorVerify(
            signerPublicKey: publicKey,
            adaptorPointY: encryptionKey,
            messageHash: messageHash,
            signature: signature,
          ),
          isTrue,
        );

        final decryptionKey = scalarFromBytes(
          _hex(vector['decryption_key'] as String),
        );
        final decrypted = adaptorDecrypt(
          signature: signature,
          decryptionKey: decryptionKey,
        );
        expect(
          _bytesToHex(decrypted.serialize()),
          vector['signature'] as String,
        );

        final recovered = adaptorRecover(
          adaptorPointY: encryptionKey,
          signature: signature,
          decryptedSignature: decrypted,
        );
        expect(
          bigEndian32(recovered),
          _hex(vector['decryption_key'] as String),
        );
      });
    }
  });

  group('wire codec', () {
    test('primitive round-trip', () {
      final bytes = _hex(
        '036035c89860ec62ad153f69b5b3077bcd08fbb0d28dc7f7f6df4a05cca35455be'
        '037043b63c56f6317d9928e8f91007335748c49824220db14ad10d80a5d00a'
        '9654af0996c1824c64c90b951bb2734aaecf78d4b36131a47238c3fa2ba25e2ce'
        'd54255b06df696de1483c3767242a3728826e05f79e3981e12553355bba8a0131'
        'cd370e63e3da73106f638576a5aab0ea6d45c042574c0c8d0b14b8c7c01cfe9072',
      );
      final sig = EcdsaAdaptorSignature.deserializePrimitive(bytes);
      expect(sig.toEncryptedAdaptorBytes(), bytes);
    });

    test('wire round-trip preserves fields', () {
      final primitive = EcdsaAdaptorSignature.deserializePrimitive(_hex(
        '03424d14a5471c048ab87b3b83f6085d125d5864249ae4297a57c84e74710bb6730'
        '223f325042fce535d040fee52ec13231bf709ccd84233c6944b90317e62528b2527'
        'dff9d659a96db4c99f9750168308633c1867b70f3a18fb0f4539a1aecedcd1fc0'
        '148fc22f36b6303083ece3f872b18e35d368b3958efe5fb081f7716736ccb598d2'
        '69aa3084d57e1855e1ea9a45efc10463bbf32ae378029f5763ceb40173f',
      ));
      final wire = primitive.serializeWire();
      final parsed = EcdsaAdaptorSignature.deserializeWire(wire);
      expect(parsed.rPoint, primitive.rPoint);
      expect(parsed.raPoint, primitive.raPoint);
      expect(parsed.sA, primitive.sA);
      expect(parsed.proof, primitive.proof);
      expect(wire.length, kWireCetAdaptorEntryBytes);
    });
  });

  group('low-S', () {
    test('normalizes s above half order', () {
      final halfOrder = secp256k1OrderN >> 1;
      final highS = halfOrder + BigInt.one;
      expect(normalizeToLowS(highS), secp256k1OrderN - highS);
    });
  });
}

List<Map<String, dynamic>> _loadVerificationVectors() {
  return [
    {
      'name': 'plain valid',
      'comment': 'plain valid adaptor signature',
      'adaptor_sig':
          '03424d14a5471c048ab87b3b83f6085d125d5864249ae4297a57c84e74710bb6730223f325042fce535d040fee52ec13231bf709ccd84233c6944b90317e62528b2527dff9d659a96db4c99f9750168308633c1867b70f3a18fb0f4539a1aecedcd1fc0148fc22f36b6303083ece3f872b18e35d368b3958efe5fb081f7716736ccb598d269aa3084d57e1855e1ea9a45efc10463bbf32ae378029f5763ceb40173f',
      'message_hash':
          '8131e6f4b45754f2c90bd06688ceeabc0c45055460729928b4eecf11026a9e2d',
      'public_signing_key':
          '035be5e9478209674a96e60f1f037f6176540fd001fa1d64694770c56a7709c42c',
      'encryption_key':
          '02c2662c97488b07b6e819124b8989849206334a4c2fbdf691f7b34d2b16e9c293',
      'decryption_key':
          '0b2aba63b885a0f0e96fa0f303920c7fb7431ddfa94376ad94d969fbf4109dc8',
      'signature':
          '424d14a5471c048ab87b3b83f6085d125d5864249ae4297a57c84e74710bb67329e80e0ee60e57af3e625bbae1672b1ecaa58effe613426b024fa1621d903394',
    },
    {
      'name': 'high s decrypt',
      'comment': 'high s must be negated',
      'adaptor_sig':
          '036035c89860ec62ad153f69b5b3077bcd08fbb0d28dc7f7f6df4a05cca35455be037043b63c56f6317d9928e8f91007335748c49824220db14ad10d80a5d00a9654af0996c1824c64c90b951bb2734aaecf78d4b36131a47238c3fa2ba25e2ced54255b06df696de1483c3767242a3728826e05f79e3981e12553355bba8a0131cd370e63e3da73106f638576a5aab0ea6d45c042574c0c8d0b14b8c7c01cfe9072',
      'message_hash':
          '8131e6f4b45754f2c90bd06688ceeabc0c45055460729928b4eecf11026a9e2d',
      'public_signing_key':
          '035be5e9478209674a96e60f1f037f6176540fd001fa1d64694770c56a7709c42c',
      'encryption_key':
          '024eee18be9a5a5224000f916c80b393447989e7194bc0b0f1ad7a03369702bb51',
      'decryption_key':
          'db2debddb002473a001dd70b06f6c97bdcd1c46ba1001237fe0ee1aeffb2b6c4',
      'signature':
          '6035c89860ec62ad153f69b5b3077bcd08fbb0d28dc7f7f6df4a05cca35455be4ceacf921546c03dd1be596723ad1e7691bdac73d88cc36c421c5e7f08384305',
    },
    {
      'name': 'bad proof',
      'comment': 'proof is wrong',
      'adaptor_sig':
          '03f94dca206d7582c015fb9bffe4e43b14591b30ef7d2b464d103ec5e116595dba03127f8ac3533d249280332474339000922eb6a58e3b9bf4fc7e01e4b4df2b7a4100a1e089f16e5d70bb89f961516f1de0684cc79db978495df2f399b0d01ed7240fa6e3252aedb58bdc6b5877b0c602628a235dd1ccaebdddcbe96198c0c21bead7b05f423b673d14d206fa1507b2dbe2722af792b8c266fc25a2d901d7e2c335',
      'message_hash':
          '8131e6f4b45754f2c90bd06688ceeabc0c45055460729928b4eecf11026a9e2d',
      'public_signing_key':
          '035be5e9478209674a96e60f1f037f6176540fd001fa1d64694770c56a7709c42c',
      'encryption_key':
          '0214ccb756249ad6e733c80285ea7ac2ee12ffebbcee4e556e6810793a60c45ad4',
      'decryption_key':
          '1dfcfc0880e72509768ab46f2545b33168b8b8df8e4f5feb5059aa3750ee59d0',
      'signature':
          '424d14a5471c048ab87b3b83f6085d125d5864249ae4297a57c84e74710bb67329e80e0ee60e57af3e625bbae1672b1ecaa58effe613426b024fa1621d903394',
      'error': 'proof is wrong',
    },
  ];
}

Uint8List _hex(String value) => Uint8List.fromList(hex.decode(value));

String _bytesToHex(Uint8List bytes) => hex.encode(bytes);

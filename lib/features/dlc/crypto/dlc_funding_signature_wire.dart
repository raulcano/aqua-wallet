import 'dart:typed_data';

/// DLC [`BigSize`](https://github.com/lightningdevkit/rust-lightning) variable-length integer.
void writeBigSize(BytesBuilder builder, int value) {
  if (value <= 0xfc) {
    builder.addByte(value);
    return;
  }
  if (value <= 0xffff) {
    builder
      ..addByte(0xfd)
      ..addByte((value >> 8) & 0xff)
      ..addByte(value & 0xff);
    return;
  }
  if (value <= 0xffffffff) {
    builder
      ..addByte(0xfe)
      ..addByte((value >> 24) & 0xff)
      ..addByte((value >> 16) & 0xff)
      ..addByte((value >> 8) & 0xff)
      ..addByte(value & 0xff);
    return;
  }
  builder
    ..addByte(0xff)
    ..addByte((value >> 56) & 0xff)
    ..addByte((value >> 48) & 0xff)
    ..addByte((value >> 40) & 0xff)
    ..addByte((value >> 32) & 0xff)
    ..addByte((value >> 24) & 0xff)
    ..addByte((value >> 16) & 0xff)
    ..addByte((value >> 8) & 0xff)
    ..addByte(value & 0xff);
}

/// One witness stack: `n_elements || elem0 || elem1 || ...`.
Uint8List encodeWitnessStack(List<Uint8List> witnessElements) {
  final builder = BytesBuilder();
  writeBigSize(builder, witnessElements.length);
  for (final element in witnessElements) {
    writeBigSize(builder, element.length);
    builder.add(element);
  }
  return builder.toBytes();
}

/// P2WPKH witness stack for one funding input: `[DER + SIGHASH_ALL, pubkey]`.
Uint8List encodeP2wpkhWitnessStack({
  required Uint8List derSignatureWithSighash,
  required Uint8List compressedPublicKey,
}) {
  if (compressedPublicKey.length != 33) {
    throw ArgumentError('Compressed public key must be 33 bytes');
  }
  return encodeWitnessStack([
    derSignatureWithSighash,
    compressedPublicKey,
  ]);
}

/// Single [`FundingSignature`](https://github.com/p2pderivatives/rust-dlc) entry
/// wrapping all party-owned funding-input witness stacks.
///
/// Wire layout: `n_stacks || stack0 || stack1 || ...`
Uint8List encodeFundingSignaturesContainer(List<Uint8List> witnessStacks) {
  final builder = BytesBuilder();
  writeBigSize(builder, witnessStacks.length);
  for (final stack in witnessStacks) {
    builder.add(stack);
  }
  return builder.toBytes();
}

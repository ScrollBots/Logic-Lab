import 'dart:math';

/// Compact, collision-resistant identifiers for local circuits. IDs are not
/// security-sensitive; they only need to be unique inside one installation.
class IdGenerator {
  const IdGenerator._();

  static final Random _random = Random();
  static int _counter = 0;

  static String next([String prefix = 'id']) {
    _counter = (_counter + 1) & 0xFFFFFF;
    final String time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final String counter = _counter.toRadixString(36);
    final String noise = _random
        .nextInt(1 << 30)
        .toRadixString(36)
        .padLeft(6, '0');
    return '${prefix}_$time$counter$noise';
  }
}

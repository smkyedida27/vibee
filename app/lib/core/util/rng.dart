/// mulberry32 — must match docs/CONTRACT.md §2 and the backend bit-for-bit.
class Rng {
  Rng(int seed) : _a = seed & 0xFFFFFFFF;

  int _a;

  /// 32-bit multiply that stays exact on the web (where ints are doubles).
  static int _imul(int a, int b) {
    final ah = (a >> 16) & 0xFFFF, al = a & 0xFFFF;
    final bh = (b >> 16) & 0xFFFF, bl = b & 0xFFFF;
    final mid = ((ah * bl + al * bh) & 0xFFFF) * 65536;
    return (al * bl + mid) & 0xFFFFFFFF;
  }

  /// Next unsigned 32-bit value.
  int next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _imul(_a ^ (_a >> 15), 1 | _a);
    t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  int nextInt(int n) => next() % n;

  double nextDouble() => next() / 4294967296.0;

  /// Fisher–Yates from the end, as specified in the contract.
  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }
}

/// Stable 32-bit hash for building seeds from strings (FNV-1a).
int fnv1a(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = Rng._imul(h, 0x01000193);
  }
  return h;
}

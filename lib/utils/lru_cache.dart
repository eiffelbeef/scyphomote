class LruCache<K, V> {
  final int maxEntries;
  final _map = <K, V>{};

  LruCache({this.maxEntries = 100});

  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    final value = _map.remove(key);
    if (value == null) return null;
    _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    }
    _map[key] = value;
    if (_map.length > maxEntries) {
      final oldest = _map.keys.first;
      _map.remove(oldest);
    }
  }

  bool containsKey(K key) => _map.containsKey(key);

  void remove(K key) => _map.remove(key);

  void clear() => _map.clear();

  int get length => _map.length;
}

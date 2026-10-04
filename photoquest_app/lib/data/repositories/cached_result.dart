/// Hasil pengambilan data dengan pola "server dulu, cache jika gagal".
///
/// [fromCache] = true berarti server tidak terjangkau dan data berasal dari
/// database lokal -> UI menampilkan banner "Mode offline".
class CachedResult<T> {
  const CachedResult(this.data, {this.fromCache = false, this.cachedAt});

  final T data;
  final bool fromCache;
  final DateTime? cachedAt;
}

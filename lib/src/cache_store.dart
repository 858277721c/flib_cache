import 'dart:io';

import 'core.dart';
import 'key_transform.dart';

class FFileCacheStore implements FCacheStore {
  final String directory;
  final FCacheKeyTransform cacheKeyTransform;

  FFileCacheStore(
    this.directory, {
    FCacheKeyTransform cacheKeyTransform,
  })  : this.cacheKeyTransform = cacheKeyTransform ?? new MD5KeyTransform(),
        assert(directory != null && directory.isNotEmpty);

  File _getCacheFile(String key) {
    key = cacheKeyTransform.transform(key);
    return new File(directory + '/' + key);
  }

  bool _checkDirectory() {
    return true;
  }

  @override
  bool putCache(String key, List<int> value) {
    if (value == null) {
      return removeCache(key);
    }

    if (!_checkDirectory()) {
      throw new FCacheException('create cache directory failed');
    }

    final File file = _getCacheFile(key);
    file.writeAsBytesSync(value);
    return true;
  }

  @override
  List<int> getCache(String key) {
    final File file = _getCacheFile(key);
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  @override
  bool removeCache(String key) {
    final File file = _getCacheFile(key);
    if (file.existsSync()) {
      file.deleteSync();
      return true;
    }
    return false;
  }

  @override
  bool containsCache(String key) {
    final File file = _getCacheFile(key);
    return file.existsSync();
  }
}

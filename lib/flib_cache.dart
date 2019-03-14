library flib_cache;

import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

class FCacheManager {
  static FCacheManager _instance;

  FCacheManager._internal() {}

  static FCacheManager getInstance() {
    if (_instance == null) {
      _instance = new FCacheManager._internal();
    }
    return _instance;
  }

  FCacheConfig _cacheConfig;

  FCacheConfig get cacheConfig {
    if (_cacheConfig == null) {
      throw new _FCacheException('you must provide a FCacheConfig before this');
    }
    return _cacheConfig;
  }

  /// 初始化
  void init(FCacheConfig config) {
    assert(config != null);
    if (_cacheConfig != null) {
      throw new _FCacheException('FCacheConfig can only be specified once');
    }
    _cacheConfig = config;
  }

  static FStringCache string() {
    final FCacheConfig config = getInstance().cacheConfig;
    return new _StringCache(
      config,
      new _PrefixKeyTransform('FStringCache:'),
    );
  }

  static FIntCache int() {
    final FCacheConfig config = getInstance().cacheConfig;
    return new _IntCache(
      config,
      new _PrefixKeyTransform('FIntCache:'),
    );
  }

  static FDoubleCache double() {
    final FCacheConfig config = getInstance().cacheConfig;
    return new _DoubleCache(
      config,
      new _PrefixKeyTransform('FDoubleCache:'),
    );
  }

  static FObjectCache<T> object<T extends FCacheableObject>() {
    final FCacheConfig config = getInstance().cacheConfig;
    return new _ObjectCache<T>(
      config,
      new _PrefixKeyTransform('FObjectCache:'),
    );
  }

  static FSingleObjectCache<T> singleObject<T extends FCacheableObject>() {
    final FCacheConfig config = getInstance().cacheConfig;
    return new _SingleObjectCache<T>(
      config,
      new _PrefixKeyTransform('FSingleObjectCache:'),
    );
  }
}

class FCacheConfig {
  /// 整个库的底层缓存实现类
  final FBytesCache cache;
  final FByteableObjectConverter byteableObjectConverter;
  final FJsonMapableObjectConverter jsonMapableObjectConverter;

  FCacheConfig(
    this.cache, {
    this.byteableObjectConverter,
    this.jsonMapableObjectConverter,
  }) : assert(cache != null);
}

abstract class FCache<T> {
  /// 放入缓存
  bool put(String key, T value);

  /// 获得缓存
  T get(String key);

  /// 删除缓存
  bool remove(String key);

  /// 是否有key对应的缓存
  bool contains(String key);
}

abstract class FCacheableObject {
  static const tagByte = 0;
  static const tagJsonMap = 1;
}

/// 可转换为byte的对象接口
abstract class FByteableObject extends FCacheableObject {
  List<int> toBytes();
}

/// 可转换为json map的对象接口
abstract class FJsonMapableObject extends FCacheableObject {
  Map<String, dynamic> toJsonMap();
}

abstract class FCacheableObjectConverter<C, O> {
  O cacheToObject(C cache, Type type);
}

/// 可转换byte为对象的转换器接口
abstract class FByteableObjectConverter
    extends FCacheableObjectConverter<List<int>, FByteableObject> {}

/// 可转换json map为对象的转换器接口
abstract class FJsonMapableObjectConverter extends FCacheableObjectConverter<
    Map<String, dynamic>, FJsonMapableObject> {}

abstract class FBytesCache extends FCache<List<int>> {}

abstract class FStringCache extends FCache<String> {}

abstract class FIntCache extends FCache<int> {}

abstract class FDoubleCache extends FCache<double> {}

abstract class FObjectCache<T extends FCacheableObject> extends FCache<T> {}

abstract class FSingleObjectCache<T extends FCacheableObject> {
  bool put(T value);

  T get();

  bool remove();

  bool contains();
}

abstract class FCacheKeyTransform {
  String transform(String key);
}

class _MD5KeyTransform implements FCacheKeyTransform {
  @override
  String transform(String key) {
    assert(key != null);
    final List<int> keyBytes = utf8.encode(key);
    final Digest digest = md5.convert(keyBytes);
    final String keyMd5 = hex.encode(digest.bytes);
    return keyMd5;
  }
}

class _PrefixKeyTransform implements FCacheKeyTransform {
  final String prefix;

  _PrefixKeyTransform(this.prefix) : assert(prefix != null);

  @override
  String transform(String key) {
    assert(key != null);
    return prefix + key;
  }
}

class FSimpleBytesCache implements FBytesCache {
  final String directory;
  final FCacheKeyTransform cacheKeyTransform;

  FSimpleBytesCache(
    this.directory, {
    FCacheKeyTransform cacheKeyTransform,
  })  : this.cacheKeyTransform = cacheKeyTransform == null
            ? new _MD5KeyTransform()
            : cacheKeyTransform,
        assert(directory != null && directory.isNotEmpty);

  File _getCacheFile(String key) {
    key = cacheKeyTransform.transform(key);
    return new File(directory + '/' + key);
  }

  bool _checkDirectory() {
    return true;
  }

  @override
  bool put(String key, List<int> value) {
    if (value == null) {
      return remove(key);
    }

    if (!_checkDirectory()) {
      throw new _FCacheException('create cache directory failed');
    }

    final File file = _getCacheFile(key);
    file.writeAsBytesSync(value);
    return true;
  }

  @override
  List<int> get(String key) {
    final File file = _getCacheFile(key);
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  @override
  bool remove(String key) {
    final File file = _getCacheFile(key);
    if (file.existsSync()) {
      file.deleteSync();
      return true;
    }
    return false;
  }

  @override
  bool contains(String key) {
    final File file = _getCacheFile(key);
    return file.existsSync();
  }
}

abstract class _BaseCache<T> extends FCache<T> {
  final FCacheConfig cacheConfig;
  final FCacheKeyTransform cacheKeyTransform;

  _BaseCache(
    this.cacheConfig,
    this.cacheKeyTransform,
  )   : assert(cacheConfig != null),
        assert(cacheKeyTransform != null);

  @override
  bool put(String key, T value) {
    key = cacheKeyTransform.transform(key);

    if (value == null) {
      return cacheConfig.cache.put(key, null);
    }

    final List<int> bytes = valueToBytes(value);
    if (bytes == null) {
      throw new _FCacheException('valueToBytes return null');
    }

    return cacheConfig.cache.put(key, bytes);
  }

  @override
  T get(String key) {
    key = cacheKeyTransform.transform(key);

    final List<int> bytes = cacheConfig.cache.get(key);
    if (bytes == null || bytes.length <= 0) {
      return null;
    }

    return bytesToValue(bytes);
  }

  @override
  bool remove(String key) {
    key = cacheKeyTransform.transform(key);
    return cacheConfig.cache.remove(key);
  }

  @override
  bool contains(String key) {
    key = cacheKeyTransform.transform(key);
    return cacheConfig.cache.contains(key);
  }

  List<int> valueToBytes(T value);

  T bytesToValue(List<int> bytes);
}

class _StringCache extends _BaseCache<String> implements FStringCache {
  _StringCache(
    FCacheConfig cacheConfig,
    FCacheKeyTransform cacheKeyTransform,
  ) : super(
          cacheConfig,
          cacheKeyTransform,
        );

  @override
  List<int> valueToBytes(String value) {
    return utf8.encode(value);
  }

  @override
  String bytesToValue(List<int> bytes) {
    return utf8.decode(bytes);
  }
}

class _IntCache extends _BaseCache<int> implements FIntCache {
  _IntCache(
    FCacheConfig cacheConfig,
    FCacheKeyTransform cacheKeyTransform,
  ) : super(
          cacheConfig,
          cacheKeyTransform,
        );

  @override
  List<int> valueToBytes(int value) {
    return utf8.encode(value.toString());
  }

  @override
  int bytesToValue(List<int> bytes) {
    return int.parse(utf8.decode(bytes));
  }
}

class _DoubleCache extends _BaseCache<double> implements FDoubleCache {
  _DoubleCache(
    FCacheConfig cacheConfig,
    FCacheKeyTransform cacheKeyTransform,
  ) : super(
          cacheConfig,
          cacheKeyTransform,
        );

  @override
  List<int> valueToBytes(double value) {
    return utf8.encode(value.toString());
  }

  @override
  double bytesToValue(List<int> bytes) {
    return double.parse(utf8.decode(bytes));
  }
}

class _ObjectCache<T extends FCacheableObject> extends _BaseCache<T>
    implements FObjectCache<T> {
  _ObjectCache(
    FCacheConfig cacheConfig,
    FCacheKeyTransform cacheKeyTransform,
  ) : super(
          cacheConfig,
          cacheKeyTransform,
        );

  @override
  T get(String key) {
    if (T == FCacheableObject) {
      throw new _FCacheException(
          'Generics type are not specified when get object');
    }
    return super.get(key);
  }

  @override
  List<int> valueToBytes(FCacheableObject value) {
    final List<int> result = [];

    if (value is FByteableObject) {
      final List<int> toBytes = value.toBytes();
      if (toBytes == null || toBytes.length <= 0) {
        throw new _FCacheException(
            '${value.runtimeType.toString()} toBytes() return null or empty');
      }

      result.addAll(toBytes);
      result.add(FCacheableObject.tagByte);
    } else if (value is FJsonMapableObject) {
      final Map<String, dynamic> jsonMap = value.toJsonMap();
      if (jsonMap == null) {
        throw new _FCacheException(
            '${value.runtimeType.toString()} toJsonMap() return null');
      }
      final List<int> toBytes = utf8.encode(json.encode(jsonMap));

      result.addAll(toBytes);
      result.add(FCacheableObject.tagJsonMap);
    } else {
      throw new _FCacheException(
          'unknow FCacheableObject: ' + value.runtimeType.toString());
    }
    return result;
  }

  @override
  T bytesToValue(List<int> bytes) {
    final int tagIndex = bytes.length - 1;
    final int tag = bytes[tagIndex];
    bytes = bytes.sublist(0, tagIndex);

    FCacheableObject object;
    switch (tag) {
      case FCacheableObject.tagByte:
        object = cacheConfig.byteableObjectConverter.cacheToObject(bytes, T);
        break;
      case FCacheableObject.tagJsonMap:
        final String jsonString = utf8.decode(bytes);
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        object =
            cacheConfig.jsonMapableObjectConverter.cacheToObject(jsonMap, T);
        break;
      default:
        throw new _FCacheException('unknow tag: ' + tag.toString());
    }

    if (T != object.runtimeType) {
      throw new _FCacheException(
          'Expect ${T.toString()} but ${object.runtimeType} was found from FCacheableObjectConverter');
    }

    return object;
  }
}

class _SingleObjectCache<T extends FCacheableObject>
    implements FSingleObjectCache<T> {
  final _ObjectCache<T> _objectCache;

  _SingleObjectCache(
    FCacheConfig cacheConfig,
    FCacheKeyTransform cacheKeyTransform,
  ) : this._objectCache = new _ObjectCache<T>(
          cacheConfig,
          cacheKeyTransform,
        ) {
    if (T == FCacheableObject) {
      throw new _FCacheException(
          'Generics type are not specified for FSingleObjectCache');
    }
  }

  @override
  bool put(T value) {
    final String key = T.toString();
    return _objectCache.put(key, value);
  }

  @override
  T get() {
    final String key = T.toString();
    return _objectCache.get(key);
  }

  @override
  bool remove() {
    final String key = T.toString();
    return _objectCache.remove(key);
  }

  @override
  bool contains() {
    final String key = T.toString();
    return _objectCache.contains(key);
  }
}

class _FCacheException implements Exception {
  final message;

  _FCacheException(this.message);

  @override
  String toString() {
    final String prefix = 'FCacheException';
    return message == null ? prefix : prefix + ': ' + message;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_store.dart';
import 'core.dart';
import 'key_transform.dart';

class FCache {
  static FCache _instance;

  FCache._() {}

  static FCache getInstance() {
    if (_instance == null) {
      _instance = new FCache._();
    }
    return _instance;
  }

  FCacheConfig _cacheConfig;
  bool _initialized = false;

  FCacheConfig get cacheConfig {
    if (!_initialized) {
      throw new FCacheException('FCache has not been initialized');
    }
    return _cacheConfig;
  }

  /// 初始化
  Future<bool> init(FCacheConfig config) async {
    if (_initialized) {
      throw new FCacheException('FCache can only be initialized once');
    }

    assert(config != null);
    if (config.cacheStore == null) {
      final Directory directory = await getApplicationDocumentsDirectory();
      config = config.copyWith(cacheStore: FFileCacheStore(directory.path));
    }

    _cacheConfig = config;
    _initialized = true;
    return true;
  }

  bool get initialized => _initialized;

  static FStringCache string() {
    final FCacheConfig config = getInstance().cacheConfig;
    return new _StringCache(
      config,
      new PrefixKeyTransform('FStringCache:'),
    );
  }

  static FIntCache int() {
    final FCacheConfig config = getInstance().cacheConfig;
    return new _IntCache(
      config,
      new PrefixKeyTransform('FIntCache:'),
    );
  }

  static FDoubleCache double() {
    final FCacheConfig config = getInstance().cacheConfig;
    return new _DoubleCache(
      config,
      new PrefixKeyTransform('FDoubleCache:'),
    );
  }

  static FObjectCache<T> object<T extends FCacheableObject>() {
    final FCacheConfig config = getInstance().cacheConfig;
    return new _ObjectCache<T>(
      config,
      new PrefixKeyTransform('FObjectCache:'),
    );
  }

  static FSingleObjectCache<T> singleObject<T extends FCacheableObject>() {
    final FCacheConfig config = getInstance().cacheConfig;
    return new _SingleObjectCache<T>(
      config,
      new PrefixKeyTransform('FSingleObjectCache:'),
    );
  }
}

class FCacheConfig {
  final FCacheStore cacheStore;
  final FByteObjectConverter byteObjectConverter;
  final FJsonMapObjectConverter jsonMapObjectConverter;

  FCacheConfig({
    @required this.cacheStore,
    this.byteObjectConverter,
    this.jsonMapObjectConverter,
  }) : assert(cacheStore != null);

  FCacheConfig copyWith({
    FCacheStore cacheStore,
    FByteObjectConverter byteObjectConverter,
    FJsonMapObjectConverter jsonMapObjectConverter,
  }) {
    return FCacheConfig(
        cacheStore: cacheStore ?? this.cacheStore,
        byteObjectConverter: byteObjectConverter ?? this.byteObjectConverter,
        jsonMapObjectConverter:
            jsonMapObjectConverter ?? this.jsonMapObjectConverter);
  }
}

abstract class _BaseCache<T> implements FCommonCache<T> {
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
      return cacheConfig.cacheStore.putCache(key, null);
    }

    final List<int> bytes = valueToBytes(value);
    if (bytes == null) {
      throw new FCacheException('valueToBytes return null');
    }

    return cacheConfig.cacheStore.putCache(key, bytes);
  }

  @override
  T get(String key) {
    key = cacheKeyTransform.transform(key);

    final List<int> bytes = cacheConfig.cacheStore.getCache(key);
    if (bytes == null || bytes.length <= 0) {
      return null;
    }

    return bytesToValue(bytes);
  }

  @override
  bool remove(String key) {
    key = cacheKeyTransform.transform(key);
    return cacheConfig.cacheStore.removeCache(key);
  }

  @override
  bool contains(String key) {
    key = cacheKeyTransform.transform(key);
    return cacheConfig.cacheStore.containsCache(key);
  }

  @protected
  List<int> valueToBytes(T value);

  @protected
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

  @protected
  @override
  List<int> valueToBytes(String value) {
    return utf8.encode(value);
  }

  @protected
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

  @protected
  @override
  List<int> valueToBytes(int value) {
    return utf8.encode(value.toString());
  }

  @protected
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

  @protected
  @override
  List<int> valueToBytes(double value) {
    return utf8.encode(value.toString());
  }

  @protected
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
      throw new FCacheException(
          'Generics type are not specified when get object');
    }
    return super.get(key);
  }

  @protected
  @override
  List<int> valueToBytes(FCacheableObject value) {
    final List<int> result = [];

    if (value is FByteObject) {
      final List<int> toBytes = value.toBytes();
      if (toBytes == null || toBytes.length <= 0) {
        throw new FCacheException(
            '${value.runtimeType.toString()} toBytes() return null or empty');
      }

      result.addAll(toBytes);
      result.add(FCacheableObject.tagByte);
    } else if (value is FJsonMapObject) {
      final Map<String, dynamic> jsonMap = value.toJsonMap();
      if (jsonMap == null) {
        throw new FCacheException(
            '${value.runtimeType.toString()} toJsonMap() return null');
      }
      final List<int> toBytes = utf8.encode(json.encode(jsonMap));

      result.addAll(toBytes);
      result.add(FCacheableObject.tagJsonMap);
    } else {
      throw new FCacheException(
          'unknow FCacheableObject: ' + value.runtimeType.toString());
    }
    return result;
  }

  @protected
  @override
  T bytesToValue(List<int> bytes) {
    final int tagIndex = bytes.length - 1;
    final int tag = bytes[tagIndex];
    bytes = bytes.sublist(0, tagIndex);

    FCacheableObject object;
    switch (tag) {
      case FCacheableObject.tagByte:
        object = cacheConfig.byteObjectConverter.cacheToObject(bytes, T);
        break;
      case FCacheableObject.tagJsonMap:
        final String jsonString = utf8.decode(bytes);
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        object = cacheConfig.jsonMapObjectConverter.cacheToObject(jsonMap, T);
        break;
      default:
        throw new FCacheException('unknow tag: ' + tag.toString());
    }

    if (T != object.runtimeType) {
      throw new FCacheException(
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
      throw new FCacheException(
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

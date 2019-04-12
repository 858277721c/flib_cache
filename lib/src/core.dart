/// 整个库底层缓存操作接口
abstract class FCacheStore {
  /// 放入缓存
  bool putCache(String key, List<int> bytes);

  /// 获得缓存
  List<int> getCache(String key);

  /// 删除缓存
  bool removeCache(String key);

  /// 是否有key对应的缓存
  bool containsCache(String key);
}

abstract class FCacheableObject {
  static const tagByte = 0;
  static const tagJsonMap = 1;
}

/// 可转换为byte的对象接口
abstract class FByteObject extends FCacheableObject {
  List<int> toBytes();
}

/// 可转换为json map的对象接口
abstract class FJsonMapObject extends FCacheableObject {
  Map<String, dynamic> toJsonMap();
}

abstract class _FCacheableObjectConverter<C, O> {
  O cacheToObject(C cache, Type type);
}

/// 可转换byte为对象的转换器接口
abstract class FByteObjectConverter
    extends _FCacheableObjectConverter<List<int>, FByteObject> {}

/// 可转换json map为对象的转换器接口
abstract class FJsonMapObjectConverter extends _FCacheableObjectConverter<
    Map<String, dynamic>, FJsonMapObject> {}

abstract class FCommonCache<T> {
  /// 放入缓存
  bool put(String key, T value);

  /// 获得缓存
  T get(String key);

  /// 删除缓存
  bool remove(String key);

  /// 是否有key对应的缓存
  bool contains(String key);
}

abstract class FStringCache extends FCommonCache<String> {}

abstract class FIntCache extends FCommonCache<int> {}

abstract class FDoubleCache extends FCommonCache<double> {}

abstract class FObjectCache<T extends FCacheableObject>
    extends FCommonCache<T> {}

abstract class FSingleObjectCache<T extends FCacheableObject> {
  bool put(T value);

  T get();

  bool remove();

  bool contains();
}

abstract class FCacheKeyTransform {
  String transform(String key);
}

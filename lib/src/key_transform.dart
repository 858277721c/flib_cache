import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

import 'core.dart';

class MD5KeyTransform implements FCacheKeyTransform {
  @override
  String transform(String key) {
    assert(key != null);
    final List<int> keyBytes = utf8.encode(key);
    final Digest digest = md5.convert(keyBytes);
    final String keyMd5 = hex.encode(digest.bytes);
    return keyMd5;
  }
}

class PrefixKeyTransform implements FCacheKeyTransform {
  final String prefix;

  PrefixKeyTransform(this.prefix) : assert(prefix != null && prefix.isNotEmpty);

  @override
  String transform(String key) {
    assert(key != null);
    return prefix + key;
  }
}

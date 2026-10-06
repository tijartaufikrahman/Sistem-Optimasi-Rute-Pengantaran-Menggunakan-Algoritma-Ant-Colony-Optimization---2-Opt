import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {

  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const _tokenKey = "token";
  static const _nameKey = "name";
  static const _roleKey = "role";
  static const _idKey = "id";

  Future<void> saveLoginData({
    required String token,
    required String id,
    required String name,
    required String role,
  }) async {

    await _storage.write(
      key: _tokenKey,
      value: token,
    );

    await _storage.write(
      key: _idKey,
      value: id,
    );

    await _storage.write(
      key: _nameKey,
      value: name,
    );

    await _storage.write(
      key: _roleKey,
      value: role,
    );

  }

  Future<Map<String, String?>> getLoginData() async {

    return {

      "token": await _storage.read(
        key: _tokenKey,
      ),

      "id": await _storage.read(
        key: _idKey,
      ),

      "name": await _storage.read(
        key: _nameKey,
      ),

      "role": await _storage.read(
        key: _roleKey,
      ),

    };

  }

  Future<String?> getToken() async {

    return await _storage.read(
      key: _tokenKey,
    );

  }

  Future<void> clearLogin() async {

    await _storage.deleteAll();

  }

  Future<int?> getUserId() async {

    final id = await _storage.read(
      key: _idKey,
    );

    if (id == null) {
      return null;
    }

    return int.parse(id);

  }

}

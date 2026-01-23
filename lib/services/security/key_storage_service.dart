import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyStorageService {
  static const _storage = FlutterSecureStorage();

  static const _masterKeyKey = 'user_master_key';

  Future<void> saveMasterKey(String base64Key) async {
    await _storage.write(
      key: _masterKeyKey,
      value: base64Key,
    );
  }

  Future<String?> getMasterKey() async {
    return await _storage.read(key: _masterKeyKey);
  }

  Future<void> clearMasterKey() async {
    await _storage.delete(key: _masterKeyKey);
  }

  Future<bool> hasMasterKey() async {
    final key = await getMasterKey();
    return key != null && key.isNotEmpty;
  }
}

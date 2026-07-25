import 'package:cryptography/cryptography.dart';

class SessionKeyService {
  SessionKeyService._();
  static final SessionKeyService instance = SessionKeyService._();

  SecretKey? _masterKey;

  bool get hasKey => _masterKey != null;

  SecretKey get key {
    if (_masterKey == null) {
      throw StateError('Master key not initialized');
    }
    return _masterKey!;
  }

  void setKey(SecretKey key) {
    _masterKey = key;
  }

  void clear() {
    _masterKey = null;
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoreInfo {
  final int id;
  final String name;
  final String address;
  const StoreInfo({required this.id, required this.name, required this.address});
}

class StoreService {
  static const _storage = FlutterSecureStorage();
  static const _kId = 'selectedStoreId';
  static const _kName = 'selectedStoreName';
  static const _kAddress = 'selectedStoreAddress';

  static Future<void> saveSelectedStore(StoreInfo store) async {
    await _storage.write(key: _kId, value: store.id.toString());
    await _storage.write(key: _kName, value: store.name);
    await _storage.write(key: _kAddress, value: store.address);
  }

  static Future<StoreInfo?> loadSelectedStore() async {
    final idStr = await _storage.read(key: _kId);
    final name = await _storage.read(key: _kName);
    final address = await _storage.read(key: _kAddress);
    if (idStr == null || name == null || address == null) return null;
    final id = int.tryParse(idStr);
    if (id == null) return null;
    return StoreInfo(id: id, name: name, address: address);
  }

  static Future<int?> getSelectedStoreId() async {
    final idStr = await _storage.read(key: _kId);
    return idStr == null ? null : int.tryParse(idStr);
  }

  static Future<void> clearSelectedStore() async {
    await _storage.delete(key: _kId);
    await _storage.delete(key: _kName);
    await _storage.delete(key: _kAddress);
  }
}


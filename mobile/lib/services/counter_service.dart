import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';

/// Takeaway (T1, T2...) and Delivery (D1, D2...) counter numbers, kept on
/// the server so a counter added on one device shows on every device.
class CounterService {
  final Dio _dio = DioClient.instance.dio;

  /// Counter numbers for [orderType] ('takeaway' or 'delivery').
  Future<List<int>> list(String orderType) async {
    try {
      final res = await _dio.get('/counters');
      return _numbers(res.data['data'], orderType);
    } catch (e) {
      throw DioClient.instance.mapError(e);
    }
  }

  /// Adds the next free counter; returns the updated list.
  Future<List<int>> add(String orderType) async {
    try {
      final res = await _dio.post('/counters/$orderType');
      return _numbers(res.data['data'], orderType);
    } catch (e) {
      throw DioClient.instance.mapError(e);
    }
  }

  /// Removes counter [number]; refused while an order is running on it.
  Future<List<int>> remove(String orderType, int number) async {
    try {
      final res = await _dio.delete('/counters/$orderType/$number');
      return _numbers(res.data['data'], orderType);
    } catch (e) {
      throw DioClient.instance.mapError(e);
    }
  }

  List<int> _numbers(dynamic data, String orderType) {
    final list = (data as Map<String, dynamic>)[orderType] as List<dynamic>? ?? const [];
    return list.map((n) => (n as num).toInt()).toList()..sort();
  }
}

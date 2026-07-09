import '../../core/api_client.dart';

class BodyRepository {
  static Future<void> create(Map<String, dynamic> fields) => ApiClient.post('/api/measurements', fields);

  static Future<void> delete(String id) => ApiClient.delete('/api/measurements/$id');
}

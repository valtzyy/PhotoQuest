import 'api_client.dart';

/// GET /weather?lat=&lng= (backend memanggil Open-Meteo, aplikasi tidak langsung).
class WeatherApi {
  WeatherApi(this._client);
  final ApiClient _client;

  /// JSON mentah agar bisa langsung disimpan ke cache sqflite.
  Future<Map<String, dynamic>> raw(double lat, double lng) =>
      _client.send<Map<String, dynamic>>(
        (dio) => dio.get('/weather', queryParameters: {'lat': lat, 'lng': lng}),
      );
}

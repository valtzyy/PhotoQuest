import 'api_client.dart';

/// GET /currency (kurs via backend -> Frankfurter) dan GET /gear.
class ConverterApi {
  ConverterApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> ratesRaw({String base = 'IDR'}) =>
      _client.send<Map<String, dynamic>>(
        (dio) => dio.get('/currency', queryParameters: {'base': base}),
      );

  Future<List<dynamic>> gearRaw() =>
      _client.send<List<dynamic>>((dio) => dio.get('/gear'));
}

import 'package:http/http.dart' as http;
import 'dart:convert';

class WeatherService {
  static const String _apiKey = 'YOUR_WEATHER_API_KEY'; // Placeholder

  Future<String> getWeather(double lat, double lon) async {
    // Mock weather since no API key
    final List<String> weathers = ['Sunny', 'Cloudy', 'Rainy', 'Partly Cloudy'];
    return weathers[((lat + lon).abs() % 4).toInt()];
  }
}

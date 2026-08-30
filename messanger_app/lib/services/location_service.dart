import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class LocationSuggestion {
  final String value;
  final String fullAddress;

  LocationSuggestion({required this.value, required this.fullAddress});

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return LocationSuggestion(
      value: data['city'] ?? data['settlement'] ?? json['value'],
      fullAddress: json['value'],
    );
  }
}

class LocationService {
  Future<List<LocationSuggestion>> searchCities(String query) async {
    if (query.length < 3) return [];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&countrycodes=ru&accept-language=ru&limit=3',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'Orbita Messenger'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((e) {
          return LocationSuggestion(
            value: e['display_name'].split(',').first.trim(),
            fullAddress: e['display_name'],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      log.e('Ошибка Nominatim: $e');
      return [];
    }
  }
}

import 'dart:convert';

import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final NLatLng latLng;
  final String address;

  const GeocodingResult({required this.latLng, required this.address});
}

class GeocodingService {
  static const String _naverMapKeyId = '6nqz044aws';
  static const String _naverMapKey = 'TRuNcSMkqt3m9z3nqcOZ5iL4o2KezgXjQQ3ix4fC';

  static final RegExp latLngPattern =
      RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$');

  static NLatLng? tryParseLatLngText(String text) {
    final match = latLngPattern.firstMatch(text.trim());
    if (match == null) return null;

    final lat = double.tryParse(match.group(1) ?? '');
    final lng = double.tryParse(match.group(2) ?? '');
    if (lat == null || lng == null || !_isValidLatLng(lat, lng)) {
      return null;
    }
    return NLatLng(lat, lng);
  }

  static bool _isValidLatLng(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  static Future<String> reverseGeocode(NLatLng latLng) async {
    final naver = await _reverseGeocodeFromNaver(latLng);
    if (naver != null && naver.isNotEmpty) {
      return naver;
    }

    final osm = await _reverseGeocodeFromOsm(latLng);
    if (osm != null && osm.isNotEmpty) {
      return osm;
    }

    return '주소 정보 없음';
  }

  static Future<GeocodingResult?> searchAddress(String query) async {
    final naver = await _searchAddressFromNaver(query);
    if (naver != null) {
      return naver;
    }

    final osm = await _searchAddressFromOsm(query);
    if (osm != null) {
      return osm;
    }

    return null;
  }

  static Future<String?> _reverseGeocodeFromNaver(NLatLng latLng) async {
    try {
      final uri = Uri.parse(
        'https://naveropenapi.apigw.ntruss.com/map-reversegeocode/v2/gc'
        '?coords=${latLng.longitude},${latLng.latitude}'
        '&output=json&orders=roadaddr,addr',
      );

      final response = await http.get(
        uri,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': _naverMapKeyId,
          'X-NCP-APIGW-API-KEY': _naverMapKey,
        },
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final region = first['region'] as Map<String, dynamic>?;
      final land = first['land'] as Map<String, dynamic>?;

      final area1 = (region?['area1']?['name'] ?? '').toString();
      final area2 = (region?['area2']?['name'] ?? '').toString();
      final area3 = (region?['area3']?['name'] ?? '').toString();
      final number1 = (land?['number1'] ?? '').toString();
      final number2 = (land?['number2'] ?? '').toString();
      final number = number2.isNotEmpty ? '$number1-$number2' : number1;

      final address = '$area1 $area2 $area3 $number'.trim();
      return address.isEmpty ? null : address;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _reverseGeocodeFromOsm(NLatLng latLng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=${latLng.latitude}&lon=${latLng.longitude}',
      );
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'fitple-app/1.0',
          'Accept-Language': 'ko,en',
        },
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final displayName = (data['display_name'] ?? '').toString().trim();
      return displayName.isEmpty ? null : displayName;
    } catch (_) {
      return null;
    }
  }

  static Future<GeocodingResult?> _searchAddressFromNaver(String query) async {
    try {
      final uri = Uri.parse(
        'https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode'
        '?query=${Uri.encodeQueryComponent(query)}&count=1',
      );

      final response = await http.get(
        uri,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': _naverMapKeyId,
          'X-NCP-APIGW-API-KEY': _naverMapKey,
        },
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final addresses = data['addresses'] as List<dynamic>?;
      if (addresses == null || addresses.isEmpty) return null;

      final first = addresses.first as Map<String, dynamic>;
      final lat = double.tryParse((first['y'] ?? '').toString());
      final lng = double.tryParse((first['x'] ?? '').toString());
      if (lat == null || lng == null || !_isValidLatLng(lat, lng)) return null;

      final address =
          (first['roadAddress'] ?? first['jibunAddress'] ?? query).toString().trim();
      return GeocodingResult(latLng: NLatLng(lat, lng), address: address);
    } catch (_) {
      return null;
    }
  }

  static Future<GeocodingResult?> _searchAddressFromOsm(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=jsonv2&limit=1&q=${Uri.encodeQueryComponent(query)}',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'fitple-app/1.0',
          'Accept-Language': 'ko,en',
        },
      );

      if (response.statusCode != 200) return null;

      final list = json.decode(response.body) as List<dynamic>;
      if (list.isEmpty) return null;

      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse((first['lat'] ?? '').toString());
      final lng = double.tryParse((first['lon'] ?? '').toString());
      if (lat == null || lng == null || !_isValidLatLng(lat, lng)) return null;

      final address = (first['display_name'] ?? query).toString().trim();
      return GeocodingResult(latLng: NLatLng(lat, lng), address: address);
    } catch (_) {
      return null;
    }
  }
}

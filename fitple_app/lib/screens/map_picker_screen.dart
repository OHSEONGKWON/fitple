import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapPickerScreen extends StatefulWidget {
  final NLatLng? initialLatLng;

  const MapPickerScreen({super.key, this.initialLatLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _defaultLatLng = NLatLng(37.5665, 126.9780);

  NLatLng? _selectedLatLng;
  String _selectedAddress = '';
  bool _isLoading = false;
  NaverMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _selectedLatLng = widget.initialLatLng;
    if (widget.initialLatLng != null) {
      _reverseGeocode(widget.initialLatLng!);
    }
  }

  Future<void> _reverseGeocode(NLatLng latLng) async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(
        'https://naveropenapi.apigw.ntruss.com/map-reversegeocode/v2/gc'
        '?coords=${latLng.longitude},${latLng.latitude}'
        '&output=json&orders=roadaddr,addr',
      );
      final response = await http.get(
        uri,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': '6nqz044aws',
          'X-NCP-APIGW-API-KEY': 'TRuNcSMkqt3m9z3nqcOZ5iL4o2KezgXjQQ3ix4fC',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final region = results[0]['region'] as Map<String, dynamic>;
          final land = results[0]['land'] as Map<String, dynamic>?;
          final area1 = region['area1']?['name'] ?? '';
          final area2 = region['area2']?['name'] ?? '';
          final area3 = region['area3']?['name'] ?? '';
          final number1 = land?['number1'] ?? '';
          final number2 = land?['number2'] ?? '';
          final numberStr = number2.isNotEmpty ? '$number1-$number2' : number1;
          setState(() => _selectedAddress = '$area1 $area2 $area3 $numberStr'.trim());
        }
      }
    } catch (_) {
      setState(() => _selectedAddress =
          '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final initialCenter = widget.initialLatLng ?? _defaultLatLng;

    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 선택', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedLatLng != null)
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'latLng': _selectedLatLng,
                'address': _selectedAddress,
              }),
              child: const Text(
                '확인',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: kIsWeb
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '지도 기능은 모바일 앱에서 이용해주세요',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: initialCenter,
                zoom: 14,
              ),
              mapType: NMapType.basic,
              nightModeEnable: isDarkMode,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              if (widget.initialLatLng != null) {
                _updateMarker(widget.initialLatLng!);
              }
            },
            onMapTapped: (point, latLng) {
              setState(() {
                _selectedLatLng = latLng;
                _selectedAddress = '';
              });
              _updateMarker(latLng);
              _reverseGeocode(latLng);
            },
          ),

          // 상단 안내 문구
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, color: Color(0xFF00E676), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '지도를 탭하여 위치를 선택하세요',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 선택된 주소 표시
          if (_selectedLatLng != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '선택된 위치',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_isLoading)
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF00E676)),
                      )
                    else
                      Text(
                        _selectedAddress.isEmpty
                            ? '${_selectedLatLng!.latitude.toStringAsFixed(5)}, ${_selectedLatLng!.longitude.toStringAsFixed(5)}'
                            : _selectedAddress,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, {
                          'latLng': _selectedLatLng,
                          'address': _selectedAddress,
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '이 위치로 설정',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }


  Future<void> _updateMarker(NLatLng latLng) async {
    if (_mapController == null) return;
    await _mapController!.clearOverlays();
    final marker = NMarker(id: 'selected', position: latLng);
    await _mapController!.addOverlay(marker);
  }
}

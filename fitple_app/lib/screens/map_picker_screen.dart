import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../services/geocoding_service.dart';

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
  bool _isSearching = false;
  NaverMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedLatLng = widget.initialLatLng;
    if (widget.initialLatLng != null) {
      _reverseGeocode(widget.initialLatLng!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(NLatLng latLng) async {
    setState(() => _isLoading = true);
    try {
      final address = await GeocodingService.reverseGeocode(latLng);
      if (!mounted) return;
      setState(() => _selectedAddress = address);
    } catch (_) {
      if (!mounted) return;
      setState(() => _selectedAddress = '주소 정보 없음');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchAddressAndMove() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색할 주소를 입력해주세요.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);
    try {
      final found = await GeocodingService.searchAddress(query);
      if (!mounted) return;
      if (found == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 결과가 없습니다. 다른 키워드로 시도해주세요.')),
        );
        return;
      }

      setState(() {
        _selectedLatLng = found.latLng;
        _selectedAddress = found.address;
      });

      await _updateMarker(found.latLng);
      if (_mapController != null) {
        final update = NCameraUpdate.scrollAndZoomTo(
          target: found.latLng,
          zoom: 16,
        );
        await _mapController!.updateCamera(update);
      }
      await _reverseGeocode(found.latLng);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소 검색 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _searchAddressAndMove(),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '주소 검색 (예: 강남역)',
                            filled: true,
                            fillColor: isDarkMode
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _isSearching ? null : _searchAddressAndMove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSearching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.black.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app, color: Color(0xFF00E676), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '지도를 탭하거나 주소로 위치를 검색하세요',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                            ? '주소를 불러오는 중입니다...'
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

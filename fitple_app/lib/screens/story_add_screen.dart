import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

class StorySelectionScreen extends StatefulWidget {
  // 주의: 파라미터 이름이 onSourceSelected에서 onImageSelected로 바뀌었습니다!
  final Function(Uint8List) onImageSelected;

  const StorySelectionScreen({super.key, required this.onImageSelected});

  @override
  State<StorySelectionScreen> createState() => _StorySelectionScreenState();
}

class _StorySelectionScreenState extends State<StorySelectionScreen> {
  List<AssetEntity> _mediaList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGalleryImages();
  }

  // 기기 갤러리 사진 불러오기 로직
  Future<void> _fetchGalleryImages() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _mediaList = [];
          _isLoading = false;
        });
      }
      return;
    }

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.image,
      );
      if (albums.isNotEmpty) {
        // 최근 사진 60장 불러오기
        List<AssetEntity> media = await albums[0].getAssetListPaged(page: 0, size: 60);
        if (mounted) {
          setState(() {
            _mediaList = media;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      // 권한 거부 시 설정창 안내
      PhotoManager.openSetting();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (mounted) {
        Navigator.pop(context); // 선택 창 닫기
        widget.onImageSelected(bytes); // 업로드 실행
      }
    }
  }

  // 상단 카메라 버튼 로직
  Future<void> _pickFromCamera() async => _pickImage(ImageSource.camera);

  Future<void> _pickFromGallery() async => _pickImage(ImageSource.gallery);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isWeb = kIsWeb;
    final topActionIcon = isWeb ? Icons.photo_library : Icons.camera_alt_rounded;
    final topActionTitle = isWeb ? '사진 선택' : '카메라로 촬영';
    final topActionSubtitle = isWeb
        ? '웹에서는 파일 선택 창을 이용해 이미지를 업로드하세요.'
        : '지금 바로 사진을 찍어 스토리에 공유하세요.';
    final VoidCallback topActionTap = isWeb ? _pickFromGallery : _pickFromCamera;

    return Scaffold(
      appBar: AppBar(
        title: const Text('스토리 추가', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // 1. 상단 카메라로 촬영 버튼
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: GestureDetector(
              onTap: topActionTap,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!isDarkMode)
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                  ],
                  border: Border.all(
                    color: isDarkMode ? Colors.white12 : Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(topActionIcon, size: 28, color: const Color(0xFF00E676)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topActionTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            topActionSubtitle,
                            style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. 하단 갤러리 미리보기 (그리드 형태)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF121212) : Colors.grey[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      '최근 항목',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                        : kIsWeb
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '웹에서는 파일 선택 창을 이용해 이미지를 업로드하세요.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDarkMode ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _pickFromGallery,
                                      icon: const Icon(Icons.photo_library),
                                      label: const Text('사진 선택'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00E676),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _mediaList.isEmpty
                                ? const Center(child: Text('사진이 없습니다.', style: TextStyle(color: Colors.grey)))
                                : GridView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3, // 3열 배치
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: _mediaList.length,
                                    itemBuilder: (context, index) {
                                      final asset = _mediaList[index];
                                      return GestureDetector(
                                        onTap: () async {
                                          // 갤러리 사진을 눌렀을 때
                                          final file = await asset.file;
                                          if (file != null) {
                                            final bytes = await file.readAsBytes();
                                            if (mounted) {
                                              Navigator.pop(context); // 창 닫고
                                              widget.onImageSelected(bytes); // 업로드 실행
                                            }
                                          }
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: FutureBuilder<Uint8List?>(
                                            // 썸네일을 가져와 화면에 그림 (메모리 최적화)
                                            future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.done &&
                                                  snapshot.data != null) {
                                                return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                              }
                                              return Container(
                                                color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
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
}
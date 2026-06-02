import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isPosting = false;

  String get _nickname =>
      Supabase.instance.client.auth.currentUser?.userMetadata?['display_name']
          as String? ??
      Supabase.instance.client.auth.currentUser?.email?.split('@').first ??
      '사용자';

  @override
  void dispose() {
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name;
    });
    _focusNode.requestFocus();
  }

  Future<void> _post() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _imageBytes == null) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isPosting = true);
    try {
      String? imageUrl;
      if (_imageBytes != null) {
        final ext = (_imageName ?? 'photo.jpg').split('.').last;
        final fileName =
            'posts/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await Supabase.instance.client.storage
            .from('posts')
            .uploadBinary(fileName, _imageBytes!,
                fileOptions: const FileOptions(upsert: false));
        imageUrl = fileName;
      }
      await Supabase.instance.client.from('posts').insert({
        'user_id': user.id,
        'user_nickname': _nickname,
        'content': content.isEmpty ? null : content,
        'image_url': imageUrl,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('게시 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white54 : Colors.black45;
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final divColor = isDarkMode ? Colors.white12 : Colors.grey.shade200;
    final hasContent =
        _contentController.text.trim().isNotEmpty || _imageBytes != null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('새 게시물',
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: (hasContent && !_isPosting) ? _post : null,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                backgroundColor: hasContent && !_isPosting
                    ? const Color(0xFF00E676).withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF00E676)))
                  : Text(
                      '공유하기',
                      style: TextStyle(
                        color: hasContent
                            ? const Color(0xFF00E676)
                            : subColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: divColor),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── 이미지 영역 ──
                  GestureDetector(
                    onTap: _pickImage,
                    child: _imageBytes != null
                        ? Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: Image.memory(_imageBytes!,
                                    fit: BoxFit.cover,
                                    width: double.infinity),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _imageBytes = null;
                                    _imageName = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.photo_library_outlined,
                                            color: Colors.white, size: 15),
                                        SizedBox(width: 4),
                                        Text('변경',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: double.infinity,
                              height: kIsWeb ? 320 : MediaQuery.of(context).size.width,
                              color: isDarkMode
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.grey.shade100,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.add_photo_alternate_outlined,
                                        size: 36, color: subColor),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    '사진을 선택하세요',
                                    style: TextStyle(
                                        color: subColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    kIsWeb ? '클릭하여 파일 선택' : '탭하여 갤러리 열기',
                                    style: TextStyle(
                                        color: subColor, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                  ),

                  // ── 캡션 입력 (인스타처럼 아바타 + 텍스트) ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 프로필 아바타
                        CircleAvatar(
                          radius: 19,
                          backgroundColor:
                              const Color(0xFF00E676).withValues(alpha: 0.2),
                          child: const Icon(Icons.person,
                              color: Color(0xFF00E676), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nickname,
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _contentController,
                                focusNode: _focusNode,
                                onChanged: (_) => setState(() {}),
                                maxLines: null,
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                    height: 1.5),
                                decoration: InputDecoration(
                                  hintText: '문구를 입력하세요...',
                                  hintStyle: TextStyle(
                                      color: subColor, fontSize: 15),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: divColor),
                ],
              ),
            ),
          ),

          // ── 하단 도구 바 ──
          Container(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Divider(height: 1, color: divColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Row(children: [
                            Icon(Icons.photo_library_outlined,
                                color: const Color(0xFF00E676), size: 22),
                            const SizedBox(width: 6),
                            Text(kIsWeb ? '파일 선택' : '갤러리',
                                style: const TextStyle(
                                    color: Color(0xFF00E676),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ]),
                        ),
                        if (!kIsWeb) ...[
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 85);
                              if (picked == null) return;
                              final bytes = await picked.readAsBytes();
                              setState(() {
                                _imageBytes = bytes;
                                _imageName = picked.name;
                              });
                              _focusNode.requestFocus();
                            },
                            child: Row(children: [
                              Icon(Icons.camera_alt_outlined,
                                  color: subColor, size: 22),
                              const SizedBox(width: 6),
                              Text('카메라',
                                  style: TextStyle(
                                      color: subColor, fontSize: 14)),
                            ]),
                          ),
                        ],
                      ],
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

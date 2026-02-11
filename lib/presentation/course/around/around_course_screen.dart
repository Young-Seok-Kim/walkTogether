import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../model/walk_record_model.dart';
import '../../../viewmodel/course/around_course_notifier.dart';
import '../../../viewmodel/course/my_course_list_notifier.dart';
import '../mine/my_course_detail_screen.dart';

class AroundCourseScreen extends ConsumerWidget {
  const AroundCourseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(aroundCourseProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // _buildHeader(),
          Expanded(
            child: coursesAsync.when(
              data: (courses) {
                if (courses.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(aroundCourseProvider);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        _buildEmptyState(),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    // 📍 여기서 데이터를 새로 불러옵니다.
                    ref.invalidate(aroundCourseProvider);
                  },
                  child: ListView.builder(
                    itemCount: courses.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      return _buildAroundCourseCard(
                        context,
                        ref,
                        course,
                      ); // ✅ ref 전달
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text("데이터를 불러오지 못했습니다.\n$err", textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAroundCourseCard(
      BuildContext context,
      WidgetRef ref,
      WalkRecord course,
      ) {
    final bool isLiked = course.isLiked ?? false;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // ✅ GestureDetector로 전체 영역을 하나로 묶습니다.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 카드 전체(빈 공간 포함) 터치 인식
        onTap: () {
          // 싱글 탭: 상세 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseDetailScreen(course: course),
            ),
          );
        },
        onDoubleTap: () {
          // 더블 탭: 좋아요 토글
          if (course.id != null) {
            ref.read(aroundCourseProvider.notifier).toggleLike(course.id!);
            HapticFeedback.lightImpact();

            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(!isLiked ? "이 코스를 좋아합니다! ❤️" : "좋아요를 취소했습니다. 💔"),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              // 1. 썸네일 (AbsorbPointer로 내부 지도 클릭 방지)
              Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent.withOpacity(0.1), blurRadius: 10),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AbsorbPointer( // 지도가 제스처를 뺏어가지 못하게 막음
                    child: OverflowBox(
                      minHeight: 180,
                      maxHeight: 180,
                      alignment: const Alignment(0, -0.6),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: course.path.isNotEmpty ? course.path.first.latLng : const LatLng(37.5665, 126.9780),
                          zoom: 15,
                        ),
                        key: ValueKey('map_${course.id}'),
                        liteModeEnabled: false,
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 2. 정보 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF2D2D2D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildProfileImage(course.kakaoUserProfileUrl),
                        const SizedBox(width: 4),
                        Text(
                          course.kakaoUserNickname ?? '익명',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _modernBadge(Icons.straighten, "${(course.distance / 1000).toStringAsFixed(1)}km", const Color(0xFF4A90E2)),
                        const SizedBox(width: 8),
                        _modernBadge(isLiked ? Icons.favorite : Icons.favorite_border, "${course.likeCount ?? 0}", isLiked ? Colors.redAccent : Colors.grey[500]!),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black12),
            ],
          ),
        ),
      ),
    );
  }

// 프로필 이미지 빌더 (중복 제거용)
  Widget _buildProfileImage(String? url) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: (url != null && url.isNotEmpty)
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 12, color: Colors.grey))
            : const Icon(Icons.person, size: 12, color: Colors.grey),
      ),
    );
  }

  // 💡 현대적인 배지 위젯
  Widget _modernBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), // 아주 연한 배경색
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 아이콘 색상 지원하도록 수정
  Widget _infoBadge(IconData icon, String label, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor ?? Colors.grey[400]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "주변에 등록된 코스가 없어요.\n첫 번째 코스를 등록해 보세요!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

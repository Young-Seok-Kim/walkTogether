import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../viewmodel/course/my_course_list_notifier.dart';
import 'my_course_detail_screen.dart';


class MyCourseListScreen extends ConsumerWidget {
  const MyCourseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(myCourseListProvider);

    return coursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('에러 발생: $err')),
      data: (courses) {
        if (courses.isEmpty) {
          return const Center(child: Text('저장된 산책 기록이 없습니다.'));
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(myCourseListProvider.notifier).refresh(),
          child: ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];

              // Dismissible로 감싸서 삭제 기능을 추가합니다.
              return Dismissible(
                // 고유한 키가 필요합니다. 기록의 ID를 사용하세요.
                key: Key(course.id ?? index.toString()),

                // 밀기 방향 (오른쪽에서 왼쪽으로)
                direction: DismissDirection.endToStart,

                // 밀었을 때 뒤에 보일 배경 (빨간색 휴지통)
                background: Container(
                  color: Colors.redAccent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),

                // 삭제 전 확인 창 띄우기 (실수 방지)
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('기록 삭제'),
                      content: const Text('이 산책 기록을 정말 삭제하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },

                // 확인 후 삭제 로직 실행
                onDismissed: (direction) {
                  // ✅ Notifier의 삭제 함수 호출
                  ref.read(myCourseListProvider.notifier).removeRecord(course.id!);

                  // 하단에 간단한 알림(SnackBar) 띄우기
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${course.title} 기록이 삭제되었습니다.')),
                  );
                },

                child: ListTile(
                  leading: const Icon(Icons.directions_walk, color: Colors.blueAccent),
                  title: Text(
                    course.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Row(
                    children: [
                      // 1. 거리 표시
                      Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('${(course.distance / 1000).toStringAsFixed(2)}km'),

                      const SizedBox(width: 12), // 간격 조절

                      Icon(Icons.favorite, size: 14, color: Colors.redAccent[100]),
                      const SizedBox(width: 4),
                      Text('${course.likeCount ?? 0}'), // null 대비 0 처리
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CourseDetailScreen(course: course)),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
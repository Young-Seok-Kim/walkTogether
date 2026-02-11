import 'dart:async';
import 'dart:ffi';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../../model/walk_record_model.dart';
import '../../repository/walk_repository.dart';
import '../auth_notifier.dart';

final myCourseListProvider = AsyncNotifierProvider<MyCourseListNotifier, List<WalkRecord>>(() {
  return MyCourseListNotifier();
});

final userTotalLikesProvider = Provider<int>((ref) {
  final coursesAsync = ref.watch(myCourseListProvider);
  // ✅ 카카오 모델 정보 가져오기
  final kakaoUser = ref.watch(kakaoUserProvider);

  return coursesAsync.maybeWhen(
    data: (courses) {
      if (kakaoUser == null) return 0;

      // 🎯 코스 작성자 ID와 내 카카오 ID가 같은지 비교!
      return courses
          .where((course) => course.kakaoUserId == kakaoUser.id)
          .fold(0, (sum, course) => sum + (course.likeCount ?? 0));
    },
    orElse: () => 0,
  );
});

// 3. 뷰모델 클래스 정의
class MyCourseListNotifier extends AsyncNotifier<List<WalkRecord>> {

  @override
  FutureOr<List<WalkRecord>> build() async {
    return _fetchInitialData();
  }

  Future<List<WalkRecord>> _fetchInitialData() async {
    try {
      var kakakoUser = ref.watch(kakaoUserProvider);

      final records = await ref.read(walkRepositoryProvider).fetchMyWalks(
        kakakoUser?.id ?? null
      );
      return records;
    } catch (e) {
      rethrow;
    }
  }

  void addRecordLocally(WalkRecord newRecord) {
    state.whenData((currentList) {
      state = AsyncValue.data([newRecord, ...currentList]);
    });
  }

  Future<void> removeRecord(String recordId) async {
    try {
      await ref.read(walkRepositoryProvider).deleteWalk(recordId);
      if (state.hasValue) {
        state = AsyncData(
          state.value!.where((record) => record.id != recordId).toList(),
        );
      }
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchInitialData());
  }

  void updateLikeStatusLocally({
    required String courseId,
    required bool isLiked,
    required String userId,
  }) {
    if (!state.hasValue) return; // 아직 데이터를 불러온 적이 없다면 패스

    state = AsyncValue.data(state.value!.map((record) {
      if (record.id == courseId) {
        return record.copyWith(
          kakaoUserProfileUrl: record.kakaoUserProfileUrl,
          isLiked: isLiked,
          likeCount: isLiked ? record.likeCount + 1 : record.likeCount - 1,
          likedUserIds: isLiked
              ? [...record.likedUserIds, userId]
              : record.likedUserIds.where((id) => id != userId).toList(),
        );
      }
      return record;
    }).toList());
  }
}
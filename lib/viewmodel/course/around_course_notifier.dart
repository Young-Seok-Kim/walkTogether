
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:walk_together/viewmodel/auth_notifier.dart';

import '../../model/walk_record_model.dart';
import '../../repository/walk_repository.dart';
import 'my_course_list_notifier.dart';

final aroundCourseProvider = AsyncNotifierProvider<AroundCourseNotifier, List<WalkRecord>>(() {
  return AroundCourseNotifier();
});

class AroundCourseNotifier extends AsyncNotifier<List<WalkRecord>> {
  @override
  FutureOr<List<WalkRecord>> build() async {
    Position pos = await Geolocator.getCurrentPosition();

    final user = await ref.read(authProvider.notifier).getOrFetchKakaoUser();

    final List<WalkRecord> nearbyWalks = await ref.read(walkRepositoryProvider).fetchNearbyWalks(
      lat: pos.latitude,
      lng: pos.longitude,
    );

    return nearbyWalks.map((record) {
      // 유저가 로그인 상태이고, 해당 코스의 likedUserIds에 내 ID가 있다면 isLiked를 true로 설정
      final bool isLikedByMe = record.likedUserIds.contains(user.id);

      return record.copyWith(isLiked: isLikedByMe);
    }).toList();
  }

  Future<void> toggleLike(String courseId) async {
    try {
      var user = await ref.read(authProvider.notifier).getOrFetchKakaoUser();

      final currentState = state.value ?? [];

      bool wasAlreadyLiked = false;
      bool isNowLiked = false;


      state = AsyncValue.data(currentState.map((record) {
        if (record.id == courseId) {
          wasAlreadyLiked = record.isLiked;
          isNowLiked = !wasAlreadyLiked;
          return record.copyWith(
            firebaseUserId: record.firebaseUserId,
            kakaoUserId: record.kakaoUserId,
            kakaoUserNickname: record.kakaoUserNickname,
            kakaoUserProfileUrl: record.kakaoUserProfileUrl,
            isLiked: isNowLiked,
            likeCount: isNowLiked ? record.likeCount + 1 : record.likeCount - 1,
            likedUserIds: isNowLiked
                ? [...record.likedUserIds, user.id.toString()]
                : record.likedUserIds.where((id) => id != user.id.toString()).toList(),
          );
        }
        return record;
      }).toList());

      ref.read(myCourseListProvider.notifier).updateLikeStatusLocally(
        courseId: courseId,
        isLiked: isNowLiked,
        userId: user.id,
      );

      final docRef = FirebaseFirestore.instance.collection('walks').doc(courseId);
      if (wasAlreadyLiked) {
        await docRef.update({
          'likedUserIds': FieldValue.arrayRemove([user.id.toString()]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await docRef.update({
          'likedUserIds': FieldValue.arrayUnion([user.id.toString()]),
          'likeCount': FieldValue.increment(1),
        });
      }

      if(!isNowLiked) return;

      final myInfo = await ref.read(authProvider.notifier).getOrFetchKakaoUser();
      final targetCourse = state.value?.firstWhere((c) => c.id == courseId); // 좋아요 누른 코스 정보

      if (targetCourse != null) {
        // myInfo.id -> myInfo.uid 로 변경
        // if (!wasAlreadyLiked && targetCourse.kakaoUserId != myInfo.id) { // todo 내 코스는 좋아요 알림 안오게 하는 코드
          await FirebaseFirestore.instance.collection('notifications').add({
            'receiverId': targetCourse.kakaoUserId,
            'courseId': targetCourse.id,
            'senderId': myInfo.id,
            'senderName': myInfo.nickname ?? '익명', // 닉네임 필드명 확인 필요!
            'courseTitle': targetCourse.title,
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'like',
          });
        // }
      }
    } catch (e) {
      ref.invalidateSelf(); // 에러 시 롤백
    }
  }
}
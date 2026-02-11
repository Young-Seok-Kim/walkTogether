import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../model/kakao_model.dart';

final kakaoUserProvider = StateProvider<KakaoModel?>((ref) => null);

final authProvider = NotifierProvider<AuthNotifier, AsyncValue<User?>>(
  () => AuthNotifier(),
);

class AuthNotifier extends Notifier<AsyncValue<User?>> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  AsyncValue<User?> build() {
    final currentUser = _auth.currentUser;

    // 2. 이미 로그인 상태라면? 카카오 정보 긁어오기 (시동 걸기 ㅋ)
    if (currentUser != null) {
      // build 실행 직후에 안전하게 비동기 함수 실행!
      Future.microtask(() => syncKakaoInfo());
    }

    return AsyncValue.data(currentUser);
  }

  Future<void> loginWithKakao() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      bool isInstalled = await kakao.isKakaoTalkInstalled();

      if (isInstalled) {
        await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // ✅ 1. 여기서 정보를 동기화하고 주머니(kakaoUserProvider)를 채웁니다.
      await syncKakaoInfo();

      // ✅ 2. 주머니에 들어간 최신 정보를 꺼내옵니다.
      final kakaoInfo = ref.read(kakaoUserProvider);

      final userCredential = await _auth.signInAnonymously();
      User? fbUser = userCredential.user;

      if (fbUser != null && kakaoInfo != null) {
        // ✅ 3. 카카오 모델에서 꺼낸 정보를 파이어베이스 프로필에 업데이트!
        await fbUser.updatePhotoURL(kakaoInfo.profileUrl);
        await fbUser.updateDisplayName(kakaoInfo.nickname);
        await fbUser.reload();

        await syncUserToFirestore();
      }

      return _auth.currentUser;
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await kakao.UserApi.instance.logout();
      await _auth.signOut();

      // 🔥 로그아웃하면 카카오 주머니도 깔끔하게 비워주기!
      ref.read(kakaoUserProvider.notifier).state = null;

      return null;
    });
  }

  Future<void> syncKakaoInfo() async {
    try {
      final user = await kakao.UserApi.instance.me();

      ref.read(kakaoUserProvider.notifier).state = KakaoModel(
        id: user.id.toString(),
        nickname: user.kakaoAccount?.profile?.nickname ?? "산책자",
        profileUrl: user.kakaoAccount?.profile?.profileImageUrl,
      );
      print("✅ 카카오 정보 동기화 완료: ${user.id}");
    } catch (e) {
      print("❌ 카카오 정보 동기화 에러: $e");
    }
  }

  Future<KakaoModel> getOrFetchKakaoUser() async {
    // 1. 먼저 현재 주머니(kakaoUserProvider)에 정보가 있는지 확인
    final currentInfo = ref.read(kakaoUserProvider);
    if (currentInfo != null) return currentInfo;

    // 2. 주머니가 비어있다면 서버에서 직접 긁어오기 (syncKakaoInfo 로직 활용)
    try {
      final user = await kakao.UserApi.instance.me();
      final model = KakaoModel(
        id: user.id.toString(),
        nickname: user.kakaoAccount?.profile?.nickname ?? "산책자",
        profileUrl: user.kakaoAccount?.profile?.profileImageUrl,
      );

      // 주머니 업데이트 (캐싱)
      ref.read(kakaoUserProvider.notifier).state = model;
      return model;
    } catch (e) {
      print("❌ 공통 함수에서 카카오 정보 로드 실패: $e");
      return KakaoModel(id: 'unknown', nickname: '산책자', profileUrl: null);
    }
  }

  // Future<void> updateFCMToken() async {
  //   // state.value는 현재 로그인된 유저 정보(User객체)입니다.
  //   final user = state.value;
  //   if (user == null) return;
  //
  //   try {
  //     String? token = await FirebaseMessaging.instance.getToken();
  //     if (token != null) {
  //       // 🎯 [중요] .doc(user.uid)가 아까 확인한 '4728516873' 같은 카카오 ID인지 확인하세요!
  //       // 만약 user.uid가 아니라면 user.id 등 실제 문서 ID로 쓰이는 값을 넣으셔야 합니다.
  //       await FirebaseFirestore.instance
  //           .collection('users')
  //           .doc(user.uid.toString())
  //           .update({'fcmToken': token});
  //
  //       print("✅ ViewModel: FCM 토큰 업데이트 성공");
  //     }
  //   } catch (e) {
  //     print("❌ ViewModel: FCM 토큰 업데이트 실패: $e");
  //   }
  // }

  Future<void> syncUserToFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final kakaoUser = await getOrFetchKakaoUser();

      String? token;
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        token = await FirebaseMessaging.instance.getToken();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(kakaoUser.id.toString())
          .set({
            'firebaseId': FirebaseAuth.instance.currentUser?.uid,
            'kakaoId': kakaoUser.id.toString(),
            'kakaoNickname': kakaoUser.nickname,
            'kakaoProfileUrl': kakaoUser.profileUrl,
            'fcmToken': token,
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      print("✅ [성공] 유저 정보 & FCM 토큰 동기화 완료! (토큰: $token)");
    } catch (e) {
      print("❌ [실패] 유저 정보 저장 중 오류 발생: $e");
    }
  }
}

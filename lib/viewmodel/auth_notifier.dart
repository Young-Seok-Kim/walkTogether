import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../model/kakao_model.dart';

final kakaoUserProvider = StateProvider<KakaoModel?>((ref) => null);
final guestLoginEnabledProvider = StateProvider<bool>((ref) => false);

final authProvider = NotifierProvider<AuthNotifier, AsyncValue<User?>>(
  () => AuthNotifier(),
);

class AuthNotifier extends Notifier<AsyncValue<User?>> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  AsyncValue<User?> build() {
    fetchAuthSettings();
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

  Future<void> loginAsGuest() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      // 1. Firebase 익명 로그인 (카카오 인증 없이 즉시 통과)
      final userCredential = await _auth.signInAnonymously();
      User? fbUser = userCredential.user;

      if (fbUser != null) {
        // 2. 파이어베이스 프로필에 '게스트' 표시
        await fbUser.updateDisplayName("게스트");
        await fbUser.reload();

        // 3. Firestore에 게스트 데이터 생성
        // 카카오 ID가 없으므로 fbUser.uid를 문서 ID로 사용합니다.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(fbUser.uid)
            .set({
          'firebaseId': fbUser.uid,
          'kakaoId': 'guest_${fbUser.uid}', // 게스트 구분용 임시 ID
          'kakaoNickname': "게스트",
          'isGuest': true,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print("✅ 게스트 로그인 성공 (UID: ${fbUser.uid})");
      }
      return _auth.currentUser;
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        // ✅ 1. 우리 앱의 카카오 주머니가 채워져 있는지 먼저 확인
        final kakaoUser = ref.read(kakaoUserProvider);

        // 주머니에 정보가 있다면 카카오 로그인을 했던 유저임
        if (kakaoUser != null) {
          // 혹시 모를 상황을 대비해 토큰 존재 여부도 한 번 더 체크
          if (await kakao.AuthApi.instance.hasToken()) {
            await kakao.UserApi.instance.logout();
            print("✅ 카카오 로그아웃 완료");
          }
        }
      } catch (e) {
        // 익명 로그인 상태라면 여기서 에러가 날 수 있지만, 무시하고 진행
        print("⚠️ 카카오 로그아웃 건너뜀 (익명 유저일 가능성 높음): $e");
      }

      // 2. Firebase 로그아웃 (익명이든 카카오든 무조건 수행)
      await _auth.signOut();

      // 3. 상태 초기화
      ref.read(kakaoUserProvider.notifier).state = null;

      print("✅ 전체 로그아웃 처리 완료");
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

  Future<void> fetchAuthSettings() async {
    try {
      final doc = await _db.collection('config').doc('auth').get();

      if (doc.exists) {
        final isEnabled = doc.data()?['isGuestLoginEnabled'] ?? false;

        // ✅ .state = isEnabled 보다 더 확실한 업데이트 방식입니다.
        ref.read(guestLoginEnabledProvider.notifier).update((state) => isEnabled);

        print("✅ 게스트 로그인 활성화 상태: $isEnabled");
      }
    } catch (e) {
      print("❌ 설정 로드 실패: $e");
    }
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = _auth.currentUser;
      if (user == null) return null;

      try {
        final kakaoUser = ref.read(kakaoUserProvider);

        // 1. 산책 기록(walks) 삭제 쿼리 준비
        // 카카오 유저라면 kakaoUserId로, 게스트라면 firebaseUserId로 찾습니다.
        QuerySnapshot walksQuery;
        if (kakaoUser != null) {
          walksQuery = await _db
              .collection('walks')
              .where('kakaoUserId', isEqualTo: kakaoUser.id.toString())
              .get();
        } else {
          walksQuery = await _db
              .collection('walks')
              .where('firebaseUserId', isEqualTo: user.uid)
              .get();
        }

        // 2. Batch를 사용하여 모든 산책 기록 삭제
        final batch = _db.batch();
        for (var doc in walksQuery.docs) {
          batch.delete(doc.reference);
        }

        // 3. 유저 프로필(users) 문서 삭제
        // 카카오 유저는 id 문자열, 게스트는 firebase UID가 문서 ID입니다.
        String userDocId = (kakaoUser != null) ? kakaoUser.id.toString() : user.uid;
        batch.delete(_db.collection('users').doc(userDocId));

        // Batch 실행 (산책 기록 + 유저 정보 한꺼번에 삭제)
        await batch.commit();
        print("✅ Firestore 모든 데이터 삭제 완료");

        // 4. 카카오 연결 끊기 (카카오 유저일 경우)
        if (kakaoUser != null && await kakao.AuthApi.instance.hasToken()) {
          await kakao.UserApi.instance.unlink();
        }

        // 5. Firebase 인증 계정 삭제 (마지막 단계)
        await user.delete();
        print("✅ 회원 탈퇴 완료");

      } catch (e) {
        print("❌ 탈퇴 처리 실패: $e");
        // 만약 'requires-recent-login' 에러가 나면
        // "보안을 위해 다시 로그인 후 시도해주세요"라는 안내가 필요합니다.
      }

      ref.read(kakaoUserProvider.notifier).state = null;
      return null;
    });
  }
}

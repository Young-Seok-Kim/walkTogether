import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodel/auth_notifier.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: authState.when(
        // 데이터 상태일 때 (유저가 null인 경우 포함)
        data: (user) => _buildBody(context, ref),
        // 카카오톡 이동 및 Firebase 처리 중일 때
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("카카오 로그인 중...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        // 에러 발생 시
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("로그인 중 에러가 발생했습니다.\n$error", textAlign: TextAlign.center),
              TextButton(
                onPressed: () => ref.refresh(authProvider),
                child: const Text("다시 시도"),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // const Icon(Icons.directions_walk, size: 100, color: Colors.blueAccent),
          ClipRRect(
            borderRadius: BorderRadius.circular(20), // 숫자가 클수록 더 둥글어집니다
            child: Image.asset(
              'assets/icon/ic_walk_together.png',
              width: 100,
              height: 100,
              fit: BoxFit.cover, // 이미지가 영역을 꽉 채우도록 설정했습니다
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "함께,이길",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 50),
          GestureDetector(
            onTap: () => ref.read(authProvider.notifier).loginWithKakao(),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE500),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble, color: Colors.black, size: 20),
                  SizedBox(width: 10),
                  Text(
                    "카카오로 시작하기",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk_together/viewmodel/course/around_course_notifier.dart';
import 'package:walk_together/viewmodel/settings_notifier.dart';
import '../../model/path_point.dart';
import '../../utils/map_utils.dart';
import '../../viewmodel/course/my_course_list_notifier.dart';
import '../../viewmodel/map_notifier.dart';
import '../../viewmodel/walk_notifier.dart'; // 저장 노티피어 추가

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _isAddressLoading = false;

  @override
  Widget build(BuildContext context) {
    // final seconds = ref.watch(timerProvider);
    final isTracking = ref.watch(isTrackingProvider);
    final trackPoints = ref.watch(walkNotifierProvider).path;
    final saveState = ref.watch(walkNotifierProvider);
    final targetSpeed = ref.watch(settingsProvider);
    final toiletMarkers = ref.watch(toiletMarkersProvider);

    // 저장 중 에러 발생 시 간단한 스낵바 알림
    ref.listen(walkNotifierProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: ${next.error}')));
      }
    });

    // 🛡️ PopScope 추가: 산책 중 뒤로가기 방지
    return PopScope(
      canPop: !isTracking, // 산책 중이 아닐 때만 즉시 뒤로가기 허용
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // 이미 pop 되었으면 무시

        // 산책 중일 때만 확인 다이얼로그 노출
        final bool shouldExit =
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text("🚶 산책 중단"),
                content: const Text(
                  "정말로 산책을 중단하고 나갈까요?\n다른앱을 사용하고 싶으시면 홈버튼을 눌러주세요\n기록이 저장되지 않습니다.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("계속하기"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      "중단 및 나가기",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ) ??
            false;

        if (shouldExit) {
          // 상태 리셋 후 수동으로 뒤로가기 수행
          ref.read(mapProvider.notifier).cancelAndReset();
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 1. 구글 맵
            Positioned.fill(
              child: GoogleMap(
                mapToolbarEnabled: false,
                zoomGesturesEnabled: true,
                // 줌 제스처 허용
                scrollGesturesEnabled: true,
                // 스크롤 허용
                rotateGesturesEnabled: true,
                // 회전 허용
                tiltGesturesEnabled: true,
                // 기울기 허용
                key: const ValueKey('main_map_unique'),
                // 고유 키 추가
                initialCameraPosition: const CameraPosition(
                  target: LatLng(37.5665, 126.9780),
                  zoom: 16,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                polylines: MapUtils.createGradientPolylines(
                  trackPoints,
                  targetSpeed,
                ),
                markers: toiletMarkers,
                onMapCreated: (controller) {
                  ref.read(mapProvider.notifier).setController(controller);

                  // 💡 맵 생성 직후 아주 살짝 딜레이를 주면 실제 기기에서 훨씬 안정적입니다.
                  Future.delayed(const Duration(milliseconds: 300), () {
                    ref.read(mapProvider.notifier).moveToCurrentLocation();
                    ref.read(mapProvider.notifier).findNearbyToilets();
                  });
                },
              ),
            ),

            // 2. 하트 카운터 (나의 좋아요)
            Positioned(top: 50, left: 16, child: _buildHeartCounter(ref)),

            // 3. 실시간 타이머
            if (isTracking)
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final seconds = ref.watch(timerProvider);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          formatTime(seconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // 4. 산책 시작/종료 버튼
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: SizedBox(
                  width: 220,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: saveState.isLoading
                          ? Colors.grey
                          : (isTracking ? Colors.redAccent : Colors.blueAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    onPressed: saveState.isLoading
                        ? null
                        : () async {
                            if (isTracking) {
                              final suggestedTitle = await ref
                                  .read(mapProvider.notifier)
                                  .stopTrackingAndPrepareSave();

                              if (suggestedTitle.isEmpty) return;

                              if (context.mounted) {
                                _showSaveDialog(context, ref, suggestedTitle);
                              }
                            } else {
                              ref
                                  .read(mapProvider.notifier)
                                  .toggleTracking(context);
                            }
                          },
                    child: saveState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            isTracking ? '산책 종료하기' : '산책 시작하기',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveDialog(
    BuildContext context,
    WidgetRef ref,
    String initialTitle,
  ) {
    final firstPoint = ref.read(mapProvider).isNotEmpty
        ? ref.read(mapProvider).first
        : null;
    final controller = TextEditingController(text: initialTitle);
    setState(() => _isAddressLoading = true);
    final addressFuture = ref
        .read(mapProvider.notifier)
        .getPlaceNameAsync(firstPoint);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // 🎯 핵심: 다이얼로그 내부에서 상태를 변경하기 위해 StatefulBuilder 사용
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 비동기 작업이 끝나면 다이얼로그 내부만 다시 그립니다.
            addressFuture
                .then((realAddress) {
                  if (realAddress.isNotEmpty &&
                      controller.text == initialTitle) {
                    controller.text = "$realAddress 산책";
                    // 주소 가져오기 성공하면 로딩바 끄기
                    if (context.mounted && _isAddressLoading) {
                      setDialogState(() => _isAddressLoading = false);
                      setState(() => _isAddressLoading = false);
                    }
                  }
                })
                .catchError((_) {
                  if (context.mounted) {
                    setDialogState(() => _isAddressLoading = false);
                    setState(() => _isAddressLoading = false);
                  }
                });
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text("🌳 산책 완료"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("산책을 완료할까요?"),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: "코스 제목",
                      hintText: "위치를 확인하고 있습니다...",
                      suffixIcon: _isAddressLoading
                          ? Container(
                              padding: EdgeInsets.all(12),
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  // 버튼 사이 간격 동일하게
                  children: [
                    // 1. 그냥 종료 (기록 삭제)
                    TextButton(
                      onPressed: () {
                        // ✅ 저장 없이 상태만 리셋하는 함수 호출 (ViewModel에 만들어야 함)
                        ref.read(mapProvider.notifier).cancelAndReset();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "기록 삭제",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

                    // 2. 계속하기 (실수로 눌렀을 때)
                    TextButton(
                      onPressed: () {
                        // ✅ 다시 트래킹을 시작하는 로직 (ViewModel에 추가 필요)
                        ref.read(mapProvider.notifier).resumeTracking();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "계속 산책하기",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),

                    // 3. 저장하기
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        print("⏱️ [UI] 1. 버튼 눌림");
                        Navigator.pop(context);
                        print("⏱️ [UI] 2. Navigator.pop 실행됨");

                        ref
                            .read(mapProvider.notifier)
                            .completeAndSave(controller.text)
                            .then((_) {
                              if (mounted) {
                                // 위젯이 아직 살아있는지 체크 (선택사항)
                                ref.invalidate(aroundCourseProvider);
                                ref.invalidate(myCourseListProvider);
                              }
                            });
                      },
                      child: const Text(
                        "저장하기",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 초 단위를 00:00:00 형식으로 변환하는 함수
  String formatTime(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  Widget _buildHeartCounter(WidgetRef ref) {
    final totalLikes = ref.watch(userTotalLikesProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        // 🔥 [디테일] 하트가 100개가 넘으면 테두리를 금색으로! (자극 포인트 ㅋ)
        border: Border.all(
          color: totalLikes >= 100
              ? Colors.orangeAccent
              : Colors.redAccent.withOpacity(0.2),
          width: totalLikes >= 100 ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite,
            color: totalLikes >= 100 ? Colors.orange : Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "나의 좋아요",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "$totalLikes",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: totalLikes >= 100
                      ? Colors.orange[800]
                      : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

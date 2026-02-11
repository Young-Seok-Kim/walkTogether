import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../model/walk_record_model.dart';
import '../../../utils/map_utils.dart';
import '../../../viewmodel/settings_notifier.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final WalkRecord? course;
  final String? courseId;

  const CourseDetailScreen({super.key, this.course, this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    // 화면 전환 후 지도를 띄우기 위한 지연 (렉 방지)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isMapReady = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetSpeed = ref.watch(settingsProvider);
    // 1. 이미 데이터가 전달된 경우
    if (widget.course != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.course!.title),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: _buildContent(widget.course!, targetSpeed),
      );
    }

    // 2. Firestore에서 데이터를 가져와야 하는 경우
    return Scaffold(
      appBar: AppBar(
        title: const Text("코스 상세"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('walks').doc(widget.courseId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("코스 정보를 찾을 수 없습니다."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final fetchedCourse = WalkRecord.fromFirestore(data, snapshot.data!.id);

          return _buildContent(fetchedCourse, targetSpeed);
        },
      ),
    );
  }

  // 실제 화면의 내용을 그리는 부분 (지도 포함)
  Widget _buildContent(WalkRecord course, double targetSpeed) {

    final double distanceInKm = course.distance / 1000;
    final int minutes = course.duration ~/ 60;
    final int seconds = course.duration % 60;

    // 🎯 평균 시속 계산 (시간이 0인 경우 방어 로직 추가)
    final double averageSpeed = course.duration > 0
        ? (course.distance * 3.6) / course.duration
        : 0.0;

    return Column(
      children: [
        // 상단 정보 요약
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${course.startTime.year}년 ${course.startTime.month}월 ${course.startTime.day}일',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  // Text(
                  //   '${distanceInKm.toStringAsFixed(2)}km 산책 완료',
                  //   style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  // ),
                ],
              ),
            ],
          ),
        ),

        // 지도 영역
        Expanded(
          child: _isMapReady
              ? GoogleMap(
            myLocationEnabled: true, // 내 위치 파란 점 표시
            myLocationButtonEnabled: true, // 내 위치로 이동 버튼 표시
            initialCameraPosition: CameraPosition(
              target: course.path.isNotEmpty
                  ? course.path.first.latLng
                  : const LatLng(37.5665, 126.9780),
              zoom: 16,
            ),
            polylines: MapUtils.createGradientPolylines(course.path, targetSpeed),
            markers: {
              if (course.path.isNotEmpty) ...{
                Marker(
                  markerId: const MarkerId('start'),
                  position: course.path.first.latLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  infoWindow: const InfoWindow(title: '시작 지점'),
                ),
                Marker(
                  markerId: const MarkerId('end'),
                  position: course.path.last.latLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  infoWindow: const InfoWindow(title: '도착 지점'),
                ),
              }
            },
            onMapCreated: (controller) => _fitBounds(controller, course.path.map((p) => p.latLng).toList(), ),
          )
              : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("지도를 불러오는 중..."),
              ],
            ),
          ),
        ),

        // 하단 요약 정보
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
          color: Colors.grey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn(Icons.timer_outlined, '소요 시간', '$minutes분 $seconds초'),
              _buildInfoColumn(Icons.straighten, '이동 거리', '${distanceInKm.toStringAsFixed(2)}km'),
              _buildInfoColumn(Icons.speed, '평균 속도', '${averageSpeed.toStringAsFixed(1)}km/h'),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueAccent),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _fitBounds(GoogleMapController controller, List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLat = points.first.latitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80, // 여백 패딩
      ),
    );
  }
}
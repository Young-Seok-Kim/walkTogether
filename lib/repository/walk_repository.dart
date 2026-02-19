import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:way_together/viewmodel/auth_notifier.dart';
import '../model/walk_record_model.dart';

final walkRepositoryProvider = Provider((ref) => WalkRepository());

class WalkRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> saveWalkToFirebase(WalkRecord record) async {
    final docRef = await _firestore.collection('walks').add(record.toMap());
    return docRef.id;
  }

  Future<List<WalkRecord>> fetchNearbyWalks({
    required double lat,
    required double lng,
    double radiusInKm = 3.0,
  }) async {
    // 1. 범위 계산 (기존 로직 동일)
    const double kmPerLatDegree = 111.32;
    double kmPerLngDegree = 111.32 * math.cos(lat * math.pi / 180);
    double latRange = radiusInKm / kmPerLatDegree;
    double lngRange = radiusInKm / kmPerLngDegree;

    final double minLat = lat - latRange;
    final double maxLat = lat + latRange;
    final double minLng = lng - lngRange;
    final double maxLng = lng + lngRange;

    // 🎯 STEP 1: 시작점(startLatitude) 기준 쿼리
    final startQuery = _firestore.collection('walks')
        .where('startLatitude', isGreaterThan: minLat)
        .where('startLatitude', isLessThan: maxLat)
        .get();

    // 🎯 STEP 2: 종료점(endLatitude) 기준 쿼리
    final endQuery = _firestore.collection('walks')
        .where('endLatitude', isGreaterThan: minLat)
        .where('endLatitude', isLessThan: maxLat)
        .get();

    // 두 쿼리를 병렬로 실행
    final results = await Future.wait([startQuery, endQuery]);

    // 🎯 STEP 3: 데이터 합치기 및 중복 제거
    final Map<String, WalkRecord> mergedMap = {};

    for (var snapshot in results) {
      for (var doc in snapshot.docs) {
        final record = WalkRecord.fromFirestore(doc.data(), doc.id);

        final double sLng = record.startLongitude ?? 0.0;
        final double eLng = record.endLongitude ?? 0.0;

        final bool startNear = sLng > minLng && sLng < maxLng;
        final bool endNear = eLng > minLng && eLng < maxLng;

        if (startNear || endNear) {
          mergedMap[doc.id] = record; // ID를 키로 써서 중복 자동 제거
        }
      }
    }

    // 🎯 STEP 4: 정렬 (최신순)
    final filteredList = mergedMap.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return filteredList;
  }

  // walk_repository.dart 수정
  Future<List<WalkRecord>> fetchMyWalks(String? userId) async {
    if (userId == null) return [];

    // 우선 kakaoUserId로 조회 시도
    var snapshot = await _firestore
        .collection('walks')
        .where('kakaoUserId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .get();

    // 만약 결과가 없다면 firebaseUserId로도 한 번 더 확인 (게스트 대비)
    if (snapshot.docs.isEmpty) {
      snapshot = await _firestore
          .collection('walks')
          .where('firebaseUserId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .get();
    }

    return snapshot.docs
        .map((doc) => WalkRecord.fromFirestore(doc.data(), doc.id, currentUserId: userId))
        .toList();
  }

  Future<void> deleteWalk(String recordId) async {
    try {
      await _firestore.collection('walks').doc(recordId).delete();
    } catch (e) {
      throw Exception("삭제 실패: $e");
    }
  }
}

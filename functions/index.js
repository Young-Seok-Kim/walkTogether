// 마지막 배포 시도: 2026-02-06
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendLikeNotification = onDocumentCreated("notifications/{notificationId}", async (event) => {
    const data = event.data.data();

    // 1. 데이터 검증
    if (!data || !data.receiverId) {
        console.log("❌ receiverId가 없습니다.");
        return null;
    }

    try {
        const receiverKakaoId = String(data.receiverId); // 이제 카카오 ID("4728516873" 등)가 들어옴
        const senderName = data.senderName || '누군가';
        const courseTitle = data.courseTitle || '코스';

        console.log(`🔔 알림 전송 시도: 수신자 카카오ID(${receiverKakaoId})`);

        // 2. 🎯 문서 ID가 카카오 ID이므로 바로 조준 사격!
        const userDoc = await admin.firestore().collection('users').doc(receiverKakaoId).get();

        if (!userDoc.exists) {
            console.log(`⚠️ 해당 유저 문서를 찾을 수 없음: users/${receiverKakaoId}`);
            return null;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        // 3. 토큰 확인 및 전송
        if (fcmToken) {
            const message = {
                notification: {
                    title: '새로운 좋아요! ❤️',
                    body: `${senderName}님이 '${courseTitle}' 코스를 좋아합니다.`,
                },
                // 안드로이드 포그라운드 알림을 위한 데이터 설정 (선택)
                data: {
                    courseId: String(data.courseId || ''),
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    courseTitle: courseTitle,
                },
                token: fcmToken,
            };

            const response = await admin.messaging().send(message);
            console.log('✅ 푸시 전송 성공:', response);
            return response;
        } else {
            console.log(`⚠️ 유저(${receiverKakaoId})의 fcmToken이 null입니다.`);
            return null;
        }
    } catch (error) {
        console.error('🔥 알림 전송 에러:', error);
        return null;
    }
});
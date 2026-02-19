# 📍 함께, 이길 (Way Together)
> **Google Maps API와 Firebase를 활용한 스마트 산책 기록 및 경로 공유 플랫폼**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Riverpod](https://img.shields.io/badge/Riverpod-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://riverpod.dev)

---

## 🚀 프로젝트 소개
**함께, 이길**은 산책을 사랑하는 사람들을 위한 위치 기반 서비스입니다. 단순히 걷는 것을 넘어, 내가 걸어온 길을 기록하고 이웃들이 추천하는 아름다운 산책 코스를 탐색하며 건강한 걷기 문화를 만들어갑니다.

## ✨ 주요 기능
- **🚶 실시간 산책 트래킹**: Google Maps API를 연동하여 실시간 이동 경로, 거리, 소요 시간을 정밀하게 기록합니다.
- **🌍 코스 탐색 & 공유**: '주변 코스' 기능을 통해 다른 사용자들이 공유한 매력적인 산책로를 확인합니다.
- **🔐 하이브리드 로그인**: 카카오(Kakao) 간편 로그인과 더불어, 리뷰어 및 미가입자를 위한 **익명(Guest) 로그인** 기능을 제공합니다.
- **📂 내 기록 관리**: 나의 지난 산책 데이터를 클라우드(Firestore)에 안전하게 저장하고 언제든 다시 확인합니다.
- **👤 데이터 주권 보장**: 구글 정책을 준수하여 사용자가 직접 자신의 계정과 모든 활동 데이터를 즉시 삭제할 수 있는 **회원 탈퇴** 기능을 포함합니다.

## 🛠 Tech Stack
- **Framework**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore, Cloud Messaging)
- **Maps**: Google Maps Platform (Android SDK)
- **Auth**: Kakao Login SDK & Firebase Anonymous Auth
- **State Management**: **Riverpod** (Notifier, AsyncValue 기반의 반응형 상태 관리)

---

## 🔒 Security & Setup
이 프로젝트는 보안을 위해 API Key 및 민감 정보를 소스코드에 포함하지 않습니다.

1. **환경 변수 설정**: 프로젝트 루트에 `.env` 파일을 생성하고 필요한 Key를 설정합니다.
2. **Key Store**: 릴리즈 빌드를 위해 `android/key.properties` 설정이 필요합니다.
3. **Firestore Rules**: 데이터 보호를 위해 사용자 인증 기반의 보안 규칙이 적용되어 있습니다.

---

## 📄 Privacy Policy
본 프로젝트의 개인정보 처리방침은 아래 링크에서 확인할 수 있습니다.
[개인정보 처리방침 보러가기](https://gist.github.com/Young-Seok-Kim/78b4eefe03bb6aad6c1369c997bde695)
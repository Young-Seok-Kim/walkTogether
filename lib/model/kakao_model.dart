class KakaoModel {
  final String id;
  final String nickname;
  final String? profileUrl;

  KakaoModel({
    required this.id,
    required this.nickname,
    this.profileUrl,
  });
}
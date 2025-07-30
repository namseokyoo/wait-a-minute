# Wait A Minute - 고객 대기 감지 시스템

**실시간 파란불빛 모니터링을 통한 고객 대기 상태 감지 시스템**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Vercel](https://img.shields.io/badge/Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white)](https://vercel.com)

## 🎯 프로젝트 개요

"Wait A Minute"은 카메라를 이용한 파란불빛 감지를 통해 고객의 대기 상태를 실시간으로 모니터링하는 Flutter 애플리케이션입니다. CCTV 모드와 모니터 모드를 지원하여 효율적인 대기 관리 시스템을 제공합니다.

## ✨ 주요 기능

### 📱 모바일 앱
- **CCTV 모드**: 실시간 카메라 모니터링 및 파란불빛 감지
- **모니터 모드**: 다중 디바이스 상태 통합 모니터링
- **실시간 알림**: 대기 상태 변경 시 즉시 푸시 알림
- **감도 조절**: 5단계 감도 설정으로 정밀한 감지
- **스마트 최적화**: 배터리 절약 및 성능 최적화

### 🌐 웹 앱 (PWA)
- **크로스 플랫폼**: 모든 브라우저에서 동작
- **카메라 지원**: 웹에서도 실시간 카메라 접근 (HTTPS 필요)
- **반응형 디자인**: 데스크톱, 태블릿, 모바일 최적화
- **오프라인 지원**: Service Worker를 통한 PWA 기능

## 🚀 빠른 시작

### 개발 환경 요구사항
```bash
Flutter SDK >= 3.7.2
Dart SDK >= 3.0.0
```

### 로컬 실행
```bash
# 프로젝트 클론
git clone https://github.com/namseokyoo/wait-a-minute.git
cd wait-a-minute

# 의존성 설치
flutter pub get

# 모바일 앱 실행
flutter run

# 웹 앱 실행 (HTTPS)
flutter run -d chrome --web-port 8080
```

### 웹 배포
```bash
# 웹 빌드
flutter build web --release

# 빌드 파일은 build/web/ 에 생성됩니다
```

## 🏗️ 시스템 아키텍처

### 핵심 서비스
- **CameraService**: 카메라 제어 및 앱 생애주기 관리
- **BlueLightDetector**: AI 기반 파란불빛 감지 엔진
- **FirebaseRealtimeService**: 실시간 데이터 동기화
- **SmartUpdateManager**: 컨텍스트 기반 업데이트 최적화
- **BatchCleanupManager**: 자동 데이터베이스 정리
- **DeviceHealthChecker**: 디바이스 상태 모니터링

### 고급 기능
- **Ghost Device 방지**: 앱 비정상 종료 시 자동 정리
- **Exponential Backoff**: 지능형 재연결 메커니즘
- **App Lifecycle Management**: 백그라운드/포그라운드 전환 처리
- **Firebase Presence System**: 실시간 연결 상태 추적

## 🔐 보안 및 개인정보

- **HTTPS 필수**: 웹에서 카메라 권한을 위해 HTTPS 필요
- **로컬 우선**: 민감한 데이터는 로컬에서만 처리
- **권한 최소화**: 필요한 권한만 요청 (카메라, 알림)
- **자동 정리**: 오래된 데이터 자동 삭제

## 🛡️ 브라우저 호환성

| 브라우저 | 카메라 지원 | PWA 지원 | 권장도 |
|---------|------------|----------|--------|
| Chrome | ✅ 완전 지원 | ✅ | ⭐⭐⭐⭐⭐ |
| Firefox | ✅ 완전 지원 | ✅ | ⭐⭐⭐⭐⭐ |
| Safari | ⚠️ 부분 지원 | ✅ | ⭐⭐⭐ |
| Edge | ✅ 완전 지원 | ✅ | ⭐⭐⭐⭐⭐ |

> **참고**: 카메라 접근을 위해서는 HTTPS 연결이 필요합니다.

## 📊 성능 최적화

- **스마트 업데이트**: 상황에 따른 업데이트 빈도 자동 조절
- **메모리 관리**: 미사용 리소스 자동 해제
- **배터리 절약**: 백그라운드에서 저전력 모드
- **네트워크 효율성**: 필요한 데이터만 전송

## 🔧 기술 스택

**Frontend**: Flutter, Provider, Camera  
**Backend**: Firebase (Realtime Database, Auth, FCM)  
**Deployment**: Vercel, GitHub Actions  
**Tools**: VS Code, Flutter Dev Tools  

## 📄 라이선스

MIT License - 자유롭게 사용하세요!

---

**Made with ❤️ using Flutter**

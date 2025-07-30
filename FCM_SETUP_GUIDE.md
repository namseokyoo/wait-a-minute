# FCM 푸시 알림 설정 가이드

Wait A Minute 앱에서 FCM 푸시 알림을 완전히 사용하기 위한 설정 가이드입니다.

## 🚀 현재 구현 상태

✅ **완료된 기능**
- FCM 토큰 자동 등록 및 관리
- 실시간 기기 상태 동기화
- CCTV → Monitor 장치로 푸시 알림 전송
- 오프라인 기기 자동 정리
- 온라인 기기만 표시하는 필터링

⚠️ **추가 설정 필요**
- Firebase 프로젝트 설정
- FCM 서버 키 구성 (실제 푸시 알림 전송용)

## 📱 Firebase 프로젝트 설정

### 1. Firebase Console 설정
```bash
# Firebase Console (https://console.firebase.google.com) 에서:
1. 프로젝트 선택 또는 생성
2. Authentication > 로그인 방법 > Anonymous 사용 설정
3. Realtime Database > 데이터베이스 만들기
4. Cloud Messaging > FCM API (V1) 사용 설정
```

### 2. Android 설정
```bash
# android/app/google-services.json 확인
# 파일이 없다면 Firebase Console에서 다운로드
1. Firebase Console > 프로젝트 설정 > 일반
2. Android 앱 추가 (패키지명: com.example.wait_a_minute)
3. google-services.json 다운로드 → android/app/ 폴더에 복사
```

### 3. iOS 설정 (필요시)
```bash
# ios/Runner/GoogleService-Info.plist 확인
1. Firebase Console > 프로젝트 설정 > 일반  
2. iOS 앱 추가 (Bundle ID: com.example.waitAMinute)
3. GoogleService-Info.plist 다운로드 → ios/Runner/ 폴더에 복사
```

## 🔧 FCM 푸시 알림 완전 활성화

### 현재 상태
```dart
// 현재는 로컬에서 FCM 메시지 시뮬레이션만 가능
await _sendFCMMessage(fcmToken, title, body, data);
// → 실제로는 console.log만 출력
```

### 실제 FCM 푸시 알림을 위한 추가 설정

#### 방법 1: Firebase Functions 사용 (권장)
```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendPushNotification = functions.database
  .ref('/alerts/{alertId}')
  .onCreate(async (snapshot, context) => {
    const alertData = snapshot.val();
    
    // 모든 모니터 디바이스 토큰 가져오기
    const monitorsSnapshot = await admin.database()
      .ref('/monitors')
      .once('value');
    
    const tokens = [];
    monitorsSnapshot.forEach(child => {
      const monitorData = child.val();
      if (monitorData.pushEnabled && monitorData.fcmToken) {
        tokens.push(monitorData.fcmToken);
      }
    });
    
    // FCM 메시지 전송
    if (tokens.length > 0) {
      const message = {
        notification: {
          title: '대기인원 알림',
          body: alertData.message
        },
        data: {
          deviceId: alertData.deviceId,
          type: 'waiting_alert'
        },
        tokens: tokens
      };
      
      return admin.messaging().sendMulticast(message);
    }
  });
```

#### 방법 2: HTTP API 사용
```dart
// lib/services/firebase_realtime_service.dart의 _sendFCMMessage 구현
Future<void> _sendFCMMessage(String fcmToken, String title, String body, Map<String, String>? data) async {
  const String serverKey = 'YOUR_FCM_SERVER_KEY'; // Firebase Console에서 가져오기
  
  final response = await http.post(
    Uri.parse('https://fcm.googleapis.com/fcm/send'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'key=$serverKey',
    },
    body: jsonEncode({
      'to': fcmToken,
      'notification': {
        'title': title,
        'body': body,
      },
      'data': data ?? {},
    }),
  );
  
  if (response.statusCode == 200) {
    print('FCM message sent successfully');
  } else {
    print('Failed to send FCM message: ${response.statusCode}');
  }
}
```

## 🗂️ Firebase Database 구조

현재 구현된 데이터 구조:

```json
{
  "devices": {
    "device_uuid": {
      "deviceInfo": {
        "name": "CCTV 기기",
        "location": "입구",
        "mode": "cctv"
      },
      "status": {
        "isWaiting": true,
        "blueIntensity": 0.8,
        "confidence": 0.95,
        "isOnline": true,
        "isMonitoring": true,
        "batteryLevel": 0.85,
        "lastUpdate": 1678901234567
      }
    }
  },
  "monitors": {
    "monitor_uuid": {
      "deviceName": "Monitor Device",
      "fcmToken": "fcm_token_here",
      "isOnline": true,
      "pushEnabled": true,
      "lastSeen": 1678901234567,
      "registeredAt": 1678901234567
    }
  },
  "alerts": {
    "alert_uuid": {
      "deviceId": "device_uuid",
      "message": "대기인원 있음",
      "timestamp": 1678901234567
    }
  }
}
```

## 🔐 보안 규칙

Firebase Realtime Database 보안 규칙:

```json
{
  "rules": {
    "devices": {
      ".read": true,
      ".write": true
    },
    "monitors": {
      ".read": true,
      ".write": true  
    },
    "alerts": {
      ".read": true,
      ".write": true
    }
  }
}
```

## 🧪 테스트 방법

### 1. 로컬 테스트
```bash
# 현재 상태에서도 테스트 가능
1. CCTV 모드 실행 → 파란불 감지 시뮬레이션
2. Monitor 모드 실행 → Firebase 실시간 상태 확인
3. Debug 콘솔에서 FCM 메시지 시뮬레이션 로그 확인
```

### 2. 실제 FCM 테스트  
```bash
1. Firebase Functions 배포 또는 HTTP API 구현
2. 실제 기기에서 앱 실행 (에뮬레이터는 FCM 제한)
3. CCTV 모드에서 상태 변화 → Monitor 모드로 실제 푸시 알림 수신
```

## 📋 설정 체크리스트

- [ ] Firebase 프로젝트 생성 및 설정
- [ ] google-services.json 파일 추가
- [ ] FCM API 활성화
- [ ] Realtime Database 생성
- [ ] 보안 규칙 설정
- [ ] Firebase Functions 배포 또는 HTTP API 구현
- [ ] 실제 기기에서 테스트

## 🚨 중요 사항

1. **에뮬레이터 제한**: FCM은 실제 기기에서만 완전히 작동
2. **서버 키 보안**: FCM 서버 키는 안전하게 보관 (클라이언트 코드에 포함하지 말것)
3. **배터리 최적화**: Android에서 배터리 최적화 예외 설정 필요할 수 있음
4. **권한**: 알림 권한이 자동으로 요청됨

## 🔄 업그레이드 경로

현재 → 완전한 FCM:
1. Firebase Functions 배포 (권장)
2. 또는 HTTP API를 통한 FCM 직접 호출 구현
3. 실제 기기에서 테스트 및 검증
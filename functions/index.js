const {onValueCreated} = require("firebase-functions/v2/database");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

// Firebase Realtime Database에서 새로운 alert가 생성될 때 FCM 푸시 알림 전송
exports.sendPushNotification = onValueCreated(
    "/alerts/{alertId}",
    async (event) => {
      const snapshot = event.data;
      const alertData = snapshot.val();

      console.log("New alert created:", alertData);

      try {
        // 모든 모니터 디바이스 토큰 가져오기
        const monitorsSnapshot = await admin.database()
            .ref("/monitors")
            .once("value");

        const tokens = [];
        monitorsSnapshot.forEach((child) => {
          const monitorData = child.val();
          if (monitorData.pushEnabled &&
              monitorData.fcmToken &&
              monitorData.isOnline) {
            tokens.push(monitorData.fcmToken);
          }
        });

        console.log("Found monitor tokens:", tokens.length);

        // FCM 메시지 전송
        if (tokens.length > 0) {
          const message = {
            notification: {
              title: "대기인원 알림",
              body: alertData.message || "대기인원이 감지되었습니다",
            },
            data: {
              deviceId: alertData.deviceId || "",
              type: "waiting_alert",
              timestamp: Date.now().toString(),
            },
            tokens: tokens,
          };

          const response = await admin.messaging().sendMulticast(message);
          console.log("FCM message sent successfully:",
              response.successCount, "success,",
              response.failureCount, "failed");

          // 실패한 토큰들 정리
          if (response.failureCount > 0) {
            response.responses.forEach((resp, idx) => {
              if (!resp.success) {
                console.log("Failed token:", tokens[idx], resp.error);
              }
            });
          }

          return response;
        } else {
          console.log("No active monitor devices found");
          return null;
        }
      } catch (error) {
        console.error("Error sending FCM message:", error);
        throw error;
      }
    });

// 기기가 오프라인 상태로 변경될 때 정리
exports.cleanupOfflineDevices = onSchedule("every 5 minutes", async () => {
  const now = Date.now();
  const fiveMinutesAgo = now - (5 * 60 * 1000);

  try {
    // 오프라인 기기 정리
    const devicesSnapshot = await admin.database()
        .ref("/devices").once("value");
    const cleanupPromises = [];

    devicesSnapshot.forEach((child) => {
      const deviceData = child.val();
      const status = deviceData.status;

      if (status && (!status.isOnline ||
              status.lastUpdate < fiveMinutesAgo)) {
        console.log("Removing offline device:", child.key);
        cleanupPromises.push(child.ref.remove());
      }
    });

    // 오프라인 모니터 정리
    const monitorsSnapshot = await admin.database()
        .ref("/monitors").once("value");

    monitorsSnapshot.forEach((child) => {
      const monitorData = child.val();

      if (!monitorData.isOnline || monitorData.lastSeen < fiveMinutesAgo) {
        console.log("Removing offline monitor:", child.key);
        cleanupPromises.push(child.ref.remove());
      }
    });

    await Promise.all(cleanupPromises);
    console.log("Cleanup completed, removed",
        cleanupPromises.length, "entries");

    return null;
  } catch (error) {
    console.error("Error during cleanup:", error);
    throw error;
  }
});

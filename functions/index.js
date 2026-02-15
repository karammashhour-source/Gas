"use strict";

const { onValueWritten } = require("firebase-functions/v2/database");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

const TOPIC = "gas_alerts_all";
const WARNING_MIN = 40.0; // warning يبدأ من هذه القيمة
const DANGER_MIN = 70.0; // danger يبدأ من هذه القيمة (شامل)
const WARNING_MIN_INTERVAL_MS = 90 * 1000;
const DANGER_MIN_INTERVAL_MS = 30 * 1000;
const STATE_PATH = "/home/gas_sensor/notification_state";

function statusFromLevel(level) {
  if (level >= DANGER_MIN) {
    return "danger";
  }
  if (level >= WARNING_MIN) {
    return "warning";
  }
  return "safe";
}

function buildAlert(status, level) {
  const rounded = Math.round(level);
  if (status === "danger") {
    return {
      type: "danger",
      title: "خطر غاز - Danger",
      body: `تسرب غاز! المستوى: ${rounded} PPM`,
    };
  }
  return {
    type: "warning",
    title: "تنبيه تحذير - Warning",
    body: `مستوى الغاز مرتفع: ${rounded} PPM`,
  };
}

exports.notifyGasAlerts = onValueWritten(
  "/home/gas_sensor/level",
  async (event) => {
    const after = event.data.after.val();
    if (after == null) {
      return;
    }

    const level = Number(after);
    if (!Number.isFinite(level)) {
      console.log("Skipping non-numeric gas level:", after);
      return;
    }

    const now = Date.now();
    const status = statusFromLevel(level);
    const stateRef = admin.database().ref(STATE_PATH);
    const stateSnap = await stateRef.get();
    const state = stateSnap.exists() ? stateSnap.val() : {};
    const previousStatus = String(state.status || "safe");
    const lastSentAt = Number(state.lastSentAt || 0);

    if (status === "safe") {
      if (previousStatus !== "safe") {
        await stateRef.set({
          status: "safe",
          lastSentAt: now,
          lastLevel: level,
        });
      }
      return;
    }

    const statusChanged = status !== previousStatus;
    const minIntervalMs =
      status === "danger" ? DANGER_MIN_INTERVAL_MS : WARNING_MIN_INTERVAL_MS;
    const intervalPassed = now - lastSentAt >= minIntervalMs;

    if (!statusChanged && !intervalPassed) {
      console.log(
        `Skip FCM (${status}) due to cooldown. level=${level}, remainingMs=${
          minIntervalMs - (now - lastSentAt)
        }`,
      );
      return;
    }

    const alert = buildAlert(status, level);
    const dataPayload = {
      type: alert.type,
      title: alert.title,
      body: alert.body,
      gas_level: level.toFixed(1),
      sent_at: String(now),
    };

    await admin.messaging().send({
      topic: TOPIC,
      notification: {
        title: alert.title,
        body: alert.body,
      },
      data: dataPayload,
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          sound: "default",
          defaultSound: true,
          defaultVibrateTimings: true,
          visibility: "PUBLIC",
          tag: "gas-alert",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            sound: "default",
            contentAvailable: true,
          },
        },
      },
    });

    await stateRef.set({
      status,
      lastSentAt: now,
      lastLevel: level,
      lastMessageType: alert.type,
    });

    console.log(
      `FCM sent to topic ${TOPIC}: status=${status}, level=${level.toFixed(1)}`,
    );
  },
);

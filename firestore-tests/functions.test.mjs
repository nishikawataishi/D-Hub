/**
 * Cloud Functions (functions/index.js) のセキュリティ・コスト・運用改善テスト
 * 対象項目: P0-1, P0-3, P2-2, P2-4, P3-3, P3-4 および現行アプリの正常系互換性
 *
 * 実行方法（firestore-tests ディレクトリから）:
 *   firebase emulators:exec --only auth,firestore,functions,storage --project d-scout-6d281 "node --test functions.test.mjs"
 */

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { createRequire } from "node:module";
import { initializeApp, deleteApp } from "firebase/app";
import {
  getAuth as getClientAuth,
  connectAuthEmulator,
  signInWithEmailAndPassword,
  signOut,
} from "firebase/auth";
import {
  getFunctions,
  connectFunctionsEmulator,
  httpsCallable,
} from "firebase/functions";

const require = createRequire(import.meta.url);

const PROJECT_ID = "d-scout-6d281";
const PASSWORD = "TestPass123!";

// Admin SDK がエミュレータへ接続するよう環境変数を設定
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("../functions/node_modules/firebase-admin");
if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    storageBucket: `${PROJECT_ID}.firebasestorage.app`,
  });
}
const adminDb = admin.firestore();
const adminAuth = admin.auth();

let clientApp;
let clientAuth;
let clientFunctions;

/**
 * SHA-256ハッシュから6桁の確認コードを逆引きする（テスト専用ヘルパー）
 */
function crackSixDigitHash(targetHash) {
  for (let i = 100000; i <= 999999; i++) {
    const code = i.toString();
    const h = crypto.createHash("sha256").update(code).digest("hex");
    if (h === targetHash) return code;
  }
  throw new Error(`6桁コードの復元に失敗しました: ${targetHash}`);
}

/**
 * 非同期トリガーの完了をポーリングで待機するヘルパー
 */
async function waitForCondition(checkFn, timeoutMs = 8000, intervalMs = 200) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await checkFn()) return true;
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  return false;
}

/**
 * テスト用ユーザーを作成してログインし、callable 呼び出し関数を返す
 */
async function loginTestUser(uid, email, customClaims = null) {
  try {
    await adminAuth.deleteUser(uid);
  } catch (_) {
    // 未作成の場合は無視
  }
  await adminAuth.createUser({
    uid,
    email,
    password: PASSWORD,
    emailVerified: true,
  });
  if (customClaims) {
    await adminAuth.setCustomUserClaims(uid, customClaims);
  }
  await signOut(clientAuth);
  const cred = await signInWithEmailAndPassword(clientAuth, email, PASSWORD);
  if (customClaims) {
    await cred.user.getIdToken(true);
  }
  return cred.user;
}

before(async () => {
  clientApp = initializeApp({
    projectId: PROJECT_ID,
    apiKey: "fake-api-key-for-emulator",
  });
  clientAuth = getClientAuth(clientApp);
  connectAuthEmulator(clientAuth, "http://127.0.0.1:9099", { disableWarnings: true });
  clientFunctions = getFunctions(clientApp, "us-central1");
  connectFunctionsEmulator(clientFunctions, "127.0.0.1", 5001);
});

after(async () => {
  await signOut(clientAuth).catch(() => {});
  await deleteApp(clientApp).catch(() => {});
});

// ============================================================================
// 【P0-1】大学メール第2層認証のバイパス・複数垢量産・メール爆撃の遮断
// ============================================================================

test("[P0-1a] カンマ区切りやスペース混入による外部メールへの相乗り送信（学生認証バイパス）を拒否", async () => {
  await loginTestUser("p01_comma_attacker", "student1@mail2.doshisha.ac.jp");
  const sendCode = httpsCallable(clientFunctions, "sendVerificationCode");

  await assert.rejects(
    () => sendCode({ email: "attacker@gmail.com, student1@mail2.doshisha.ac.jp" }),
    (err) => err.code === "functions/invalid-argument",
  );
  await assert.rejects(
    () => sendCode({ email: "\"Evil\" <attacker@gmail.com>, student1@mail.doshisha.ac.jp" }),
    (err) => err.code === "functions/invalid-argument",
  );
});

test("[P0-1b] ログインメールと異なる大学メールへの確認コード送信（嫌がらせメール爆撃）を拒否", async () => {
  await loginTestUser("p01_mismatch_attacker", "throwaway@gmail.com");
  const sendCode = httpsCallable(clientFunctions, "sendVerificationCode");

  await assert.rejects(
    () => sendCode({ email: "victim@mail2.doshisha.ac.jp" }),
    (err) =>
      err.code === "functions/permission-denied" ||
      err.code === "functions/invalid-argument",
  );
});

test("[P0-1c] 団体アカウントからの sendVerificationCode 呼び出しを拒否", async () => {
  const orgUid = "p01_org_caller";
  await adminDb.collection("organizations").doc(orgUid).set({
    name: "テスト団体",
    status: "pending",
    representativeId: orgUid,
  });
  await loginTestUser(orgUid, "orgcaller@mail2.doshisha.ac.jp");
  const sendCode = httpsCallable(clientFunctions, "sendVerificationCode");

  await assert.rejects(
    () => sendCode({ email: "orgcaller@mail2.doshisha.ac.jp" }),
    (err) => err.code === "functions/failed-precondition",
  );
});

test("[P0-1d] 同一の大学メールアドレスで複数UIDの学生アカウントを重複認証できない（退会後は再登録可・mail10対応含む）", async () => {
  const sharedUniEmail = "dupcheck@mail2.doshisha.ac.jp";
  const uid1 = "p01_dup_user_1";
  const uid2 = "p01_dup_user_2";

  // 1人目: 通常の学生登録 → コード送信 → コード検証成功
  await adminDb.collection("users").doc(uid1).set({
    isStudentVerified: false,
    createdAt: new Date(),
  });
  await loginTestUser(uid1, sharedUniEmail);
  const sendCode = httpsCallable(clientFunctions, "sendVerificationCode");
  const verifyCode = httpsCallable(clientFunctions, "verifyCode");

  await sendCode({ email: sharedUniEmail });
  const priv1 = await adminDb.collection("users").doc(uid1).collection("private").doc("verification").get();
  const code1 = crackSixDigitHash(priv1.data().codeHashedValue);
  const res1 = await verifyCode({ code: code1 });
  assert.equal(res1.data.success, true);

  // 1人目がAuthメールを別アドレスに変更したと想定し、2人目が同じ大学メールで登録・認証を試みる
  await adminAuth.updateUser(uid1, { email: "changed1@gmail.com" });
  await adminDb.collection("users").doc(uid2).set({
    isStudentVerified: false,
    createdAt: new Date(),
  });
  await loginTestUser(uid2, sharedUniEmail);

  await assert.rejects(
    async () => {
      await sendCode({ email: sharedUniEmail });
      const priv2 = await adminDb.collection("users").doc(uid2).collection("private").doc("verification").get();
      const code2 = crackSixDigitHash(priv2.data().codeHashedValue);
      await verifyCode({ code: code2 });
    },
    (err) => err.code === "functions/already-exists",
  );

  // 1人目が正式に退会（deleteMyAccount）した後は、同じ大学メールで再登録・認証できること
  await adminAuth.updateUser(uid2, { email: "temp_release@gmail.com" });
  await adminAuth.updateUser(uid1, { email: sharedUniEmail });
  await signInWithEmailAndPassword(clientAuth, sharedUniEmail, PASSWORD);
  await httpsCallable(clientFunctions, "deleteMyAccount")();

  const uid3 = "p01_rejoin_user";
  await adminDb.collection("users").doc(uid3).set({
    isStudentVerified: false,
    createdAt: new Date(),
  });
  await loginTestUser(uid3, sharedUniEmail);
  await sendCode({ email: sharedUniEmail });
  const priv3 = await adminDb.collection("users").doc(uid3).collection("private").doc("verification").get();
  const code3 = crackSixDigitHash(priv3.data().codeHashedValue);
  const res3 = await verifyCode({ code: code3 });
  assert.equal(res3.data.success, true);

  // クライアント側正規表現で許可されている mail10.doshisha.ac.jp も通ること
  const uid4 = "p01_mail10_user";
  const mail10 = "student10@mail10.doshisha.ac.jp";
  await adminDb.collection("users").doc(uid4).set({
    isStudentVerified: false,
    createdAt: new Date(),
  });
  await loginTestUser(uid4, mail10);
  const resMail10 = await sendCode({ email: mail10 });
  assert.equal(resMail10.data.success, true);
});

// ============================================================================
// 【P0-3】Cloud Functions の maxInstances 設定検証
// ============================================================================

test("[P0-3] Cloud Functions にスケール上限（maxInstances）が設定されている", async () => {
  const { execFileSync } = await import("node:child_process");
  const script = `
    const fn = require("./index.js");
    const opts = require("firebase-functions/v2/options").getGlobalOptions();
    console.log(JSON.stringify({
      globalMaxInstances: opts.maxInstances ?? null,
      deleteTimeout: fn.deleteMyAccount.__endpoint.timeoutSeconds ?? null,
      deleteMaxInstances: fn.deleteMyAccount.__endpoint.maxInstances ?? opts.maxInstances ?? null,
    }));
  `;
  const raw = execFileSync(process.execPath, ["-e", script], {
    cwd: new URL("../functions", import.meta.url),
    encoding: "utf8",
  });
  const info = JSON.parse(raw.trim().split("\n").pop());

  assert.ok(
    typeof info.globalMaxInstances === "number" && info.globalMaxInstances > 0 && info.globalMaxInstances <= 20,
    `setGlobalOptions で maxInstances が設定されていません: ${JSON.stringify(info)}`,
  );
  assert.ok(
    info.deleteTimeout <= 300,
    `deleteMyAccount の timeoutSeconds が長すぎます: ${info.deleteTimeout}`,
  );
});

// ============================================================================
// 【P2-2】並列リクエストによるレート制限突破 ＆ verifyCode でのカウンタ消失防止
// ============================================================================

test("[P2-2a] sendVerificationCode を並列同時呼び出ししても1時間3回制限を突破できない（TOCTOU対策）", async () => {
  const uid = "p22_race_user";
  const email = "racetest@dwc.doshisha.ac.jp";
  await adminDb.collection("users").doc(uid).set({
    isStudentVerified: false,
    createdAt: new Date(),
  });
  await loginTestUser(uid, email);
  const sendCode = httpsCallable(clientFunctions, "sendVerificationCode");

  // まず2回送信して残り枠を「あと1回」にし、かつエミュレータワーカーをウォームアップする
  await sendCode({ email });
  await sendCode({ email });

  // 残り1枠に対して4並列で同時にリクエストを投げる（トランザクション外なら複数が通り合計3回を超える）
  const burstResults = await Promise.allSettled([
    sendCode({ email }),
    sendCode({ email }),
    sendCode({ email }),
    sendCode({ email }),
  ]);

  const burstSucceeded = burstResults.filter((r) => r.status === "fulfilled");
  assert.equal(
    burstSucceeded.length,
    1,
    `残り1枠に対して並列リクエストで ${burstSucceeded.length} 回送信されました（合計 ${2 + burstSucceeded.length} 回 > 上限3回）`,
  );
});

test("[P2-2b] verifyCode 成功時にレート制限カウンタ（codeSentCount / codeSentWindowStart）が消去されない", async () => {
  const uid = "p22_counter_keep_user";
  const email = "keepcounter@mail.doshisha.ac.jp";
  await adminDb.collection("users").doc(uid).set({
    isStudentVerified: false,
    createdAt: new Date(),
  });
  await loginTestUser(uid, email);
  const sendCode = httpsCallable(clientFunctions, "sendVerificationCode");
  const verifyCode = httpsCallable(clientFunctions, "verifyCode");

  await sendCode({ email });
  await sendCode({ email });

  const beforePriv = await adminDb.collection("users").doc(uid).collection("private").doc("verification").get();
  const code = crackSixDigitHash(beforePriv.data().codeHashedValue);

  const verifyRes = await verifyCode({ code });
  assert.equal(verifyRes.data.success, true);

  const afterPriv = await adminDb.collection("users").doc(uid).collection("private").doc("verification").get();
  assert.equal(afterPriv.data().codeSentCount, 2, "verifyCode 後に codeSentCount が消えています");
  assert.ok(afterPriv.data().codeSentWindowStart != null, "verifyCode 後に codeSentWindowStart が消えています");
  assert.equal(afterPriv.data().codeHashedValue, undefined);
});

// ============================================================================
// 【P2-4】イベント削除・管理画面からの団体/学生削除での孤児データ＆Auth自動削除
// ============================================================================

test("[P2-4a] イベント削除時にサブコレクション applications の個人情報が自動削除される", async () => {
  const eventRef = adminDb.collection("events").doc("p24_orphan_event");
  await eventRef.set({
    organizationId: "some_org",
    title: "削除テストイベント",
    startAt: new Date(Date.now() + 86400000),
  });
  await eventRef.collection("applications").doc("student_1").set({
    studentId: "student_1",
    studentName: "申込学生1",
    studentFaculty: "経済学部",
    studentGrade: 2,
    status: "applied",
  });

  // 現行アプリの deleteEvent と同じく親ドキュメントのみ削除
  await eventRef.delete();

  const cleaned = await waitForCondition(async () => {
    const snap = await eventRef.collection("applications").get();
    return snap.empty;
  });
  assert.equal(cleaned, true, "親イベント削除後に applications サブコレクションが孤児として残っています");
});

test("[P2-4b] 管理画面からの団体削除（organizations/{id} 削除）で Auth・イベント・申込・スカウト・blocks も自動一掃される", async () => {
  const orgUid = "p24_banned_org";
  await loginTestUser(orgUid, "banned-org@example.com");
  await signOut(clientAuth);

  await adminDb.collection("organizations").doc(orgUid).set({
    name: "悪質団体",
    status: "verified",
    representativeId: orgUid,
  });
  await adminDb.collection("organizations").doc(orgUid).collection("blocks").doc("st_x").set({
    targetName: "学生X",
  });
  await adminDb.collection("events").doc("banned_org_event").set({
    organizationId: orgUid,
    title: "悪質イベント",
  });
  await adminDb.collection("events").doc("banned_org_event").collection("applications").doc("st_y").set({
    studentId: "st_y",
    studentName: "学生Y",
    status: "applied",
  });
  await adminDb.collection("scouts").doc("banned_org_scout").set({
    organizationId: orgUid,
    targetUserId: "st_y",
    templateId: 4,
    isRead: false,
  });

  // 現行 AdminDashboardScreen._deleteOrg と同じく organizations/{id} だけ削除
  await adminDb.collection("organizations").doc(orgUid).delete();

  const cleaned = await waitForCondition(async () => {
    let authGone = false;
    try {
      await adminAuth.getUser(orgUid);
    } catch (e) {
      if (e.code === "auth/user-not-found") authGone = true;
    }
    const evDoc = await adminDb.collection("events").doc("banned_org_event").get();
    const appDoc = await adminDb.collection("events").doc("banned_org_event").collection("applications").doc("st_y").get();
    const scoutDoc = await adminDb.collection("scouts").doc("banned_org_scout").get();
    const blockDoc = await adminDb.collection("organizations").doc(orgUid).collection("blocks").doc("st_x").get();
    return authGone && !evDoc.exists && !appDoc.exists && !scoutDoc.exists && !blockDoc.exists;
  });

  assert.equal(cleaned, true, "団体削除後に Auth アカウントまたは関連データが残存しています");
});

test("[P2-4c] 管理画面からの学生削除（users/{id} 削除 + deleteAuthUser 呼び出し）が競合エラーなく関連データと大学メールロックを一掃する", async () => {
  const studentUid = "p24_deleted_student";
  const studentEmail = "del-student@mail.doshisha.ac.jp";
  const emailLockId = crypto.createHash("sha256").update(studentEmail).digest("hex");
  await loginTestUser(studentUid, studentEmail);

  await adminDb.collection("users").doc(studentUid).set({
    name: "削除対象学生",
    isStudentVerified: true,
  });
  await adminDb.collection("users").doc(studentUid).collection("private").doc("verification").set({
    universityEmail: studentEmail,
  });
  await adminDb.collection("university_email_locks").doc(emailLockId).set({
    uid: studentUid,
    verifiedAt: new Date(),
  });
  await adminDb.collection("scouts").doc("scout_to_del_student").set({
    organizationId: "some_org",
    targetUserId: studentUid,
    templateId: 4,
    isRead: false,
  });

  // 管理者としてログインし、現行 AdminDashboardScreen._deleteUser と同じ手順を実行
  await loginTestUser("p24_admin_actor", "admin-p24@example.com", { admin: true });
  await adminDb.collection("users").doc(studentUid).delete();
  // トリガーが先にAuthを消していても deleteAuthUser がエラーにならないこと
  const delRes = await httpsCallable(clientFunctions, "deleteAuthUser")({ uid: studentUid });
  assert.equal(delRes.data.success, true);

  const cleaned = await waitForCondition(async () => {
    const privDoc = await adminDb.collection("users").doc(studentUid).collection("private").doc("verification").get();
    const lockDoc = await adminDb.collection("university_email_locks").doc(emailLockId).get();
    const scoutDoc = await adminDb.collection("scouts").doc("scout_to_del_student").get();
    return !privDoc.exists && !lockDoc.exists && !scoutDoc.exists;
  });
  assert.equal(cleaned, true, "学生削除後に private/verification・university_email_locks・スカウトのいずれかが残存しています");
});

// ============================================================================
// 【P3-3】setAdminClaim クレーム保持 ＆ removeAdminClaim の自己剥奪ガード
// ============================================================================

test("[P3-3] setAdminClaim は既存カスタムクレームを保持し、removeAdminClaim は自分自身の権限剥奪を拒否する", async () => {
  const adminUid = "p33_sole_admin";
  const subUserUid = "p33_sub_user";

  await loginTestUser(subUserUid, "sub@example.com", { betaTester: true });
  await loginTestUser(adminUid, "sole-admin@example.com", { admin: true });

  const setAdmin = httpsCallable(clientFunctions, "setAdminClaim");
  const removeAdmin = httpsCallable(clientFunctions, "removeAdminClaim");

  // 自分自身の管理者権限剥奪は拒否されること
  await assert.rejects(
    () => removeAdmin({ uid: adminUid }),
    (err) => err.code === "functions/failed-precondition",
  );

  // 他ユーザーへの付与時は既存の betaTester クレームを上書き消失させないこと
  await setAdmin({ uid: subUserUid });
  const afterGrant = await adminAuth.getUser(subUserUid);
  assert.equal(afterGrant.customClaims.admin, true);
  assert.equal(afterGrant.customClaims.betaTester, true, "既存のカスタムクレームが上書き消失しました");

  // 他ユーザーからの剥奪時も betaTester クレームが残ること
  await removeAdmin({ uid: subUserUid });
  const afterRemove = await adminAuth.getUser(subUserUid);
  assert.ok(!afterRemove.customClaims?.admin);
  assert.equal(afterRemove.customClaims.betaTester, true);
});

// ============================================================================
// 【P3-4】新規通報・新規団体申請の運営通知トリガー（24時間以内確認の担保）
// ============================================================================

test("[P3-4] 新規通報・新規団体申請の作成時に運営通知トリガーが動作し、シードデータはスキップする", async () => {
  const reportId = "p34_live_report";
  const seedReportId = "p34_seed_report";
  const orgId = "p34_live_pending_org";

  await adminDb.collection("reports").doc(reportId).set({
    reporterId: "st_1",
    reporterRole: "student",
    targetType: "organization",
    targetId: "org_1",
    targetName: "<script>alert(1)</script>悪質サークル",
    reason: "harassment",
    detail: "嫌がらせがありました",
    status: "open",
    createdAt: new Date(),
  });

  await adminDb.collection("reports").doc(seedReportId).set({
    reporterId: "review_student",
    reporterRole: "student",
    targetType: "organization",
    targetId: "review_org",
    targetName: "デモ団体",
    reason: "spam",
    detail: "",
    status: "open",
    isReviewSeed: true,
    createdAt: new Date(),
  });

  await adminDb.collection("organizations").doc(orgId).set({
    name: "新規申請テニス部",
    status: "pending",
    representativeId: orgId,
    createdAt: new Date(),
  });

  const notified = await waitForCondition(async () => {
    const rNote = await adminDb.collection("admin_notifications").doc(`report_${reportId}`).get();
    const oNote = await adminDb.collection("admin_notifications").doc(`org_${orgId}`).get();
    return rNote.exists && oNote.exists;
  });
  assert.equal(notified, true, "通報または新規団体申請の運営通知トリガーが記録を作成していません");

  // HTMLエスケープの確認（管理者のメーラーでのHTMLインジェクション防止）
  const reportNotification = (await adminDb.collection("admin_notifications").doc(`report_${reportId}`).get()).data();
  assert.ok(!reportNotification.escapedTargetName.includes("<script>"));

  // isReviewSeed: true のデータは通知対象外であること
  const seedNote = await adminDb.collection("admin_notifications").doc(`report_${seedReportId}`).get();
  assert.equal(seedNote.exists, false);
});

// ============================================================================
// 【追加検証】本人退会と削除トリガーの競合防止 ＆ verifyCode 認証状態すり替え防止
// ============================================================================

test("[P2-4d] Storage画像・イベントを持つ学生・団体の本人退会（deleteMyAccount）で削除トリガーが重複実行・競合せず一発で完了する", async () => {
  // 1) 学生の本人退会（Storage複数写真付き）
  const uid = "p24_self_delete_with_storage";
  const email = "selfdel@mail2.doshisha.ac.jp";

  await adminDb.collection("users").doc(uid).set({
    name: "退会テスト学生",
    isStudentVerified: true,
    createdAt: new Date(),
  });
  await adminDb.collection("users").doc(uid).collection("private").doc("verification").set({
    universityEmail: email,
  });

  const bucket = admin.storage().bucket();
  for (let i = 0; i < 5; i++) {
    await bucket.file(`users/${uid}/photos/photo_${i}.png`).save(
      Buffer.from([0x89, 0x50, 0x4e, 0x47]),
      { contentType: "image/png" },
    );
  }

  await loginTestUser(uid, email);
  const delRes = await httpsCallable(clientFunctions, "deleteMyAccount")();
  assert.equal(delRes.data.success, true);

  const [remainingFiles] = await bucket.getFiles({ prefix: `users/${uid}/` });
  assert.equal(remainingFiles.length, 0, "退会後に Storage 画像が残存しています");

  await assert.rejects(
    () => adminAuth.getUser(uid),
    (err) => err.code === "auth/user-not-found",
  );

  // 2) 団体の本人退会（Storageロゴ・写真＋主催イベント＋申込データ付き）
  const orgUid = "p24_self_delete_org";
  const orgEmail = "selfdel-org@example.com";
  await adminDb.collection("organizations").doc(orgUid).set({
    name: "退会テスト団体",
    status: "verified",
    representativeId: orgUid,
    createdAt: new Date(),
  });
  await adminDb.collection("events").doc("selfdel_org_ev").set({
    organizationId: orgUid,
    title: "退会団体イベント",
  });
  await adminDb.collection("events").doc("selfdel_org_ev").collection("applications").doc("st_1").set({
    studentId: "st_1",
    studentName: "申込学生",
    status: "applied",
  });
  for (let i = 0; i < 3; i++) {
    await bucket.file(`organizations/${orgUid}/photos/p_${i}.png`).save(
      Buffer.from([0x89, 0x50, 0x4e, 0x47]),
      { contentType: "image/png" },
    );
  }

  await loginTestUser(orgUid, orgEmail);
  const orgDelRes = await httpsCallable(clientFunctions, "deleteMyAccount")();
  assert.equal(orgDelRes.data.success, true);

  const [remainingOrgFiles] = await bucket.getFiles({ prefix: `organizations/${orgUid}/` });
  assert.equal(remainingOrgFiles.length, 0, "団体退会後に Storage 画像が残存しています");

  // トリガーの非同期発火完了を待ち、削除中マーカーがゴミとして残っていないことを確認
  const markersCleaned = await waitForCondition(async () => {
    const m1 = await adminDb.collection("_account_deletions").doc(uid).get();
    const m2 = await adminDb.collection("_account_deletions").doc(orgUid).get();
    return !m1.exists && !m2.exists;
  });
  assert.equal(markersCleaned, true, "退会完了後に _account_deletions マーカーが残存しています");
});

test("[P0-1e] sendVerificationCode 後に Auth メールを外部アドレスへすり替えたり団体化して verifyCode を呼んでも拒否される", async () => {
  const uid = "p01_swap_email_attacker";
  const uniEmail = "swaptest@mail2.doshisha.ac.jp";

  await adminDb.collection("users").doc(uid).set({
    isStudentVerified: false,
    createdAt: new Date(),
  });
  await loginTestUser(uid, uniEmail);
  const sendCode = httpsCallable(clientFunctions, "sendVerificationCode");
  const verifyCode = httpsCallable(clientFunctions, "verifyCode");

  await sendCode({ email: uniEmail });
  const priv = await adminDb.collection("users").doc(uid).collection("private").doc("verification").get();
  const code = crackSixDigitHash(priv.data().codeHashedValue);

  // 1) コード受信後に Firebase Auth のメールアドレスを外部 Gmail に変更して verifyCode を試みる
  await adminAuth.updateUser(uid, { email: "swapped-external@gmail.com" });

  await assert.rejects(
    () => verifyCode({ code }),
    (err) => err.code === "functions/permission-denied",
  );

  const afterUser = await adminDb.collection("users").doc(uid).get();
  assert.equal(afterUser.data().isStudentVerified, false, "メールすり替え後に学生認証が通過してしまいました");

  // 2) メールを戻しても、同UIDに団体ドキュメントが存在する状態では verifyCode を拒否する
  await adminAuth.updateUser(uid, { email: uniEmail });
  await adminDb.collection("organizations").doc(uid).set({
    name: "二重ロール偽装団体",
    status: "pending",
    representativeId: uid,
  });

  await assert.rejects(
    () => verifyCode({ code }),
    (err) => err.code === "functions/failed-precondition",
  );
});


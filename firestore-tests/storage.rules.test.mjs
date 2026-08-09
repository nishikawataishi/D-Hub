/**
 * storage.rules の単体テスト
 *
 * 実行方法（リポジトリルートから）:
 *   cd firestore-tests && npm test
 * （内部で firebase emulators:exec --only firestore,storage を起動する）
 *
 * ⚠️ このファイルの主目的は「削除が実際に通ること」の検証。
 * 以前 create/update/delete をまとめて `allow write` で書いていたため、
 * 削除リクエストでは request.resource が null になり isImage() /
 * isLessThan5MB() が評価できず、削除が「常に」拒否されていた。
 * その結果、退会時もアイコン差し替え時も画像が Storage に残り続けていた。
 *
 * 気づけなかったのは、拒否されるべきものが拒否されることばかり試していて
 * 「許可されるべきものが許可されるか」を誰も試していなかったため。
 * 以下の「削除できる」系はそのリグレッション防止であり、消してはいけない。
 */

import { test, before, after, beforeEach } from "node:test";
import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import { ref, uploadBytes, getBytes, deleteObject } from "firebase/storage";

const PROJECT_ID = "d-scout-rules-test";

// テスト用UID
const STUDENT = "student_uid";
const OTHER_STUDENT = "other_student_uid";
const ORG_VERIFIED = "org_verified_uid";

// PNG のシグネチャ。中身は検証されないが contentType はルールが見る
const IMAGE = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const AS_IMAGE = { contentType: "image/png" };
const AS_TEXT = { contentType: "text/plain" };
// isLessThan5MB() の境界（5 * 1024 * 1024）をちょうど1バイト超える
const OVER_5MB = new Uint8Array(5 * 1024 * 1024 + 1);

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: readFileSync(new URL("../storage.rules", import.meta.url), "utf8"),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
  // 読み取り・削除の対象になる既存ファイルをルール無効化して配置
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const s = ctx.storage();
    await uploadBytes(ref(s, `users/${STUDENT}/icon/me.png`), IMAGE, AS_IMAGE);
    await uploadBytes(ref(s, `users/${STUDENT}/photos/p1.png`), IMAGE, AS_IMAGE);
    await uploadBytes(
      ref(s, `organizations/${ORG_VERIFIED}/logo/logo.png`), IMAGE, AS_IMAGE,
    );
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).storage();
const asAnon = () => testEnv.unauthenticatedContext().storage();

// ==========================================================
// 1. 読み取り（allow read: if isAuthenticated()）
// ==========================================================

test("未認証はユーザーアイコンを読めない", async () => {
  await assertFails(getBytes(ref(asAnon(), `users/${STUDENT}/icon/me.png`)));
});

test("未認証は団体ロゴを読めない", async () => {
  await assertFails(
    getBytes(ref(asAnon(), `organizations/${ORG_VERIFIED}/logo/logo.png`)),
  );
});

// 現仕様の明文化。マッチング用途なので他人の写真は見える設計だが、
// 「意図してそうなっている」ことをテストで固定しておく。
// 仕様を変えるならこのテストを直すことになり、変更が可視化される。
test("認証済みなら他人のアイコンも読める（現仕様）", async () => {
  await assertSucceeds(
    getBytes(ref(as(OTHER_STUDENT), `users/${STUDENT}/icon/me.png`)),
  );
});

// ==========================================================
// 2. ユーザーアイコン（users/{userId}/icon/）
// ==========================================================

test("本人は自分のアイコンをアップロードできる", async () => {
  await assertSucceeds(uploadBytes(
    ref(as(STUDENT), `users/${STUDENT}/icon/new.png`), IMAGE, AS_IMAGE,
  ));
});

test("他人のアイコン領域にはアップロードできない", async () => {
  await assertFails(uploadBytes(
    ref(as(OTHER_STUDENT), `users/${STUDENT}/icon/evil.png`), IMAGE, AS_IMAGE,
  ));
});

test("未認証はアップロードできない", async () => {
  await assertFails(uploadBytes(
    ref(asAnon(), `users/${STUDENT}/icon/anon.png`), IMAGE, AS_IMAGE,
  ));
});

test("画像以外のファイルはアップロードできない", async () => {
  await assertFails(uploadBytes(
    ref(as(STUDENT), `users/${STUDENT}/icon/bad.txt`), IMAGE, AS_TEXT,
  ));
});

test("5MBを超える画像はアップロードできない", async () => {
  await assertFails(uploadBytes(
    ref(as(STUDENT), `users/${STUDENT}/icon/huge.png`), OVER_5MB, AS_IMAGE,
  ));
});

// ⭐ リグレッション防止（冒頭コメント参照）
test("本人は自分のアイコンを削除できる", async () => {
  await assertSucceeds(
    deleteObject(ref(as(STUDENT), `users/${STUDENT}/icon/me.png`)),
  );
});

test("他人のアイコンは削除できない", async () => {
  await assertFails(
    deleteObject(ref(as(OTHER_STUDENT), `users/${STUDENT}/icon/me.png`)),
  );
});

test("未認証は削除できない", async () => {
  await assertFails(
    deleteObject(ref(asAnon(), `users/${STUDENT}/icon/me.png`)),
  );
});

// ==========================================================
// 3. プロフィール写真（users/{userId}/photos/）
// ==========================================================

test("本人は自分のプロフィール写真をアップロードできる", async () => {
  await assertSucceeds(uploadBytes(
    ref(as(STUDENT), `users/${STUDENT}/photos/p2.png`), IMAGE, AS_IMAGE,
  ));
});

test("他人のプロフィール写真領域にはアップロードできない", async () => {
  await assertFails(uploadBytes(
    ref(as(OTHER_STUDENT), `users/${STUDENT}/photos/evil.png`), IMAGE, AS_IMAGE,
  ));
});

// ⭐ リグレッション防止
test("本人は自分のプロフィール写真を削除できる", async () => {
  await assertSucceeds(
    deleteObject(ref(as(STUDENT), `users/${STUDENT}/photos/p1.png`)),
  );
});

// ==========================================================
// 4. 団体ロゴ・活動写真（organizations/{orgId}/{folder}/）
// ==========================================================

test("団体は自分のロゴをアップロードできる", async () => {
  await assertSucceeds(uploadBytes(
    ref(as(ORG_VERIFIED), `organizations/${ORG_VERIFIED}/logo/new.png`),
    IMAGE, AS_IMAGE,
  ));
});

test("他人の団体領域にはアップロードできない", async () => {
  await assertFails(uploadBytes(
    ref(as(STUDENT), `organizations/${ORG_VERIFIED}/logo/evil.png`),
    IMAGE, AS_IMAGE,
  ));
});

// ⭐ リグレッション防止（退会時に団体画像が消えずに残っていた）
test("団体は自分のロゴを削除できる", async () => {
  await assertSucceeds(deleteObject(
    ref(as(ORG_VERIFIED), `organizations/${ORG_VERIFIED}/logo/logo.png`),
  ));
});

test("他人は団体のロゴを削除できない", async () => {
  await assertFails(deleteObject(
    ref(as(STUDENT), `organizations/${ORG_VERIFIED}/logo/logo.png`),
  ));
});

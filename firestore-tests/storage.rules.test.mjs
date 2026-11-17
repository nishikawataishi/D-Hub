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
import { doc, setDoc } from "firebase/firestore";
import { ref, uploadBytes, getBytes, deleteObject } from "firebase/storage";

const PROJECT_ID = process.env.GCLOUD_PROJECT || "d-scout-rules-test";

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
    firestore: {
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
    },
    storage: {
      rules: readFileSync(new URL("../storage.rules", import.meta.url), "utf8"),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  // 読み取り・削除の対象になる既存ファイルおよびアカウント認可状態（Firestore）を配置
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", STUDENT), {
      name: "学生A", isStudentVerified: true,
    });
    await setDoc(doc(db, "users", OTHER_STUDENT), {
      name: "学生B", isStudentVerified: true,
    });
    await setDoc(doc(db, "organizations", ORG_VERIFIED), {
      name: "承認済み団体", status: "verified", representativeId: ORG_VERIFIED,
    });

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

// ==========================================================
// 5. セキュリティ強化（P0-2）および審査待ち/却下団体の互換性検証
// ==========================================================

const UNVERIFIED_STUDENT = "unverified_student_uid";
const BARE_AUTH_USER = "bare_auth_uid";
const ORG_PENDING = "org_pending_uid";
const ORG_REJECTED = "org_rejected_uid";
const ADMIN = "admin_uid";

const asAdmin = () => testEnv.authenticatedContext(ADMIN, { admin: true }).storage();

const seedStorageHardeningFixtures = async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", UNVERIFIED_STUDENT), {
      isStudentVerified: false,
    });
    await setDoc(doc(db, "organizations", ORG_PENDING), {
      name: "審査中団体", status: "pending", representativeId: ORG_PENDING,
    });
    await setDoc(doc(db, "organizations", ORG_REJECTED), {
      name: "却下団体", status: "rejected", representativeId: ORG_REJECTED,
    });

    const s = ctx.storage();
    await uploadBytes(
      ref(s, `organizations/${ORG_PENDING}/photos/proof.png`), IMAGE, AS_IMAGE,
    );
    await uploadBytes(
      ref(s, `organizations/${ORG_VERIFIED}/proof/secret_proof.png`), IMAGE, AS_IMAGE,
    );
  });
};

test("[P0-2] 未認証学生・外部AuthアカウントはStorage画像の閲覧もアップロードもできない", async () => {
  await seedStorageHardeningFixtures();

  await assertFails(getBytes(ref(as(UNVERIFIED_STUDENT), `users/${STUDENT}/icon/me.png`)));
  await assertFails(getBytes(ref(as(UNVERIFIED_STUDENT), `organizations/${ORG_VERIFIED}/logo/logo.png`)));
  await assertFails(getBytes(ref(as(BARE_AUTH_USER), `users/${STUDENT}/icon/me.png`)));

  await assertFails(uploadBytes(
    ref(as(UNVERIFIED_STUDENT), `users/${UNVERIFIED_STUDENT}/icon/evil.png`),
    IMAGE,
    AS_IMAGE,
  ));
  await assertFails(uploadBytes(
    ref(as(UNVERIFIED_STUDENT), `organizations/${UNVERIFIED_STUDENT}/logo/evil.png`),
    IMAGE,
    AS_IMAGE,
  ));
  await assertFails(uploadBytes(
    ref(as(BARE_AUTH_USER), `organizations/${BARE_AUTH_USER}/logo/evil.png`),
    IMAGE,
    AS_IMAGE,
  ));
});

test("[P0-2] 認証済み学生であっても審査待ち団体の画像や proof フォルダは読めない（管理者は閲覧可）", async () => {
  await seedStorageHardeningFixtures();

  await assertFails(getBytes(
    ref(as(STUDENT), `organizations/${ORG_PENDING}/photos/proof.png`),
  ));
  await assertFails(getBytes(
    ref(as(STUDENT), `organizations/${ORG_VERIFIED}/proof/secret_proof.png`),
  ));
  await assertSucceeds(getBytes(
    ref(asAdmin(), `organizations/${ORG_PENDING}/photos/proof.png`),
  ));
  await assertSucceeds(getBytes(
    ref(asAdmin(), `organizations/${ORG_VERIFIED}/proof/secret_proof.png`),
  ));
});

test("[互換性2] 審査待ち/却下団体は自団体のロゴ・活動写真をアップロード・読み取り・削除できる", async () => {
  await seedStorageHardeningFixtures();

  for (const orgUid of [ORG_PENDING, ORG_REJECTED]) {
    await assertSucceeds(uploadBytes(
      ref(as(orgUid), `organizations/${orgUid}/logo/uuid_logo.png`),
      IMAGE,
      AS_IMAGE,
    ));
    await assertSucceeds(getBytes(
      ref(as(orgUid), `organizations/${orgUid}/logo/uuid_logo.png`),
    ));
    await assertSucceeds(uploadBytes(
      ref(as(orgUid), `organizations/${orgUid}/photos/uuid_photo.png`),
      IMAGE,
      AS_IMAGE,
    ));
    await assertSucceeds(deleteObject(
      ref(as(orgUid), `organizations/${orgUid}/logo/uuid_logo.png`),
    ));
  }
});

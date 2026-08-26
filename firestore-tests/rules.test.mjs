/**
 * firestore.rules の単体テスト
 *
 * 実行方法（リポジトリルートから）:
 *   cd firestore-tests && npm test
 * （内部で firebase emulators:exec --only firestore を起動する）
 *
 * 特に2026-06-10に修正した脆弱性のリグレッションを防ぐ:
 *   1. 団体statusの自己承認バイパス
 *   2. users delete→再createによる学生認証バイパス
 *   3. scouts コレクションの全件ダンプ
 *   4. レート制限カウンタ等の自己改ざん
 *   5. private サブコレクションへのクライアントアクセス
 *
 * 2026-07-31に追加した定型文スカウトの検証も含む:
 *   6. スカウト本文の自由記述が保存できないこと
 *
 * 2026-08-04に追加した通報・ブロックの検証も含む:
 *   7. 通報は運営しか読めないこと（利用規約 第7条4）
 *   8. ブロックしたことが相手から見えないこと（同 第8条3）
 *   9. ブロックした団体からスカウトが届かないこと（同 第8条2）
 */

import { test, before, after, beforeEach } from "node:test";
import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import {
  doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc,
  collection, query, where,
} from "firebase/firestore";

const PROJECT_ID = "d-scout-rules-test";

// テスト用UID
const STUDENT = "student_uid";
const OTHER_STUDENT = "other_student_uid";
const ORG_VERIFIED = "org_verified_uid";   // 承認済み団体
const ORG_PENDING = "org_pending_uid";     // 審査中団体
const ADMIN = "admin_uid";

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // 共通シードデータ（ルールを無効化して投入）
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "organizations", ORG_VERIFIED), {
      name: "承認済み団体", status: "verified", representativeId: ORG_VERIFIED,
      categories: ["sports"],
    });
    await setDoc(doc(db, "organizations", ORG_PENDING), {
      name: "審査中団体", status: "pending", representativeId: ORG_PENDING,
      categories: ["sports"],
    });
    await setDoc(doc(db, "users", STUDENT), {
      name: "学生A", isStudentVerified: true,
      interests: ["スポーツ", "音楽"], mainCampus: "imadegawa", grade: 2,
    });
    await setDoc(doc(db, "users", OTHER_STUDENT), {
      name: "学生B", isStudentVerified: true,
      interests: ["ボランティア"], mainCampus: "kyotanabe", grade: 4,
    });
    await setDoc(doc(db, "users", STUDENT, "private", "verification"), {
      universityEmail: "a@mail.doshisha.ac.jp", codeSentCount: 3,
    });
    // 定型文スカウトの埋め込み先として使うイベント
    await setDoc(doc(db, "events", "event_of_verified"), {
      organizationId: ORG_VERIFIED, title: "新歓ライブ",
    });
    await setDoc(doc(db, "events", "event_of_pending"), {
      organizationId: ORG_PENDING, title: "他団体のイベント",
    });
    await setDoc(doc(db, "scouts", "scout_to_A"), {
      targetUserId: STUDENT, organizationId: ORG_VERIFIED,
      templateId: 4, isRead: false,
    });
    await setDoc(doc(db, "scouts", "scout_to_B"), {
      targetUserId: OTHER_STUDENT, organizationId: ORG_VERIFIED,
      templateId: 4, isRead: false,
    });
    // 読み取り権限を確かめるための既存の通報
    await setDoc(doc(db, "reports", "seeded_report"), {
      reporterId: STUDENT, reporterRole: "student",
      targetType: "organization", targetId: ORG_VERIFIED,
      targetName: "承認済み団体", reason: "inappropriate_content",
      detail: "", snapshot: {}, status: "open", createdAt: new Date(),
    });
  });
});

const as = (uid, claims) => testEnv.authenticatedContext(uid, claims).firestore();
const asAdmin = () => as(ADMIN, { admin: true });
const asAnon = () => testEnv.unauthenticatedContext().firestore();

// ==========================================================
// 1. 団体 status の自己承認バイパス（High修正のリグレッション）
// ==========================================================

test("団体オーナーは status 単独の変更ができない", async () => {
  await assertFails(updateDoc(
    doc(as(ORG_PENDING), "organizations", ORG_PENDING),
    { status: "verified" },
  ));
});

test("団体オーナーは status を他フィールドと同時にも変更できない（バイパス対策）", async () => {
  await assertFails(updateDoc(
    doc(as(ORG_PENDING), "organizations", ORG_PENDING),
    { status: "verified", name: "新しい名前" },
  ));
});

test("団体オーナーは verifiedAt / representativeId も変更できない", async () => {
  await assertFails(updateDoc(
    doc(as(ORG_PENDING), "organizations", ORG_PENDING),
    { verifiedAt: new Date(), name: "x" },
  ));
  await assertFails(updateDoc(
    doc(as(ORG_PENDING), "organizations", ORG_PENDING),
    { representativeId: "someone_else", name: "x" },
  ));
});

test("団体オーナーは status 以外のプロフィールは更新できる", async () => {
  await assertSucceeds(updateDoc(
    doc(as(ORG_PENDING), "organizations", ORG_PENDING),
    { name: "新団体名", description: "説明" },
  ));
});

test("管理者は status を変更できる", async () => {
  await assertSucceeds(updateDoc(
    doc(asAdmin(), "organizations", ORG_PENDING),
    { status: "verified" },
  ));
});

test("団体の create は status=pending かつ representativeId=自分 のみ", async () => {
  await assertFails(setDoc(doc(as("new_org"), "organizations", "new_org"), {
    name: "x", status: "verified", representativeId: "new_org",
  }));
  await assertFails(setDoc(doc(as("new_org"), "organizations", "new_org"), {
    name: "x", status: "pending", representativeId: "someone_else",
  }));
  await assertSucceeds(setDoc(doc(as("new_org"), "organizations", "new_org"), {
    name: "x", status: "pending", representativeId: "new_org",
  }));
});

test("団体オーナーは自分の団体を削除できる（退会処理）", async () => {
  await assertSucceeds(deleteDoc(doc(as(ORG_PENDING), "organizations", ORG_PENDING)));
});

test("他人の団体は削除できない", async () => {
  await assertFails(deleteDoc(doc(as(STUDENT), "organizations", ORG_PENDING)));
});

// ==========================================================
// 1-b. organizations の一覧取得（審査中・却下団体の漏えい防止）
//
// allow list とクライアントの .where('status', isEqualTo: 'verified') は対。
// 片方だけ変えるとホーム画面が無言で空になるので、両方をここで固める。
// ==========================================================

test("organizations list: 条件なしの全件クエリは拒否される", async () => {
  await assertFails(getDocs(collection(as(STUDENT), "organizations")));
  await assertFails(getDocs(collection(as(ORG_VERIFIED), "organizations")));
});

test("organizations list: status=verified に絞れば取得できる（getOrganizations のクエリ形状）", async () => {
  await assertSucceeds(getDocs(query(
    collection(as(STUDENT), "organizations"),
    where("status", "==", "verified"),
  )));
});

test("organizations list: カテゴリ絞り込みも status 付きなら取得できる（getOrganizationsByCategory のクエリ形状）", async () => {
  await assertSucceeds(getDocs(query(
    collection(as(STUDENT), "organizations"),
    where("status", "==", "verified"),
    where("categories", "array-contains", "sports"),
  )));
});

test("organizations list: カテゴリだけで status を付けないクエリは拒否される", async () => {
  await assertFails(getDocs(query(
    collection(as(STUDENT), "organizations"),
    where("categories", "array-contains", "sports"),
  )));
});

test("organizations list: 審査中団体を狙うクエリは拒否される", async () => {
  await assertFails(getDocs(query(
    collection(as(STUDENT), "organizations"),
    where("status", "==", "pending"),
  )));
});

test("organizations list: 未認証は verified に絞っても取得できない", async () => {
  await assertFails(getDocs(query(
    collection(asAnon(), "organizations"),
    where("status", "==", "verified"),
  )));
});

test("organizations list: 管理者は全件取得できる（管理画面）", async () => {
  await assertSucceeds(getDocs(collection(asAdmin(), "organizations")));
});

test("organizations create: 他人の UID を docId にした先取りは拒否される", async () => {
  // docId 制約が無いと、任意の学生の UID で団体文書を作って
  // その学生を団体アカウントと誤判定させ、アプリを使えなくできる。
  await assertFails(setDoc(doc(as("attacker_uid"), "organizations", OTHER_STUDENT), {
    name: "x", status: "pending", representativeId: OTHER_STUDENT,
  }));
});

// ==========================================================
// 2. 学生認証バイパス（High修正のリグレッション）
// ==========================================================

test("users create: isStudentVerified=false なら作成できる", async () => {
  await assertSucceeds(setDoc(doc(as("new_user"), "users", "new_user"), {
    isStudentVerified: false, createdAt: new Date(),
  }));
});

test("users create: isStudentVerified=true での作成は拒否（再createバイパス対策）", async () => {
  await assertFails(setDoc(doc(as("new_user"), "users", "new_user"), {
    isStudentVerified: true,
  }));
});

test("users create: 認証管理フィールド持ち込みは拒否", async () => {
  await assertFails(setDoc(doc(as("new_user"), "users", "new_user"), {
    isStudentVerified: false, codeHashedValue: "fake_hash",
  }));
  await assertFails(setDoc(doc(as("new_user"), "users", "new_user"), {
    isStudentVerified: false, verifiedAt: new Date(),
  }));
  await assertFails(setDoc(doc(as("new_user"), "users", "new_user"), {
    isStudentVerified: false, codeSentCount: 0,
  }));
  await assertFails(setDoc(doc(as("new_user"), "users", "new_user"), {
    isStudentVerified: false, universityEmail: "fake@mail.doshisha.ac.jp",
  }));
});

test("users update: 本人はプロフィールを更新できる", async () => {
  await assertSucceeds(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    name: "新しい名前", faculty: "法学部", photoUrls: [],
  }));
});

test("users update: isStudentVerified の改ざんは拒否", async () => {
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    isStudentVerified: false,
  }));
});

test("users delete: 本人は削除できる（退会処理）", async () => {
  await assertSucceeds(deleteDoc(doc(as(STUDENT), "users", STUDENT)));
});

// ==========================================================
// 3. scouts の全件ダンプ（High修正のリグレッション）
// ==========================================================

test("scouts: 条件なしの全件クエリは拒否される", async () => {
  await assertFails(getDocs(collection(as(STUDENT), "scouts")));
});

test("scouts: 他人宛のスカウトを対象にしたクエリは拒否される", async () => {
  await assertFails(getDocs(query(
    collection(as(STUDENT), "scouts"),
    where("targetUserId", "==", OTHER_STUDENT),
  )));
});

test("scouts: 自分宛のスカウトはクエリできる（学生）", async () => {
  const snap = await assertSucceeds(getDocs(query(
    collection(as(STUDENT), "scouts"),
    where("targetUserId", "==", STUDENT),
  )));
});

test("scouts: 自団体送信分はクエリできる（団体）", async () => {
  await assertSucceeds(getDocs(query(
    collection(as(ORG_VERIFIED), "scouts"),
    where("organizationId", "==", ORG_VERIFIED),
  )));
});

test("scouts: 対象学生は既読フラグのみ更新できる", async () => {
  await assertSucceeds(updateDoc(doc(as(STUDENT), "scouts", "scout_to_A"), {
    isRead: true, readAt: new Date(),
  }));
  await assertFails(updateDoc(doc(as(STUDENT), "scouts", "scout_to_A"), {
    message: "改ざん",
  }));
});

// ==========================================================
// 3-b. 定型文スカウト（自由記述の禁止）
// ==========================================================

test("scouts create: 自由記述は保存できない", async () => {
  // 旧形式の message フィールドは受け付けない
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_free1"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    message: "自由に書いたメッセージ", isRead: false,
  }));
  // 定型文に message を併記して忍ばせることもできない
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_free2"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 4, message: "こっそり本文", isRead: false,
  }));
  // 未知のフィールドに文章を入れることもできない
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_free3"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 4, note: "任意テキスト", isRead: false,
  }));
});

test("scouts create: 汎用定型文は承認済み団体のみ送れる", async () => {
  await assertSucceeds(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_generic"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 4, isRead: false,
  }));
  // 審査中団体は不可
  await assertFails(setDoc(doc(as(ORG_PENDING), "scouts", "s_pending"), {
    targetUserId: STUDENT, organizationId: ORG_PENDING,
    templateId: 4, isRead: false,
  }));
  // 定義されていない templateId は不可
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_bad_id"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 99, isRead: false,
  }));
});

test("scouts create: タグ定型文は学生が登録済みのタグに限る", async () => {
  await assertSucceeds(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_tag_ok"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 0, templateArg: "スポーツ", isRead: false,
  }));
  // 学生Aが登録していないタグ（学生Bのタグ）は不可
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_tag_ng1"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 0, templateArg: "ボランティア", isRead: false,
  }));
  // 任意の文章を埋め込むこともできない
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_tag_ng2"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 0, templateArg: "ここに好きな文章を書く", isRead: false,
  }));
});

test("scouts create: イベント定型文は自団体の実在イベントに限る", async () => {
  await assertSucceeds(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_ev_ok"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 1, templateArg: "新歓ライブ",
    templateEventId: "event_of_verified", isRead: false,
  }));
  // 他団体のイベントには招待できない
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_ev_other"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 1, templateArg: "他団体のイベント",
    templateEventId: "event_of_pending", isRead: false,
  }));
  // イベント名だけを別の文字列に差し替える＝自由記述の抜け道も塞ぐ
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_ev_fake"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 1, templateArg: "イベント名に見せかけた自由記述",
    templateEventId: "event_of_verified", isRead: false,
  }));
  // 存在しないイベントも不可
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_ev_missing"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 1, templateArg: "架空のイベント",
    templateEventId: "no_such_event", isRead: false,
  }));
});

test("scouts create: キャンパス・学年は対象学生の登録値と一致が必要", async () => {
  await assertSucceeds(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_campus_ok"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 2, templateArg: "imadegawa", isRead: false,
  }));
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_campus_ng"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 2, templateArg: "kyotanabe", isRead: false,
  }));
  await assertSucceeds(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_grade_ok"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 3, templateArg: "2", isRead: false,
  }));
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_grade_ng"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 3, templateArg: "4", isRead: false,
  }));
});

// ==========================================================
// 4. レート制限カウンタ等の自己改ざん（Medium修正のリグレッション）
// ==========================================================

test("users update: codeSentCount / codeSentWindowStart の改ざんは拒否", async () => {
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    codeSentCount: 0,
  }));
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    codeSentWindowStart: new Date(0),
  }));
});

test("users update: universityEmail / email の改ざんは拒否", async () => {
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    universityEmail: "fake@mail.doshisha.ac.jp",
  }));
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    email: "fake@example.com",
  }));
});

// ==========================================================
// 5. private サブコレクション（Medium修正のリグレッション）
// ==========================================================

test("private: 本人でも読み書きできない", async () => {
  await assertFails(getDoc(doc(as(STUDENT), "users", STUDENT, "private", "verification")));
  await assertFails(setDoc(doc(as(STUDENT), "users", STUDENT, "private", "verification"), {
    codeSentCount: 0,
  }));
});

test("private: 承認済み団体も読めない（学生メール保護）", async () => {
  await assertFails(getDoc(doc(as(ORG_VERIFIED), "users", STUDENT, "private", "verification")));
});

test("private: 管理者は読めるが書けない", async () => {
  await assertSucceeds(getDoc(doc(asAdmin(), "users", STUDENT, "private", "verification")));
  await assertFails(setDoc(doc(asAdmin(), "users", STUDENT, "private", "verification"), {
    codeSentCount: 0,
  }));
});

// ==========================================================
// 6. users の閲覧権限（基本）
// ==========================================================

test("users: 承認済み団体は学生一覧を取得できる", async () => {
  await assertSucceeds(getDocs(collection(as(ORG_VERIFIED), "users")));
});

test("users: 審査中団体・学生・未認証は一覧を取得できない", async () => {
  await assertFails(getDocs(collection(as(ORG_PENDING), "users")));
  await assertFails(getDocs(collection(as(STUDENT), "users")));
  await assertFails(getDocs(collection(asAnon(), "users")));
});

test("users: 学生は他の学生のプロフィールを読めない", async () => {
  await assertFails(getDoc(doc(as(STUDENT), "users", OTHER_STUDENT)));
});

// ==========================================================
// 7. 通報（利用規約 第7条）
// ==========================================================

/** 学生から団体への通報の雛形。overrides で一部を壊してテストする */
const reportDoc = (overrides = {}) => ({
  reporterId: STUDENT,
  reporterRole: "student",
  targetType: "organization",
  targetId: ORG_VERIFIED,
  targetName: "承認済み団体",
  reason: "inappropriate_content",
  detail: "",
  snapshot: { name: "承認済み団体" },
  status: "open",
  createdAt: new Date(),
  ...overrides,
});

test("reports create: 学生は団体を、団体は学生を通報できる", async () => {
  await assertSucceeds(setDoc(doc(as(STUDENT), "reports", "r_s2o"), reportDoc()));
  await assertSucceeds(setDoc(doc(as(ORG_VERIFIED), "reports", "r_o2s"), reportDoc({
    reporterId: ORG_VERIFIED, reporterRole: "organization",
    targetType: "user", targetId: STUDENT, targetName: "学生A",
  })));
});

test("reports create: 未認証は通報できない", async () => {
  await assertFails(setDoc(doc(asAnon(), "reports", "r_anon"), reportDoc()));
});

test("reports create: 自分自身は通報できない", async () => {
  await assertFails(setDoc(doc(as(STUDENT), "reports", "r_self"), reportDoc({
    targetType: "user", targetId: STUDENT, targetName: "学生A",
  })));
});

test("reports create: 通報者IDの詐称は拒否（他人になりすました通報を防ぐ）", async () => {
  await assertFails(setDoc(doc(as(STUDENT), "reports", "r_spoof"), reportDoc({
    reporterId: OTHER_STUDENT,
  })));
});

test("reports create: 未定義の理由・種別は拒否", async () => {
  await assertFails(setDoc(doc(as(STUDENT), "reports", "r_reason"), reportDoc({
    reason: "適当な理由",
  })));
  await assertFails(setDoc(doc(as(STUDENT), "reports", "r_type"), reportDoc({
    targetType: "event",
  })));
  await assertFails(setDoc(doc(as(STUDENT), "reports", "r_role"), reportDoc({
    reporterRole: "admin",
  })));
});

test("reports create: 対応済みでの作成・余計なフィールド・長すぎる補足は拒否", async () => {
  // 自分で status を closed にして運営の確認を飛ばすことはできない
  await assertFails(setDoc(doc(as(STUDENT), "reports", "r_closed"), reportDoc({
    status: "closed",
  })));
  await assertFails(setDoc(doc(as(STUDENT), "reports", "r_extra"), reportDoc({
    adminNote: "運営メモに見せかけた書き込み",
  })));
  await assertFails(setDoc(doc(as(STUDENT), "reports", "r_long"), reportDoc({
    detail: "あ".repeat(1001),
  })));
});

test("reports read: 通報者本人も他人も読めない（運営のみ確認する）", async () => {
  await assertFails(getDoc(doc(as(STUDENT), "reports", "seeded_report")));
  await assertFails(getDocs(collection(as(STUDENT), "reports")));
  // 通報された側から通報者を特定できないこと（第7条4）
  await assertFails(getDoc(doc(as(ORG_VERIFIED), "reports", "seeded_report")));
  await assertFails(getDocs(collection(as(ORG_VERIFIED), "reports")));
});

test("reports read/update: 管理者は閲覧と対応済み化ができる", async () => {
  await assertSucceeds(getDoc(doc(asAdmin(), "reports", "seeded_report")));
  await assertSucceeds(getDocs(collection(asAdmin(), "reports")));
  await assertSucceeds(updateDoc(doc(asAdmin(), "reports", "seeded_report"), {
    status: "closed", reviewedAt: new Date(),
  }));
});

test("reports update: 通報者・対象者は書き換えられない", async () => {
  await assertFails(updateDoc(doc(as(STUDENT), "reports", "seeded_report"), {
    status: "closed",
  }));
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "reports", "seeded_report"), {
    detail: "都合の悪い内容を消す",
  }));
  await assertFails(deleteDoc(doc(as(ORG_VERIFIED), "reports", "seeded_report")));
});

// ==========================================================
// 8. ブロック（利用規約 第8条）
// ==========================================================

const blockData = { targetName: "相手の名前", createdAt: new Date() };

test("blocks: 学生は自分のブロックを作成・取得・解除できる", async () => {
  await assertSucceeds(setDoc(
    doc(as(STUDENT), "users", STUDENT, "blocks", ORG_VERIFIED), blockData));
  await assertSucceeds(getDocs(
    collection(as(STUDENT), "users", STUDENT, "blocks")));
  await assertSucceeds(deleteDoc(
    doc(as(STUDENT), "users", STUDENT, "blocks", ORG_VERIFIED)));
});

test("blocks: ブロックされた側からは見えない（相手に通知されない）", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "users", STUDENT, "blocks", ORG_VERIFIED),
      blockData);
  });
  // 承認済み団体は users ドキュメント自体は読めるが、blocks は読めない
  await assertFails(getDoc(
    doc(as(ORG_VERIFIED), "users", STUDENT, "blocks", ORG_VERIFIED)));
  await assertFails(getDocs(
    collection(as(ORG_VERIFIED), "users", STUDENT, "blocks")));
  // 他人のブロックを勝手に解除することもできない
  await assertFails(deleteDoc(
    doc(as(ORG_VERIFIED), "users", STUDENT, "blocks", ORG_VERIFIED)));
});

test("blocks: 他人のブロック一覧に書き込めない", async () => {
  await assertFails(setDoc(
    doc(as(OTHER_STUDENT), "users", STUDENT, "blocks", ORG_VERIFIED), blockData));
  await assertFails(setDoc(
    doc(as(STUDENT), "organizations", ORG_VERIFIED, "blocks", STUDENT), blockData));
});

test("blocks: 団体は自分のブロックを操作でき、学生からは見えない", async () => {
  await assertSucceeds(setDoc(
    doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED, "blocks", STUDENT),
    blockData));
  await assertSucceeds(getDocs(
    collection(as(ORG_VERIFIED), "organizations", ORG_VERIFIED, "blocks")));
  await assertFails(getDoc(
    doc(as(STUDENT), "organizations", ORG_VERIFIED, "blocks", STUDENT)));
  await assertSucceeds(deleteDoc(
    doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED, "blocks", STUDENT)));
});

test("blocks: 管理者は通報対応のために閲覧できる", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "users", STUDENT, "blocks", ORG_VERIFIED),
      blockData);
  });
  await assertSucceeds(getDoc(
    doc(asAdmin(), "users", STUDENT, "blocks", ORG_VERIFIED)));
});

// ==========================================================
// 9. ブロックとスカウトの連動（利用規約 第8条2）
// ==========================================================

test("scouts create: ブロックした団体からはスカウトが届かない", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "users", STUDENT, "blocks", ORG_VERIFIED),
      blockData);
  });
  // 学生Aはこの団体をブロックしている
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_blocked"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 4, isRead: false,
  }));
  // ブロックしていない学生Bには変わらず送れる
  await assertSucceeds(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_not_blocked"), {
    targetUserId: OTHER_STUDENT, organizationId: ORG_VERIFIED,
    templateId: 4, isRead: false,
  }));
});

test("scouts create: ブロックを解除すれば再び届く", async () => {
  await assertSucceeds(setDoc(
    doc(as(STUDENT), "users", STUDENT, "blocks", ORG_VERIFIED), blockData));
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_before"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 4, isRead: false,
  }));
  await assertSucceeds(deleteDoc(
    doc(as(STUDENT), "users", STUDENT, "blocks", ORG_VERIFIED)));
  await assertSucceeds(setDoc(doc(as(ORG_VERIFIED), "scouts", "s_after"), {
    targetUserId: STUDENT, organizationId: ORG_VERIFIED,
    templateId: 4, isRead: false,
  }));
});

// ==========================================================
// 8. 退会時のデータ削除（規約第14条2のリグレッション）
// ==========================================================
// scouts には delete ルールが存在せず、退会しても学生名やLINE URLを含む
// スカウトが残り続けていた（管理者ですら消せなかった）。
// applications は本人しか消せず、団体がイベントを消すと孤児化していた。

/** イベント申し込みをルール無効で投入する */
const seedApplication = async (studentId = STUDENT) => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(ctx.firestore(), "events", "event_of_verified", "applications", studentId),
      { studentId, studentName: "学生A", status: "applied", appliedAt: new Date() },
    );
  });
};

const applicationRef = (db, studentId = STUDENT) =>
  doc(db, "events", "event_of_verified", "applications", studentId);

test("scouts delete: 対象学生は自分宛のスカウトを削除できる", async () => {
  await assertSucceeds(deleteDoc(doc(as(STUDENT), "scouts", "scout_to_A")));
});

test("scouts delete: 送信元団体は自分が送ったスカウトを削除できる", async () => {
  await assertSucceeds(deleteDoc(doc(as(ORG_VERIFIED), "scouts", "scout_to_A")));
});

test("scouts delete: 管理者は削除できる", async () => {
  await assertSucceeds(deleteDoc(doc(asAdmin(), "scouts", "scout_to_A")));
});

test("scouts delete: 無関係な学生・団体・未認証は削除できない", async () => {
  await assertFails(deleteDoc(doc(as(OTHER_STUDENT), "scouts", "scout_to_A")));
  await assertFails(deleteDoc(doc(as(ORG_PENDING), "scouts", "scout_to_A")));
  await assertFails(deleteDoc(doc(asAnon(), "scouts", "scout_to_A")));
});

test("applications delete: 申し込んだ学生本人はキャンセルできる", async () => {
  await seedApplication();
  await assertSucceeds(deleteDoc(applicationRef(as(STUDENT))));
});

test("applications delete: イベント主催団体は削除できる", async () => {
  await seedApplication();
  await assertSucceeds(deleteDoc(applicationRef(as(ORG_VERIFIED))));
});

test("applications delete: 管理者は削除できる", async () => {
  await seedApplication();
  await assertSucceeds(deleteDoc(applicationRef(asAdmin())));
});

test("applications delete: 別の学生・別団体・未認証は削除できない", async () => {
  await seedApplication();
  await assertFails(deleteDoc(applicationRef(as(OTHER_STUDENT))));
  await assertFails(deleteDoc(applicationRef(as(ORG_PENDING))));
  await assertFails(deleteDoc(applicationRef(asAnon())));
});

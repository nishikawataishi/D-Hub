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
  doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, addDoc,
  collection, query, where, orderBy, limit, serverTimestamp, Timestamp,
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

// ==========================================================
// 10. クラウドセキュリティ強化（P0-2, P1-4, P1-5, P3-3）および
//     現行App Store公開版アプリのロール別完全互換性テスト
// ==========================================================

const UNVERIFIED_STUDENT = "unverified_student_uid";
const BARE_AUTH_USER = "bare_auth_uid";
const ORG_REJECTED = "org_rejected_uid";

const VALID_STORAGE_USER_ICON =
  `https://firebasestorage.googleapis.com/v0/b/d-scout-6d281.firebasestorage.app/o/users%2F${STUDENT}%2Ficon%2Favatar.jpg?alt=media&token=1234`;
const VALID_STORAGE_ORG_LOGO =
  `https://firebasestorage.googleapis.com/v0/b/d-scout-6d281.firebasestorage.app/o/organizations%2F${ORG_VERIFIED}%2Flogo%2Flogo.jpg?alt=media&token=5678`;

/** 追加テスト用のシードデータ（未認証学生・却下団体・日時付きイベント等）を投入 */
const seedHardeningFixtures = async () => {
  const futureDate = Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
  const pastDate = Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", UNVERIFIED_STUDENT), {
      isStudentVerified: false,
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, "organizations", ORG_REJECTED), {
      name: "却下された団体",
      description: "修正前",
      categories: ["music"],
      campus: "kyotanabe",
      logoEmoji: "🎸",
      instagramUrl: "",
      groupLineUrl: "",
      status: "rejected",
      representativeId: ORG_REJECTED,
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, "events", "upcoming_event_strict"), {
      organizationId: ORG_VERIFIED,
      organizationName: "承認済み団体",
      organizationEmoji: "🏀",
      organizationCategory: "スポーツ",
      title: "新歓バスケ体験会",
      description: "初心者歓迎です",
      startAt: futureDate,
      campus: "imadegawa",
      fee: null,
      capacity: null,
      location: null,
      isReviewSeed: true,
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, "events", "past_hidden_event"), {
      organizationId: ORG_VERIFIED,
      organizationName: "承認済み団体",
      organizationEmoji: "🏀",
      organizationCategory: "スポーツ",
      title: "過去イベントに紛れ込ませたメッセージ",
      description: "詳細",
      startAt: pastDate,
      campus: "imadegawa",
      createdAt: Timestamp.now(),
    });
  });
};

test("[P0-2] 未認証学生・外部Authアカウントは承認済み団体一覧や個別団体を取得できない", async () => {
  await seedHardeningFixtures();
  await assertFails(getDocs(query(
    collection(as(UNVERIFIED_STUDENT), "organizations"),
    where("status", "==", "verified"),
  )));
  await assertFails(getDoc(doc(as(UNVERIFIED_STUDENT), "organizations", ORG_VERIFIED)));
  await assertFails(getDocs(query(
    collection(as(BARE_AUTH_USER), "organizations"),
    where("status", "==", "verified"),
  )));
});

test("[P0-2] 未認証学生・外部Authアカウントはイベント一覧・詳細を取得できない", async () => {
  await seedHardeningFixtures();
  await assertFails(getDocs(collection(as(UNVERIFIED_STUDENT), "events")));
  await assertFails(getDoc(doc(as(UNVERIFIED_STUDENT), "events", "upcoming_event_strict")));
  await assertFails(getDoc(doc(as(BARE_AUTH_USER), "events", "upcoming_event_strict")));
});

test("[P0-2] 未認証学生・外部Authアカウントはイベントに参加申し込みできない", async () => {
  await seedHardeningFixtures();
  await assertFails(setDoc(
    doc(as(UNVERIFIED_STUDENT), "events", "upcoming_event_strict", "applications", UNVERIFIED_STUDENT),
    {
      studentId: UNVERIFIED_STUDENT,
      studentName: "偽学生",
      studentFaculty: "偽学部",
      studentGrade: 1,
      status: "applied",
      appliedAt: serverTimestamp(),
    },
  ));
  await assertFails(setDoc(
    doc(as(BARE_AUTH_USER), "events", "upcoming_event_strict", "applications", BARE_AUTH_USER),
    {
      studentId: BARE_AUTH_USER,
      studentName: "部外者",
      studentFaculty: "外部",
      studentGrade: 1,
      status: "applied",
      appliedAt: serverTimestamp(),
    },
  ));
});

test("[P0-2] 未認証学生・外部Authアカウントは通報・お問い合わせを送信できない", async () => {
  await seedHardeningFixtures();
  await assertFails(addDoc(collection(as(UNVERIFIED_STUDENT), "reports"), {
    reporterId: UNVERIFIED_STUDENT,
    reporterRole: "student",
    targetType: "organization",
    targetId: ORG_VERIFIED,
    targetName: "承認済み団体",
    reason: "spam",
    detail: "いたずら通報",
    snapshot: {},
    status: "open",
    createdAt: serverTimestamp(),
  }));
  await assertFails(addDoc(collection(as(UNVERIFIED_STUDENT), "contacts"), {
    userId: UNVERIFIED_STUDENT,
    category: "その他",
    message: "未認証アカウントからの大量スパム送信テスト",
    status: "open",
    createdAt: serverTimestamp(),
  }));
});

test("[P1-4] users: 型破壊データ（文字列のgrade、非リストのinterests、数値混入タグ、不正キャンパス、長大文字列）を拒否", async () => {
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    grade: "二回生",
  }));
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    grade: 99,
  }));
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    interests: "音楽",
  }));
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    interests: [123, 456],
  }));
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    mainCampus: "invalid_campus",
  }));
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    unknownPayload: "x".repeat(5000),
  }));
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    name: "あ".repeat(200),
  }));
});

test("[P1-4] organizations: 未定義カテゴリ・不正キャンパス（HomeScreen全体クラッシュ攻撃）やisOfficial自己付与を拒否", async () => {
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    categories: ["non_existent_category"],
  }));
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    campus: "mars_campus",
  }));
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    isOfficial: true,
  }));
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    description: "あ".repeat(3000),
  }));
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    extraBomb: "x".repeat(5000),
  }));
});

test("[P1-4] contacts / reports / tags: 型不一致クラッシュ攻撃および巨大スナップショット爆弾・createdAt欠落を拒否", async () => {
  await assertFails(addDoc(collection(as(STUDENT), "contacts"), {
    userId: STUDENT,
    category: "バグ報告",
    message: 123456789,
    status: "open",
    createdAt: serverTimestamp(),
  }));
  await assertFails(addDoc(collection(as(STUDENT), "contacts"), {
    userId: STUDENT,
    category: "バグ報告",
    message: "あ".repeat(2500),
    status: "open",
    createdAt: serverTimestamp(),
  }));
  await assertFails(addDoc(collection(as(STUDENT), "reports"), {
    reporterId: STUDENT,
    reporterRole: "student",
    targetType: "organization",
    targetId: ORG_VERIFIED,
    targetName: "承認済み団体",
    reason: "spam",
    detail: "",
    snapshot: { maliciousDump: "x".repeat(10000) },
    status: "open",
    createdAt: serverTimestamp(),
  }));
  await assertFails(addDoc(collection(as(STUDENT), "reports"), {
    reporterId: STUDENT,
    reporterRole: "student",
    targetType: "organization",
    targetId: ORG_VERIFIED,
    targetName: "承認済み団体",
    reason: "spam",
    detail: "",
    snapshot: {},
    status: "open",
  }));
  await assertFails(addDoc(collection(as(ORG_VERIFIED), "tags"), {
    name: 99999,
    createdAt: serverTimestamp(),
  }));
  await assertFails(addDoc(collection(as(ORG_VERIFIED), "tags"), {
    name: "あ".repeat(200),
    createdAt: serverTimestamp(),
  }));
});

test("[P1-5] scouts: organizationName の詐称（別団体なりすまし・自由記述混入）を拒否", async () => {
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "spoof_org_name"), {
    targetUserId: STUDENT,
    organizationId: ORG_VERIFIED,
    organizationName: "同志社大学 学生支援課（至急LINE登録してください）",
    templateId: 4,
    isRead: false,
    sentAt: serverTimestamp(),
  }));
});

test("[P1-5] events & scouts: 長文タイトルや過去日時の隠しイベントによる自由記述スカウト抜け道を拒否", async () => {
  await seedHardeningFixtures();
  const futureDate = Timestamp.fromDate(new Date(Date.now() + 3 * 24 * 60 * 60 * 1000));
  const pastDate = Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000));

  await assertFails(addDoc(collection(as(ORG_VERIFIED), "events"), {
    organizationId: ORG_VERIFIED,
    organizationName: "承認済み団体",
    organizationEmoji: "🏀",
    organizationCategory: "スポーツ",
    title: "自由記述メッセージ".repeat(20),
    description: "詳細",
    startAt: futureDate,
    campus: "imadegawa",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));

  await assertFails(addDoc(collection(as(ORG_VERIFIED), "events"), {
    organizationId: ORG_VERIFIED,
    organizationName: "承認済み団体",
    organizationEmoji: "🏀",
    organizationCategory: "スポーツ",
    title: "一覧に出ない隠しイベント",
    description: "詳細",
    startAt: pastDate,
    campus: "imadegawa",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));

  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "hidden_event_scout"), {
    targetUserId: STUDENT,
    organizationId: ORG_VERIFIED,
    organizationName: "承認済み団体",
    templateId: 1,
    templateArg: "過去イベントに紛れ込ませたメッセージ",
    templateEventId: "past_hidden_event",
    isRead: false,
    sentAt: serverTimestamp(),
  }));

  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "events", "upcoming_event_strict"), {
    startAt: pastDate,
  }));
});

test("[P1-5] フィッシングURLの遮断（instagramUrl / groupLineUrl に外部サイトを設定不可）", async () => {
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    instagramUrl: "https://evil-phishing.example.com/instagram_login",
  }));
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    instagramUrl: "https://www.instagram.com@evil.example.com",
  }));
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    groupLineUrl: "https://evil-phishing.example.com/line_invite",
  }));
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    groupLineUrl: "https://line.me.evil.example.com/ti/g/12345",
  }));
  await assertFails(setDoc(doc(as(ORG_VERIFIED), "scouts", "phish_scout"), {
    targetUserId: STUDENT,
    organizationId: ORG_VERIFIED,
    organizationName: "承認済み団体",
    organizationGroupLineUrl: "https://evil-phishing.example.com/line",
    templateId: 4,
    isRead: false,
    sentAt: serverTimestamp(),
  }));
});

test("[P1-5] 外部画像URL（IPロガー・別プロジェクトStorageバケット）の混入を遮断", async () => {
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    iconUrl: "https://iplogger.example.com/pixel.png",
  }));
  await assertFails(updateDoc(doc(as(STUDENT), "users", STUDENT), {
    photoUrls: ["https://firebasestorage.googleapis.com/v0/b/evil-other-project.appspot.com/o/100mb.png?alt=media"],
  }));
  await assertFails(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    logoUrl: "https://iplogger.example.com/org_logo.png",
  }));
  await assertFails(updateDoc(doc(as(ORG_PENDING), "organizations", ORG_PENDING), {
    proofImageUrl: "https://iplogger.example.com/proof.png",
  }));
});

test("[P3-3] 認証済み学生はマイページから新しい興味タグを tags マスタに追加できる（未認証は不可）", async () => {
  await seedHardeningFixtures();
  const existing = await assertSucceeds(getDocs(query(
    collection(as(STUDENT), "tags"),
    where("name", "==", "サウナ"),
    limit(1),
  )));
  if (existing.empty) {
    await assertSucceeds(addDoc(collection(as(STUDENT), "tags"), {
      name: "サウナ",
      createdAt: serverTimestamp(),
    }));
  }
  await assertFails(addDoc(collection(as(UNVERIFIED_STUDENT), "tags"), {
    name: "不正タグ",
    createdAt: serverTimestamp(),
  }));
});

test("[互換性1] 登録直後の未認証学生による初期ドキュメント作成と _resolveUserStatus クエリが通る", async () => {
  const newStudentUid = "fresh_signup_student";
  const studentDb = as(newStudentUid);

  const beforeDoc = await assertSucceeds(getDoc(doc(studentDb, "users", newStudentUid)));
  if (!beforeDoc.exists()) {
    await assertSucceeds(setDoc(doc(studentDb, "users", newStudentUid), {
      isStudentVerified: false,
      createdAt: serverTimestamp(),
    }));
  }
  // 未認証アカウントが初期作成時にプロフィール名を紛れ込ませて学生一覧へ出ることは不可
  await assertFails(setDoc(doc(as("sneaky_unverified"), "users", "sneaky_unverified"), {
    isStudentVerified: false,
    name: "未認証なのに検索に出る名前",
    createdAt: serverTimestamp(),
  }));

  await assertSucceeds(getDoc(doc(studentDb, "organizations", newStudentUid)));
  await assertSucceeds(getDoc(doc(studentDb, "users", newStudentUid)));
});

test("[互換性2] 審査待ち/却下団体が OrgDashboardScreen を開いた際の全Firestoreクエリ・プロフィール編集が通る", async () => {
  await seedHardeningFixtures();
  for (const orgUid of [ORG_PENDING, ORG_REJECTED]) {
    const orgDb = as(orgUid);

    await assertSucceeds(getDoc(doc(orgDb, "organizations", orgUid)));
    await assertSucceeds(getDocs(collection(orgDb, "organizations", orgUid, "blocks")));
    await assertSucceeds(getDocs(query(
      collection(orgDb, "events"),
      where("organizationId", "==", orgUid),
      orderBy("startAt"),
    )));

    await assertSucceeds(updateDoc(doc(orgDb, "organizations", orgUid), {
      name: "新歓テストサークル",
      description: "活動紹介文を更新しました",
      categories: ["sports", "beginner"],
      campus: "both",
      logoEmoji: "🎾",
      instagramUrl: "@shinkan_test_2026",
      groupLineUrl: "https://line.me/ti/g2/abcdef12345",
      logoUrl: null,
      photoUrls: [
        `https://firebasestorage.googleapis.com/v0/b/d-scout-6d281.firebasestorage.app/o/organizations%2F${orgUid}%2Fphotos%2Fuuid_photo1.jpg?alt=media&token=abcd`,
      ],
    }));
  }
});

test("[互換性3] 団体の instagramUrl / groupLineUrl の全現行UI入力パターンが通る", async () => {
  const orgDb = as(ORG_VERIFIED);
  for (const insta of [
    "",
    "d_spirits",
    "@d_spirits.official",
    "d_spirits_2026/",
    "instagram.com/d_spirits",
    "www.instagram.com/d_spirits",
    "https://www.instagram.com/d_spirits/?igsh=MzRlODBiNWFlZA==",
    "https://instagram.com/d_spirits",
  ]) {
    await assertSucceeds(updateDoc(doc(orgDb, "organizations", ORG_VERIFIED), {
      instagramUrl: insta,
    }));
  }

  for (const lineUrl of [
    "",
    "https://line.me/ti/g/AbCdEf12345",
    "https://line.me/ti/g2/OpenChatInvite_123?utm_source=invitation",
    "https://line.me/R/ti/p/@official_circle",
    "https://lin.ee/AbCdEfG",
  ]) {
    await assertSucceeds(updateDoc(doc(orgDb, "organizations", ORG_VERIFIED), {
      groupLineUrl: lineUrl,
    }));
  }
});

test("[互換性4] レガシーフィールド（isReviewSeed等）や省略フィールド・nullを含む既存ドキュメントのupdateが通る", async () => {
  await seedHardeningFixtures();
  const legacyStudentUid = "legacy_seed_student";
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "users", legacyStudentUid), {
      isStudentVerified: true,
      isReviewSeed: true,
      createdAt: Timestamp.now(),
    });
  });

  await assertSucceeds(setDoc(
    doc(as(legacyStudentUid), "users", legacyStudentUid),
    { interests: ["カフェ巡り", "映画"] },
    { merge: true },
  ));
  await assertSucceeds(setDoc(
    doc(as(legacyStudentUid), "users", legacyStudentUid),
    {
      name: "佐藤 花子",
      faculty: "商学部",
      grade: 1,
      mainCampus: "imadegawa",
      iconUrl: VALID_STORAGE_USER_ICON,
      photoUrls: [],
    },
    { merge: true },
  ));

  // 団体名変更後に、旧団体名が記録された既存イベントを更新できること
  await assertSucceeds(updateDoc(doc(as(ORG_VERIFIED), "organizations", ORG_VERIFIED), {
    name: "改名後サークル",
  }));
  await assertSucceeds(updateDoc(doc(as(ORG_VERIFIED), "events", "upcoming_event_strict"), {
    organizationId: ORG_VERIFIED,
    organizationName: "承認済み団体",
    organizationEmoji: "🏀",
    organizationCategory: "すべて",
    title: "新歓バスケ体験会（場所変更）",
    description: "第2体育館に変更になりました",
    startAt: Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)),
    campus: "imadegawa",
    fee: "無料",
    capacity: "20名",
    location: "第2体育館",
    updatedAt: serverTimestamp(),
  }));
});

test("[互換性5] 認証済み学生・承認済み団体の通常フロー一式および最大件数境界値（興味20件＋写真4枚）が通る", async () => {
  await seedHardeningFixtures();
  const studentDb = as(STUDENT);
  const orgDb = as(ORG_VERIFIED);

  await assertSucceeds(getDoc(
    doc(studentDb, "events", "upcoming_event_strict", "applications", STUDENT),
  ));
  await assertSucceeds(setDoc(
    doc(studentDb, "events", "upcoming_event_strict", "applications", STUDENT),
    {
      studentId: STUDENT,
      studentName: "学生A",
      studentFaculty: "法学部",
      studentGrade: 2,
      studentIconUrl: VALID_STORAGE_USER_ICON,
      status: "applied",
      appliedAt: serverTimestamp(),
    },
  ));
  await assertSucceeds(updateDoc(
    doc(orgDb, "events", "upcoming_event_strict", "applications", STUDENT),
    {
      status: "accepted",
      respondedAt: serverTimestamp(),
    },
  ));

  await assertSucceeds(addDoc(collection(orgDb, "scouts"), {
    targetUserId: STUDENT,
    organizationId: ORG_VERIFIED,
    organizationName: "承認済み団体",
    organizationEmoji: "🏀",
    organizationCategory: "スポーツ",
    templateId: 1,
    templateArg: "新歓バスケ体験会",
    templateEventId: "upcoming_event_strict",
    isRead: false,
    readAt: null,
    sentAt: serverTimestamp(),
    organizationInstagramUrl: "@doshisha_bball",
    organizationLogoUrl: VALID_STORAGE_ORG_LOGO,
    targetUserIconUrl: VALID_STORAGE_USER_ICON,
    targetUserName: "学生A",
  }));

  await assertSucceeds(addDoc(collection(studentDb, "contacts"), {
    userId: STUDENT,
    category: "機能要望",
    message: "いつも便利に使っています。検索機能の改善を希望します。",
    status: "open",
    createdAt: serverTimestamp(),
  }));

  const twentyTags = Array.from({ length: 20 }, (_, i) => `興味タグ_${i + 1}`);
  const fourPhotos = Array.from(
    { length: 4 },
    (_, i) =>
      `https://firebasestorage.googleapis.com/v0/b/d-scout-6d281.firebasestorage.app/o/users%2F${STUDENT}%2Fphotos%2Fp${i}.jpg?alt=media&token=${i}`,
  );
  await assertSucceeds(updateDoc(doc(studentDb, "users", STUDENT), {
    name: "学生A",
    faculty: "法学部",
    grade: 2,
    mainCampus: "imadegawa",
    interests: twentyTags,
    iconUrl: VALID_STORAGE_USER_ICON,
    photoUrls: fourPhotos,
  }));
  await assertFails(updateDoc(doc(studentDb, "users", STUDENT), {
    interests: [...twentyTags.slice(0, 19), 999],
  }));
  await assertFails(updateDoc(doc(studentDb, "users", STUDENT), {
    interests: [...twentyTags, "21個目"],
  }));

  await assertSucceeds(addDoc(collection(orgDb, "reports"), {
    reporterId: ORG_VERIFIED,
    reporterRole: "organization",
    targetType: "user",
    targetId: STUDENT,
    targetName: "学生A",
    reason: "other",
    detail: "スナップショット最大負荷テスト",
    snapshot: {
      name: "学生A",
      faculty: "法学部",
      grade: 2,
      mainCampus: "今出川",
      interests: twentyTags,
      iconUrl: VALID_STORAGE_USER_ICON,
      photoUrls: fourPhotos,
    },
    status: "open",
    createdAt: serverTimestamp(),
  }));
});

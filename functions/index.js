const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const nodemailer = require("nodemailer");
const crypto = require("crypto");
const admin = require("firebase-admin");
const { Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");

admin.initializeApp();
const db = admin.firestore();

const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");

// 大学ドメインの許可パターン
const ALLOWED_DOMAIN_PATTERN = /^.+@(mail[1-9]?\.doshisha\.ac\.jp|dwc\.doshisha\.ac\.jp)$/;

// レート制限設定
const MAX_CODES_PER_HOUR = 3;
const CODE_EXPIRY_MINUTES = 30;
const MAX_VERIFY_ATTEMPTS = 5;

/**
 * SHA-256ハッシュを生成
 */
function hashCode(code) {
    return crypto.createHash("sha256").update(code).digest("hex");
}

/**
 * 6桁のランダム認証コードを生成
 */
function generateVerificationCode() {
    return crypto.randomInt(100000, 999999).toString();
}

/**
 * 学生認証コードを生成・保存・送信する Cloud Function
 * クライアントはメールアドレスのみ送信し、コードはサーバー側で生成
 */
exports.sendVerificationCode = onCall(
    { secrets: [SMTP_USER, SMTP_PASS] },
    async (request) => {
    // 認証済みかチェック
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
    }

    const { email } = request.data;
    if (!email) {
        throw new HttpsError("invalid-argument", "メールアドレスが必要です。");
    }

    // 大学ドメインチェック
    const normalizedEmail = email.trim().toLowerCase();
    if (!ALLOWED_DOMAIN_PATTERN.test(normalizedEmail)) {
        throw new HttpsError("invalid-argument", "許可されていないドメインです。");
    }

    const uid = request.auth.uid;
    const userRef = db.collection("users").doc(uid);
    // 認証メタデータ（大学メール・コード・レート制限）は団体に公開される
    // usersドキュメントではなく、クライアントから読めないprivateサブコレクションに保存
    const privateRef = userRef.collection("private").doc("verification");

    // レート制限チェック
    const privateDoc = await privateRef.get();
    if (privateDoc.exists) {
        const data = privateDoc.data();
        const lastSentAt = data.lastCodeSentAt?.toDate();
        const codeSentCount = data.codeSentCount || 0;
        const codeSentWindowStart = data.codeSentWindowStart?.toDate();

        if (codeSentWindowStart && lastSentAt) {
            const now = new Date();
            const hourAgo = new Date(now.getTime() - 60 * 60 * 1000);

            if (codeSentWindowStart > hourAgo && codeSentCount >= MAX_CODES_PER_HOUR) {
                throw new HttpsError(
                    "resource-exhausted",
                    `コード送信回数の上限に達しました。1時間に${MAX_CODES_PER_HOUR}回まで送信可能です。`,
                );
            }

            // ウィンドウが1時間経過していたらリセット
            if (codeSentWindowStart <= hourAgo) {
                // 下のupdateでリセットする
            }
        }
    }

    // コード生成 + ハッシュ化
    const code = generateVerificationCode();
    const hashedCode = hashCode(code);
    const now = new Date();
    const expiresAt = new Date(now.getTime() + CODE_EXPIRY_MINUTES * 60 * 1000);

    // 現在のウィンドウ情報を計算
    const existingData = privateDoc.exists ? privateDoc.data() : {};
    const existingWindowStart = existingData.codeSentWindowStart?.toDate();
    const hourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    const resetWindow = !existingWindowStart || existingWindowStart <= hourAgo;

    // privateサブコレクションにハッシュ化コード + メタデータを保存
    await privateRef.set({
        codeHashedValue: hashedCode,
        universityEmail: normalizedEmail,
        codeExpiresAt: Timestamp.fromDate(expiresAt),
        verificationAttempts: 0,
        lastCodeSentAt: FieldValue.serverTimestamp(),
        codeSentCount: resetWindow ? 1 : FieldValue.increment(1),
        codeSentWindowStart: resetWindow
            ? FieldValue.serverTimestamp()
            : existingData.codeSentWindowStart,
    }, { merge: true });

    // usersドキュメント側は認証フラグのみ管理
    await userRef.set({ isStudentVerified: false }, { merge: true });

    // エミュレーター環境ではメール送信をスキップ
    if (process.env.FUNCTIONS_EMULATOR === "true") {
        logger.info(`[MOCK] Verification code ${code} pseudo-sent to ${normalizedEmail}`);
        return { success: true };
    }

    // メール送信
    const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
            user: SMTP_USER.value(),
            pass: SMTP_PASS.value(),
        },
    });

    const mailOptions = {
        from: `"D.scout 運営" <${SMTP_USER.value()}>`,
        to: normalizedEmail,
        subject: "【D-Hub】学生認証コードのお知らせ",
        text: `D-Hub をご利用いただきありがとうございます。\n\n以下の6桁の認証コードをアプリに入力して、学生認証を完了してください。\n\n認証コード: ${code}\n\n※このコードの有効期限は${CODE_EXPIRY_MINUTES}分です。\n※心当たりがない場合は、このメールを破棄してください。`,
        html: `
        <div style="font-family: sans-serif; color: #333;">
            <h2>D-Hub 学生認証</h2>
            <p>D-Hub をご利用いただきありがとうございます。</p>
            <p>以下の6桁の認証コードをアプリに入力して、学生認証を完了してください。</p>
            <div style="padding: 16px; background-color: #f4f4f4; border-radius: 8px; font-size: 24px; font-weight: bold; letter-spacing: 4px; text-align: center;">
                ${code}
            </div>
            <p style="color: #666; font-size: 12px; margin-top: 24px;">
                ※このコードの有効期限は${CODE_EXPIRY_MINUTES}分です。<br>
                ※心当たりがない場合は、このメールを破棄してください。
            </p>
        </div>
        `,
    };

    try {
        await transporter.sendMail(mailOptions);
        logger.info(`Verification code sent to ${normalizedEmail}`);
        return { success: true };
    } catch (error) {
        logger.error(`Failed to send email to ${normalizedEmail}`, error);
        throw new HttpsError("internal", "メールの送信に失敗しました。");
    }
});

/**
 * 認証コードを検証する Cloud Function
 * ブルートフォース対策: 最大5回まで試行可能
 */
exports.verifyCode = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
    }

    const { code } = request.data;
    if (!code || typeof code !== "string" || code.length !== 6) {
        throw new HttpsError("invalid-argument", "6桁の認証コードを入力してください。");
    }

    const uid = request.auth.uid;
    const userRef = db.collection("users").doc(uid);
    const privateRef = userRef.collection("private").doc("verification");

    // トランザクションで試行回数チェック + 検証をアトミックに実行
    const result = await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
            throw new HttpsError("not-found", "ユーザー情報が見つかりません。");
        }
        const privateDoc = await transaction.get(privateRef);
        if (!privateDoc.exists) {
            throw new HttpsError("failed-precondition", "認証コードが送信されていません。");
        }

        const data = privateDoc.data();
        const hashedCode = data.codeHashedValue;
        const expiresAt = data.codeExpiresAt?.toDate();
        const attempts = data.verificationAttempts || 0;

        // 試行回数チェック
        if (attempts >= MAX_VERIFY_ATTEMPTS) {
            throw new HttpsError(
                "resource-exhausted",
                `認証コードの試行回数上限（${MAX_VERIFY_ATTEMPTS}回）に達しました。\n新しいコードを送信してください。`,
            );
        }

        // 有効期限チェック
        if (!expiresAt || new Date() > expiresAt) {
            throw new HttpsError(
                "deadline-exceeded",
                "確認コードの有効期限が切れました。\n再度コードを送信してください。",
            );
        }

        // コードが未設定の場合
        if (!hashedCode) {
            throw new HttpsError("failed-precondition", "認証コードが送信されていません。");
        }

        // ハッシュ比較
        const inputHashed = hashCode(code.trim());
        if (inputHashed !== hashedCode) {
            // 試行回数をインクリメント
            transaction.update(privateRef, {
                verificationAttempts: attempts + 1,
            });
            return {
                success: false,
                message: `確認コードが一致しません（残り${MAX_VERIFY_ATTEMPTS - attempts - 1}回）`,
            };
        }

        // 認証成功: isStudentVerified = true に更新 + コード関連フィールド削除
        // universityEmail は監査用にprivate側へ残す
        transaction.update(userRef, {
            isStudentVerified: true,
            verifiedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(privateRef, {
            codeHashedValue: FieldValue.delete(),
            codeExpiresAt: FieldValue.delete(),
            verificationAttempts: FieldValue.delete(),
            codeSentCount: FieldValue.delete(),
            codeSentWindowStart: FieldValue.delete(),
            lastCodeSentAt: FieldValue.delete(),
        });

        return { success: true, message: "学生認証が完了しました！" };
    });

    return result;
});

/**
 * 退会（アカウント削除）を行う Cloud Function
 *
 * 規約第14条2「登録データは削除されます」を実際に満たすため、クライアントからの
 * 逐次削除ではなくサーバー側（Admin SDK）で一括削除する。
 *
 * クライアントでは消しきれない理由:
 *  - 学生は自分の申し込み（events/{id}/applications）を列挙できない。
 *    list ルールは主催団体のみに許可されており、collectionGroup も張っていない
 *  - Storage は delete が許可されておらず、storage_service に削除メソッド自体が無い
 *  - 逐次削除は best-effort で、途中で失敗すると Auth ユーザーだけ消えて
 *    本人も管理者も再試行できない孤児データが残る
 *
 * あえて消さないもの: reports / contacts
 *   通報・問い合わせは運営の対応記録（規約第7条）で、通報者保護のためにも
 *   被通報者の退会で消えてはいけない。本人の識別情報ではなく事案の記録として保持する。
 *
 * ⚠️ 削除順序は「権限の失効が先、他人所有データの削除は後」で固定すること。
 *   理由はフェーズ1のコメントを参照。逆にすると権限昇格の窓が開く。
 */
const RECENT_AUTH_WINDOW_SECONDS = 10 * 60;

// 自団体イベントの削除を流す同時実行数。1件ずつ await すると実行時間が
// イベント件数に比例し、タイムアウトまでの余裕を呼び出し元が決められてしまう。
const EVENT_DELETE_CONCURRENCY = 20;

exports.deleteMyAccount = onCall({ timeoutSeconds: 540 }, async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
    }

    const uid = request.auth.uid;

    // 不可逆な操作なので直近の再認証を必須にする。ID トークンが漏れただけで
    // アカウントを消されないようにするため。
    // クライアントは reauthenticateWithCredential の後に getIdToken(true) で
    // トークンを更新してから呼ぶこと（auth_time が更新されない）。
    const authTime = request.auth.token.auth_time;
    const nowSeconds = Math.floor(Date.now() / 1000);
    if (typeof authTime !== "number" ||
        nowSeconds - authTime > RECENT_AUTH_WINDOW_SECONDS) {
        throw new HttpsError(
            "failed-precondition",
            "セキュリティのため、パスワードを再入力してからやり直してください。",
        );
    }

    // ══ フェーズ1: 権限の失効（必ず最初にやる） ══
    //
    // ルールの認可はすべて users/{uid} と organizations/{uid} を get() して
    // 判定しているので、この2つを消した時点で参照先が失われ、以降どのルールも
    // fail-closed になる（isVerifiedOrg() など）。
    //
    // ⚠️ これをフェーズ2より後ろに動かしてはいけない。
    // フェーズ2では「他人が所有する」users/{他人}/blocks/{uid} を消すが、
    // isNotBlockedByTarget()（firestore.rules）はルール中で唯一の否定存在チェック
    // （!exists）で、参照先が消えると deny ではなく allow に反転する。
    // つまりブロック記録の削除はスカウト送信権限を「与える」操作である。
    // 権限を残したままこれを先に消すと、途中で関数が落ちたときに
    // 「自分をブロックしていた学生全員のブロックが解除され、団体としては
    // 有効なまま」という状態が生まれ、ブロックを踏み越えて再送できてしまう。
    // 実行時間はイベント件数などで呼び出し元が引き延ばせるため、これは
    // 偶発的な競合ではなく狙って作れる状態だった。
    await db.recursiveDelete(db.collection("organizations").doc(uid));
    await db.recursiveDelete(db.collection("users").doc(uid));
    await getAuth().revokeRefreshTokens(uid);

    // ══ フェーズ2: 残りのデータ ══
    // ここから先で失敗しても、呼び出し元はもう何の権限も持たない。
    // この関数は冪等なので、再ログインしてもう一度呼べば続きから掃除できる。

    // 個別の削除失敗で全体を止めず、最後にまとめて成否を判断する
    let failedDeletes = 0;
    const bulkWriter = db.bulkWriter();
    bulkWriter.onWriteError((error) => {
        if (error.failedAttempts < 3) return true;
        failedDeletes++;
        logger.error(`Delete failed: ${error.documentRef.path}`, error);
        return false;
    });

    // ── スカウト（学生として受け取った分・団体として送った分の両方） ──
    for (const field of ["targetUserId", "organizationId"]) {
        const snap = await db.collection("scouts").where(field, "==", uid).get();
        snap.docs.forEach((doc) => bulkWriter.delete(doc.ref));
    }

    // ── 学生として出したイベント申し込み ──
    // collectionGroup クエリなので firestore.indexes.json の fieldOverrides が必要
    const myApplications = await db
        .collectionGroup("applications")
        .where("studentId", "==", uid)
        .get();
    myApplications.docs.forEach((doc) => bulkWriter.delete(doc.ref));

    // ── 自団体のイベント（applications サブコレクションごと消す） ──
    // BulkWriter を共有すると recursiveDelete はそれを close せずに使うので、
    // まとめて並列に流せる。同時実行数は絞ってメモリと接続数を抑える。
    const ownedEvents = await db
        .collection("events")
        .where("organizationId", "==", uid)
        .get();
    for (let i = 0; i < ownedEvents.docs.length; i += EVENT_DELETE_CONCURRENCY) {
        const chunk = ownedEvents.docs.slice(i, i + EVENT_DELETE_CONCURRENCY);
        await Promise.all(chunk.map((doc) => db.recursiveDelete(doc.ref, bulkWriter)));
    }

    // ── 他人が自分をブロックしている側の記録 ──
    // blocks は「ドキュメントIDがブロック相手のUID」かつ targetName（＝相手の氏名）を
    // 持つため、消さないと退会者の氏名が他人のサブコレクションに残る。
    // ドキュメントIDでの collectionGroup 絞り込みができないので全件走査する。
    // ブロックは件数が少なく現在の規模では許容範囲（将来 targetId フィールドを
    // 持たせればインデックス付きクエリにできる）。
    // フェーズ1で権限を失効させた後なので、ここで消しても何も復活しない。
    const allBlocks = await db.collectionGroup("blocks").get();
    allBlocks.docs
        .filter((doc) => doc.id === uid)
        .forEach((doc) => bulkWriter.delete(doc.ref));

    await bulkWriter.close();

    // ── Storage の画像 ──
    // アイコン・プロフィール写真・団体ロゴ／活動写真。差し替えで残っていた
    // 古いファイルも prefix ごと消えるので、ここで一掃される。
    const bucket = getStorage().bucket();
    for (const prefix of [`users/${uid}/`, `organizations/${uid}/`]) {
        try {
            await bucket.deleteFiles({ prefix });
        } catch (error) {
            failedDeletes++;
            logger.error(`Storage delete failed: ${prefix}`, error);
        }
    }

    // ── Auth ユーザー ──
    // 最後に消す。先に消すと、途中で失敗したときに本人が再ログインして
    // やり直すことすらできなくなるため。
    // 「権限を持ったまま生き残る」危険はフェーズ1で潰してあるので、
    // ここまで引っ張っても安全。この時点の呼び出し元は認可上ただの匿名ユーザー。
    if (failedDeletes > 0) {
        logger.error(`deleteMyAccount incomplete: uid=${uid} failures=${failedDeletes}`);
        throw new HttpsError(
            "internal",
            "データの削除に失敗しました。時間をおいて再度お試しください。",
        );
    }

    await getAuth().deleteUser(uid);
    logger.info(`Account fully deleted: uid=${uid}`);
    return { success: true };
});

/**
 * ユーザーのFirebase Authアカウントを削除する Cloud Function
 * 管理者のみが実行可能
 */
exports.deleteAuthUser = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
    }
    if (!request.auth.token.admin) {
        throw new HttpsError("permission-denied", "管理者権限が必要です。");
    }

    const { uid } = request.data;
    if (!uid || typeof uid !== "string" || uid.trim().length === 0) {
        throw new HttpsError("invalid-argument", "対象ユーザーのUIDが必要です。");
    }

    await getAuth().deleteUser(uid.trim());
    logger.info(`Auth user deleted: uid=${uid} by admin=${request.auth.uid}`);
    return { success: true };
});

/**
 * 管理者カスタムクレームを付与する Cloud Function
 * 既存の管理者のみが他ユーザーに管理者権限を付与できる
 */
exports.setAdminClaim = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
    }
    if (!request.auth.token.admin) {
        throw new HttpsError("permission-denied", "管理者権限が必要です。");
    }

    const { uid } = request.data;
    if (!uid || typeof uid !== "string" || uid.trim().length === 0) {
        throw new HttpsError("invalid-argument", "対象ユーザーのUIDが必要です。");
    }

    await getAuth().setCustomUserClaims(uid.trim(), { admin: true });
    logger.info(`Admin claim granted to uid: ${uid} by admin: ${request.auth.uid}`);
    return { success: true };
});

/**
 * 管理者カスタムクレームを剥奪する Cloud Function
 * 既存の管理者のみが実行可能
 */
exports.removeAdminClaim = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
    }
    if (!request.auth.token.admin) {
        throw new HttpsError("permission-denied", "管理者権限が必要です。");
    }

    const { uid } = request.data;
    if (!uid || typeof uid !== "string" || uid.trim().length === 0) {
        throw new HttpsError("invalid-argument", "対象ユーザーのUIDが必要です。");
    }

    await getAuth().setCustomUserClaims(uid.trim(), { admin: false });
    logger.info(`Admin claim removed from uid: ${uid} by admin: ${request.auth.uid}`);
    return { success: true };
});

const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
    onDocumentCreated,
    onDocumentDeleted,
    onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const nodemailer = require("nodemailer");
const crypto = require("crypto");
const admin = require("firebase-admin");
const { Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");

if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();

// P0-3: 大量アクセス時の無制限スケールアウトによる課金爆発を防ぐ全体上限
// ※クライアント側はリージョン未指定（デフォルト us-central1）で呼び出すため region は変更しない
setGlobalOptions({ maxInstances: 10 });

const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");

// P0-1: 大学ドメインの厳格な許可パターン
// カンマ・空白・引用符等を一切禁止し、Nodemailerの複数宛先解釈による外部メール相乗りを防止する。
// また mail10 等の2桁サブドメインもクライアント側（auth_service.dart）と一致させて許可する。
const ALLOWED_DOMAIN_PATTERN =
    /^[a-z0-9._%+-]+@(mail\d*\.doshisha\.ac\.jp|dwc\.doshisha\.ac\.jp)$/;

// レート制限・認証・削除制御設定
const MAX_CODES_PER_HOUR = 3;
const CODE_EXPIRY_MINUTES = 30;
const MAX_VERIFY_ATTEMPTS = 5;
const RECENT_AUTH_WINDOW_SECONDS = 10 * 60;
const EVENT_DELETE_CONCURRENCY = 20;
const SELF_DELETE_MARKER_COLLECTION = "_account_deletions";
const SELF_DELETE_MARKER_TTL_MS = 10 * 60 * 1000;

// 運営通知メールのグローバル流量制限（学生認証コード用SMTPクォータを圧迫しないための上限）
const ADMIN_ALERT_RATE_LIMIT_COLLECTION = "_admin_alert_rate_limits";
const ADMIN_ALERT_RATE_LIMIT_DOC_ID = "global";
const MAX_ADMIN_ALERT_EMAILS_PER_HOUR = 5;
const MAX_ADMIN_ALERT_EMAILS_PER_DAY = 20;
const ONE_HOUR_MS = 60 * 60 * 1000;
const ONE_DAY_MS = 24 * 60 * 60 * 1000;

/**
 * SHA-256ハッシュを生成する
 * @param {string} value ハッシュ化対象の文字列
 * @return {string} 16進数ハッシュ文字列
 */
function hashValue(value) {
    return crypto.createHash("sha256").update(value).digest("hex");
}

/**
 * 6桁のランダム認証コードを生成する
 * @return {string} 100000〜999999 の6桁文字列
 */
function generateVerificationCode() {
    return crypto.randomInt(100000, 1000000).toString();
}

/**
 * Cloud Logging への個人情報（学籍番号を含む大学メール）平文記録を防ぐマスク関数
 * @param {string} email メールアドレス
 * @return {string} マスク済みメールアドレス
 */
function maskEmail(email) {
    if (typeof email !== "string" || !email.includes("@")) return "***";
    const [local, domain] = email.split("@");
    const visible = local.slice(0, Math.min(2, local.length));
    return `${visible}***@${domain}`;
}

/**
 * メール件名などの単一行フィールド向けに改行コードを除去する
 * @param {unknown} input 任意の入力値
 * @return {string} 単一行に正規化された文字列
 */
function sanitizeSingleLine(input) {
    return String(input ?? "")
        .replace(/[\r\n]+/g, " ")
        .trim();
}

/**
 * メール本文（HTML）へのユーザー入力埋め込み時のHTMLエスケープ
 * @param {unknown} input 任意の入力値
 * @return {string} エスケープ済み文字列
 */
function escapeHtml(input) {
    const str = String(input ?? "");
    return str
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

/**
 * Gmail SMTP トランスポーターを生成する
 * @return {import("nodemailer").Transporter} Nodemailerトランスポーター
 */
function createSmtpTransporter() {
    return nodemailer.createTransport({
        service: "gmail",
        auth: {
            user: SMTP_USER.value(),
            pass: SMTP_PASS.value(),
        },
    });
}

/**
 * 大学メール一意性ロックを安全に解除する（該当UIDが保持している場合のみ）
 * @param {string} uid 削除対象のユーザーUID
 * @param {string|undefined} universityEmail 登録されていた大学メール
 */
async function releaseUniversityEmailLock(uid, universityEmail) {
    if (!universityEmail || typeof universityEmail !== "string") return;
    const normalized = universityEmail.trim().toLowerCase();
    if (!normalized) return;

    const lockRef = db.collection("university_email_locks").doc(hashValue(normalized));
    await db.runTransaction(async (tx) => {
        const lockDoc = await tx.get(lockRef);
        if (lockDoc.exists && lockDoc.data()?.uid === uid) {
            tx.delete(lockRef);
        }
    });
}

/**
 * Firebase Auth ユーザーを冪等に削除する（既に削除済みの場合は無視）
 * @param {string} uid 対象UID
 */
async function deleteAuthUserIdempotent(uid) {
    try {
        await getAuth().deleteUser(uid);
    } catch (error) {
        if (error.code !== "auth/user-not-found") {
            throw error;
        }
    }
}

/**
 * 本人退会（deleteMyAccount）による削除処理中マーカーを確認・消費する。
 * deleteMyAccount が進行中（または完了直後）の場合は削除トリガー側の重複フルスキャン・
 * Storage並列削除競合・先回りAuth削除を抑止するために true を返す。
 * @param {string} uid 対象UID
 * @param {"pendingOrgTrigger"|"pendingUserTrigger"} triggerField 消費するトリガー種別フィールド
 * @return {Promise<boolean>} 本人退会処理の一部であるためトリガー側をスキップすべきなら true
 */
async function consumeSelfDeleteTriggerMarker(uid, triggerField) {
    const markerRef = db.collection(SELF_DELETE_MARKER_COLLECTION).doc(uid);
    return db.runTransaction(async (tx) => {
        const snap = await tx.get(markerRef);
        if (!snap.exists) return false;

        const data = snap.data() || {};
        const nowMs = Date.now();
        if (typeof data.expiresAtMs !== "number" || data.expiresAtMs <= nowMs) {
            tx.delete(markerRef);
            return false;
        }

        const nextOrg =
            triggerField === "pendingOrgTrigger"
                ? false
                : Boolean(data.pendingOrgTrigger);
        const nextUser =
            triggerField === "pendingUserTrigger"
                ? false
                : Boolean(data.pendingUserTrigger);

        if (data.selfDeleteCompleted === true && !nextOrg && !nextUser) {
            tx.delete(markerRef);
        } else {
            tx.update(markerRef, {
                pendingOrgTrigger: nextOrg,
                pendingUserTrigger: nextUser,
            });
        }
        return true;
    });
}

/**
 * 学生認証コードを生成・保存・送信する Cloud Function
 * - P0-1: 正規表現厳格化・ログインメール一致検証・団体アカウント拒否・重複大学メール防止
 * - P2-2: Firestoreトランザクションによるアトミックなレート制限（並列呼び出し突破の防止）・ログマスク
 */
exports.sendVerificationCode = onCall(
    { secrets: [SMTP_USER, SMTP_PASS], maxInstances: 5 },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "ログインが必要です。");
        }

        const { email } = request.data || {};
        if (!email || typeof email !== "string") {
            throw new HttpsError("invalid-argument", "メールアドレスが必要です。");
        }

        const normalizedEmail = email.trim().toLowerCase();
        if (
            normalizedEmail.length > 254 ||
            !ALLOWED_DOMAIN_PATTERN.test(normalizedEmail)
        ) {
            throw new HttpsError("invalid-argument", "許可されていないドメインです。");
        }

        const uid = request.auth.uid;

        // Firebase Auth の最新ユーザーレコード（取得失敗時はトークン）から現在のメールを確認し、
        // 送信先大学メールとの完全一致を強制する（嫌がらせメール爆撃・相乗り・メールすり替えを遮断）
        const userRecord = await getAuth().getUser(uid);
        const authEmail = userRecord.email || request.auth.token.email;
        if (!authEmail || authEmail.trim().toLowerCase() !== normalizedEmail) {
            throw new HttpsError(
                "permission-denied",
                "ログイン中のメールアドレスと一致しません。",
            );
        }

        const orgRef = db.collection("organizations").doc(uid);
        const userRef = db.collection("users").doc(uid);
        const privateRef = userRef.collection("private").doc("verification");
        const emailLockRef = db
            .collection("university_email_locks")
            .doc(hashValue(normalizedEmail));

        // レート制限・重複確認・コード保存を単一トランザクションでアトミックに実行（TOCTOU対策）
        const code = await db.runTransaction(async (transaction) => {
            const [orgDoc, userDoc, privateDoc, emailLockDoc] = await Promise.all([
                transaction.get(orgRef),
                transaction.get(userRef),
                transaction.get(privateRef),
                transaction.get(emailLockRef),
            ]);

            if (orgDoc.exists) {
                throw new HttpsError(
                    "failed-precondition",
                    "団体アカウントでは学生認証を行えません。",
                );
            }

            if (userDoc.exists && userDoc.data()?.isStudentVerified === true) {
                throw new HttpsError(
                    "already-exists",
                    "すでに学生認証が完了しています。",
                );
            }

            // 同一大学メールが別UIDで認証済みでないか確認（複数アカウント量産・BAN逃れ防止）
            if (emailLockDoc.exists) {
                const lockedUid = emailLockDoc.data()?.uid;
                if (lockedUid && lockedUid !== uid) {
                    const lockedUserDoc = await transaction.get(
                        db.collection("users").doc(lockedUid),
                    );
                    if (
                        lockedUserDoc.exists &&
                        lockedUserDoc.data()?.isStudentVerified === true
                    ) {
                        throw new HttpsError(
                            "already-exists",
                            "この大学メールアドレスは既に別のアカウントで使用されています。",
                        );
                    }
                }
            }

            const now = new Date();
            const hourAgo = new Date(now.getTime() - 60 * 60 * 1000);
            const existingData = privateDoc.exists ? privateDoc.data() : {};
            const existingWindowStart = existingData.codeSentWindowStart?.toDate();
            const existingCount = existingData.codeSentCount || 0;

            const isWithinWindow =
                existingWindowStart && existingWindowStart > hourAgo;
            if (isWithinWindow && existingCount >= MAX_CODES_PER_HOUR) {
                throw new HttpsError(
                    "resource-exhausted",
                    `コード送信回数の上限に達しました。1時間に${MAX_CODES_PER_HOUR}回まで送信可能です。`,
                );
            }

            const generatedCode = generateVerificationCode();
            const hashedCode = hashValue(generatedCode);
            const expiresAt = new Date(
                now.getTime() + CODE_EXPIRY_MINUTES * 60 * 1000,
            );

            transaction.set(
                privateRef,
                {
                    codeHashedValue: hashedCode,
                    universityEmail: normalizedEmail,
                    codeExpiresAt: Timestamp.fromDate(expiresAt),
                    verificationAttempts: 0,
                    lastCodeSentAt: FieldValue.serverTimestamp(),
                    codeSentCount: isWithinWindow ? existingCount + 1 : 1,
                    codeSentWindowStart: isWithinWindow
                        ? existingData.codeSentWindowStart
                        : FieldValue.serverTimestamp(),
                },
                { merge: true },
            );

            if (!userDoc.exists) {
                transaction.set(
                    userRef,
                    {
                        isStudentVerified: false,
                        createdAt: FieldValue.serverTimestamp(),
                    },
                    { merge: true },
                );
            } else {
                transaction.set(
                    userRef,
                    { isStudentVerified: false },
                    { merge: true },
                );
            }

            return generatedCode;
        });

        // エミュレータ環境では外部メール送信をスキップ
        if (process.env.FUNCTIONS_EMULATOR === "true") {
            logger.info(
                `[MOCK] Verification code pseudo-sent for uid=${uid} (${maskEmail(normalizedEmail)})`,
            );
            return { success: true };
        }

        const transporter = createSmtpTransporter();
        const mailOptions = {
            from: `"D-Hub 運営" <${SMTP_USER.value()}>`,
            to: normalizedEmail,
            subject: "【D-Hub】学生認証コードのお知らせ",
            text: `D-Hub をご利用いただきありがとうございます。\n\n以下の6桁の認証コードをアプリに入力して、学生認証を完了してください。\n\n認証コード: ${code}\n\n※このコードの有効期限は${CODE_EXPIRY_MINUTES}分です。\n※心当たりがない場合は、このメールを破棄してください。`,
            html: `
        <div style="font-family: sans-serif; color: #333;">
            <h2>D-Hub 学生認証</h2>
            <p>D-Hub をご利用いただきありがとうございます。</p>
            <p>以下の6桁の認証コードをアプリに入力して、学生認証を完了してください。</p>
            <div style="padding: 16px; background-color: #f4f4f4; border-radius: 8px; font-size: 24px; font-weight: bold; letter-spacing: 4px; text-align: center;">
                ${escapeHtml(code)}
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
            logger.info(
                `Verification code sent: uid=${uid} to=${maskEmail(normalizedEmail)}`,
            );
            return { success: true };
        } catch (error) {
            logger.error(
                `Failed to send verification email: uid=${uid} to=${maskEmail(normalizedEmail)}`,
                error,
            );
            throw new HttpsError("internal", "メールの送信に失敗しました。");
        }
    },
);

/**
 * 認証コードを検証する Cloud Function
 * - ブルートフォース対策: 最大5回まで試行可能
 * - P0-1: 最新Authメール一致検証・団体アカウント拒否・大学メール一意性ロックのアトミック取得
 * - P2-2: 認証成功時に送信レート制限カウンタ（codeSentCount等）を削除しない
 */
exports.verifyCode = onCall({ maxInstances: 5 }, async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
    }

    const { code } = request.data || {};
    if (!code || typeof code !== "string" || code.trim().length !== 6) {
        throw new HttpsError("invalid-argument", "6桁の認証コードを入力してください。");
    }

    const uid = request.auth.uid;

    // コード送信後に Firebase Auth REST API でメールアドレスを外部アドレスへすり替える攻撃を防止するため、
    // トークン内のキャッシュではなく Auth サーバー上の最新メールアドレスを取得して照合する
    const userRecord = await getAuth().getUser(uid);
    const currentAuthEmail = (userRecord.email || "").trim().toLowerCase();

    const orgRef = db.collection("organizations").doc(uid);
    const userRef = db.collection("users").doc(uid);
    const privateRef = userRef.collection("private").doc("verification");

    const result = await db.runTransaction(async (transaction) => {
        const [orgDoc, userDoc, privateDoc] = await Promise.all([
            transaction.get(orgRef),
            transaction.get(userRef),
            transaction.get(privateRef),
        ]);

        if (orgDoc.exists) {
            throw new HttpsError(
                "failed-precondition",
                "団体アカウントでは学生認証を行えません。",
            );
        }
        if (!userDoc.exists) {
            throw new HttpsError("not-found", "ユーザー情報が見つかりません。");
        }
        if (!privateDoc.exists) {
            throw new HttpsError("failed-precondition", "認証コードが送信されていません。");
        }

        const data = privateDoc.data();
        const hashedCode = data.codeHashedValue;
        const universityEmail =
            typeof data.universityEmail === "string"
                ? data.universityEmail.trim().toLowerCase()
                : "";
        const expiresAt = data.codeExpiresAt?.toDate();
        const attempts = data.verificationAttempts || 0;

        if (!universityEmail || !ALLOWED_DOMAIN_PATTERN.test(universityEmail)) {
            throw new HttpsError(
                "failed-precondition",
                "有効な大学メールアドレスが確認できません。",
            );
        }

        if (!currentAuthEmail || currentAuthEmail !== universityEmail) {
            throw new HttpsError(
                "permission-denied",
                "ログイン中のメールアドレスが確認コード送信先と一致しません。",
            );
        }

        if (userDoc.data()?.isStudentVerified === true) {
            return { success: true, message: "学生認証が完了しました！" };
        }

        if (attempts >= MAX_VERIFY_ATTEMPTS) {
            throw new HttpsError(
                "resource-exhausted",
                `認証コードの試行回数上限（${MAX_VERIFY_ATTEMPTS}回）に達しました。\n新しいコードを送信してください。`,
            );
        }

        if (!expiresAt || new Date() > expiresAt) {
            throw new HttpsError(
                "deadline-exceeded",
                "確認コードの有効期限が切れました。\n再度コードを送信してください。",
            );
        }

        if (!hashedCode || typeof hashedCode !== "string") {
            throw new HttpsError("failed-precondition", "認証コードが送信されていません。");
        }

        const emailLockRef = db
            .collection("university_email_locks")
            .doc(hashValue(universityEmail));
        const emailLockDoc = await transaction.get(emailLockRef);
        if (emailLockDoc.exists) {
            const lockedUid = emailLockDoc.data()?.uid;
            if (lockedUid && lockedUid !== uid) {
                const lockedUserDoc = await transaction.get(
                    db.collection("users").doc(lockedUid),
                );
                if (
                    lockedUserDoc.exists &&
                    lockedUserDoc.data()?.isStudentVerified === true
                ) {
                    throw new HttpsError(
                        "already-exists",
                        "この大学メールアドレスは既に別のアカウントで使用されています。",
                    );
                }
            }
        }

        // 定数時間比較でハッシュを検証（非16進文字列混入時のバイト長不一致例外も防御）
        const inputHashed = hashValue(code.trim());
        const inputBuf = Buffer.from(inputHashed, "hex");
        const storedBuf = Buffer.from(hashedCode, "hex");
        const isMatch =
            inputBuf.length === 32 &&
            inputBuf.length === storedBuf.length &&
            crypto.timingSafeEqual(inputBuf, storedBuf);

        if (!isMatch) {
            transaction.update(privateRef, {
                verificationAttempts: attempts + 1,
            });
            return {
                success: false,
                message: `確認コードが一致しません（残り${MAX_VERIFY_ATTEMPTS - attempts - 1}回）`,
            };
        }

        // 認証成功: isStudentVerified = true に更新し、一意性ロックを記録する。
        // P2-2対策: codeSentCount / codeSentWindowStart / lastCodeSentAt は保持し、
        // 認証成功によって送信レート制限がリセットされないようにする。
        transaction.update(userRef, {
            isStudentVerified: true,
            verifiedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(privateRef, {
            codeHashedValue: FieldValue.delete(),
            codeExpiresAt: FieldValue.delete(),
            verificationAttempts: FieldValue.delete(),
        });
        transaction.set(emailLockRef, {
            uid,
            verifiedAt: FieldValue.serverTimestamp(),
        });

        return { success: true, message: "学生認証が完了しました！" };
    });

    return result;
});

/**
 * 指定UIDに紐づく関連データ（スカウト・イベント申込・主催イベント・ブロック・Storage）を一括削除する共通関数
 * 本人退会（deleteMyAccount）および管理画面からのアカウント削除トリガーで共用する
 * @param {string} uid 削除対象のUID
 * @param {{ cleanStudentData: boolean, cleanOrgData: boolean }} options 削除対象種別
 * @return {Promise<number>} 削除失敗件数
 */
async function cleanupRelatedAccountData(uid, { cleanStudentData, cleanOrgData }) {
    let failedDeletes = 0;
    const bulkWriter = db.bulkWriter();
    bulkWriter.onWriteError((error) => {
        if (error.failedAttempts < 3) return true;
        failedDeletes++;
        logger.error(`Delete failed: ${error.documentRef.path}`, error);
        return false;
    });

    if (cleanStudentData) {
        const receivedScouts = await db
            .collection("scouts")
            .where("targetUserId", "==", uid)
            .get();
        receivedScouts.docs.forEach((d) => bulkWriter.delete(d.ref));

        const myApplications = await db
            .collectionGroup("applications")
            .where("studentId", "==", uid)
            .get();
        myApplications.docs.forEach((d) => bulkWriter.delete(d.ref));
    }

    if (cleanOrgData) {
        const sentScouts = await db
            .collection("scouts")
            .where("organizationId", "==", uid)
            .get();
        sentScouts.docs.forEach((d) => bulkWriter.delete(d.ref));

        const ownedEvents = await db
            .collection("events")
            .where("organizationId", "==", uid)
            .get();
        for (let i = 0; i < ownedEvents.docs.length; i += EVENT_DELETE_CONCURRENCY) {
            const chunk = ownedEvents.docs.slice(i, i + EVENT_DELETE_CONCURRENCY);
            await Promise.all(
                chunk.map((d) => db.recursiveDelete(d.ref, bulkWriter)),
            );
        }
    }

    // 他人が対象UIDをブロックしている記録の削除
    // ※select() でドキュメント本体の転送量は削減されるが、課金される読み取り回数は減らない点に留意（現規模では許容範囲）
    const allBlocks = await db.collectionGroup("blocks").select().get();
    allBlocks.docs
        .filter((d) => d.id === uid)
        .forEach((d) => bulkWriter.delete(d.ref));

    await bulkWriter.close();

    // Storage 画像の一括削除（force: true および 404 無視で冪等性を担保）
    // ※ADC 未設定のオフラインエミュレータ環境ではデフォルトバケットが <projectId>.appspot.com に
    //   フォールバックするため、エミュレータ実行時は .firebasestorage.app バケットも併せて削除対象にする
    const prefixes = [];
    if (cleanStudentData) prefixes.push(`users/${uid}/`);
    if (cleanOrgData) prefixes.push(`organizations/${uid}/`);

    const storage = getStorage();
    const defaultBucket = storage.bucket();
    const targetBuckets = [defaultBucket];
    if (
        process.env.FUNCTIONS_EMULATOR === "true" &&
        process.env.GCLOUD_PROJECT &&
        defaultBucket.name !== `${process.env.GCLOUD_PROJECT}.firebasestorage.app`
    ) {
        targetBuckets.push(
            storage.bucket(`${process.env.GCLOUD_PROJECT}.firebasestorage.app`),
        );
    }

    for (const bucket of targetBuckets) {
        for (const prefix of prefixes) {
            try {
                await bucket.deleteFiles({ prefix, force: true });
            } catch (error) {
                const errors = Array.isArray(error) ? error : [error];
                const nonNotFound = errors.filter(
                    (e) => e && e.code !== 404 && e.code !== "404",
                );
                if (nonNotFound.length > 0) {
                    failedDeletes++;
                    logger.error(
                        `Storage delete failed: bucket=${bucket.name} prefix=${prefix}`,
                        error,
                    );
                }
            }
        }
    }

    return failedDeletes;
}

/**
 * 退会（アカウント削除）を行う Cloud Function
 * ⚠️ 削除順序は「権限の失効（organizations / users 削除＋トークン失効）が先、他人所有データの削除は後」を厳守
 */
exports.deleteMyAccount = onCall(
    { timeoutSeconds: 180, maxInstances: 5 },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "ログインが必要です。");
        }

        const uid = request.auth.uid;

        const authTime = request.auth.token.auth_time;
        const nowSeconds = Math.floor(Date.now() / 1000);
        if (
            typeof authTime !== "number" ||
            nowSeconds - authTime > RECENT_AUTH_WINDOW_SECONDS
        ) {
            throw new HttpsError(
                "failed-precondition",
                "セキュリティのため、パスワードを再入力してからやり直してください。",
            );
        }

        const orgRef = db.collection("organizations").doc(uid);
        const userRef = db.collection("users").doc(uid);
        const privateRef = userRef.collection("private").doc("verification");
        const deletionMarkerRef = db
            .collection(SELF_DELETE_MARKER_COLLECTION)
            .doc(uid);

        // 削除対象の存在確認と大学メール取得を事前実行し、削除トリガーとの二重実行防止マーカーを記録する
        const [orgSnap, userSnap, privateSnap] = await Promise.all([
            orgRef.get(),
            userRef.get(),
            privateRef.get(),
        ]);
        const hasOrgDoc = orgSnap.exists;
        const hasUserDoc = userSnap.exists;
        const universityEmail = privateSnap.data()?.universityEmail;

        if (hasOrgDoc || hasUserDoc) {
            await deletionMarkerRef.set({
                mode: "self",
                pendingOrgTrigger: hasOrgDoc,
                pendingUserTrigger: hasUserDoc,
                selfDeleteCompleted: false,
                expiresAtMs: Date.now() + SELF_DELETE_MARKER_TTL_MS,
                startedAt: FieldValue.serverTimestamp(),
            });
        }

        try {
            // ══ フェーズ1: 権限の失効（必ず最初に実行） ══
            await db.recursiveDelete(orgRef);
            await db.recursiveDelete(userRef);
            try {
                await getAuth().revokeRefreshTokens(uid);
            } catch (error) {
                if (error.code !== "auth/user-not-found") {
                    throw error;
                }
            }

            await releaseUniversityEmailLock(uid, universityEmail);

            // ══ フェーズ2: 残りの関連データ削除 ══
            const failedDeletes = await cleanupRelatedAccountData(uid, {
                cleanStudentData: true,
                cleanOrgData: true,
            });

            if (failedDeletes > 0) {
                logger.error(
                    `deleteMyAccount incomplete: uid=${uid} failures=${failedDeletes}`,
                );
                throw new HttpsError(
                    "internal",
                    "データの削除に失敗しました。時間をおいて再度お試しください。",
                );
            }

            await deleteAuthUserIdempotent(uid);

            // トリガー側が既にマーカーを消費済みなら即削除し、遅延発火待ちなら完了フラグを立ててトリガー側に削除を委ねる
            if (hasOrgDoc || hasUserDoc) {
                await db.runTransaction(async (tx) => {
                    const snap = await tx.get(deletionMarkerRef);
                    if (!snap.exists) return;
                    const d = snap.data() || {};
                    if (!d.pendingOrgTrigger && !d.pendingUserTrigger) {
                        tx.delete(deletionMarkerRef);
                    } else {
                        tx.update(deletionMarkerRef, { selfDeleteCompleted: true });
                    }
                });
            }

            logger.info(`Account fully deleted: uid=${uid}`);
            return { success: true };
        } catch (error) {
            await deletionMarkerRef.delete().catch(() => {});
            throw error;
        }
    },
);

/**
 * ユーザーのFirebase Authアカウントを削除する Cloud Function（管理者専用）
 */
exports.deleteAuthUser = onCall({ maxInstances: 5 }, async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
    }
    if (!request.auth.token.admin) {
        throw new HttpsError("permission-denied", "管理者権限が必要です。");
    }

    const { uid } = request.data || {};
    if (!uid || typeof uid !== "string" || uid.trim().length === 0) {
        throw new HttpsError("invalid-argument", "対象ユーザーのUIDが必要です。");
    }

    const targetUid = uid.trim();
    if (targetUid === request.auth.uid) {
        throw new HttpsError(
            "failed-precondition",
            "自分自身の管理者アカウントは削除できません。",
        );
    }

    await deleteAuthUserIdempotent(targetUid);
    logger.info(
        `Auth user deleted: uid=${targetUid} by admin=${request.auth.uid}`,
    );
    return { success: true };
});

/**
 * 管理者カスタムクレームを付与する Cloud Function
 * P3-3: 既存の他カスタムクレームを上書き消失させないようマージする
 */
exports.setAdminClaim = onCall({ maxInstances: 5 }, async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
    }
    if (!request.auth.token.admin) {
        throw new HttpsError("permission-denied", "管理者権限が必要です。");
    }

    const { uid } = request.data || {};
    if (!uid || typeof uid !== "string" || uid.trim().length === 0) {
        throw new HttpsError("invalid-argument", "対象ユーザーのUIDが必要です。");
    }

    const targetUid = uid.trim();
    const userRecord = await getAuth().getUser(targetUid);
    const existingClaims = userRecord.customClaims || {};

    await getAuth().setCustomUserClaims(targetUid, {
        ...existingClaims,
        admin: true,
    });
    logger.info(
        `Admin claim granted to uid: ${targetUid} by admin: ${request.auth.uid}`,
    );
    return { success: true };
});

/**
 * 管理者カスタムクレームを剥奪する Cloud Function
 * P3-3: 自分自身の管理者権限を誤って剥奪するロックアウト事故を防止し、他クレームを保持する
 */
exports.removeAdminClaim = onCall({ maxInstances: 5 }, async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
    }
    if (!request.auth.token.admin) {
        throw new HttpsError("permission-denied", "管理者権限が必要です。");
    }

    const { uid } = request.data || {};
    if (!uid || typeof uid !== "string" || uid.trim().length === 0) {
        throw new HttpsError("invalid-argument", "対象ユーザーのUIDが必要です。");
    }

    const targetUid = uid.trim();
    if (targetUid === request.auth.uid) {
        throw new HttpsError(
            "failed-precondition",
            "自分自身の管理者権限は剥奪できません。",
        );
    }

    const userRecord = await getAuth().getUser(targetUid);
    const updatedClaims = { ...(userRecord.customClaims || {}) };
    delete updatedClaims.admin;

    await getAuth().setCustomUserClaims(targetUid, updatedClaims);
    logger.info(
        `Admin claim removed from uid: ${targetUid} by admin: ${request.auth.uid}`,
    );
    return { success: true };
});

// ============================================================================
// P2-4: 孤児データ・残存Authアカウントの自動クリーンアップトリガー
// ============================================================================

/**
 * イベント削除時にサブコレクション（applications 内の申込学生個人情報）を自動削除する
 */
exports.onEventDeleted = onDocumentDeleted(
    { document: "events/{eventId}", maxInstances: 5 },
    async (event) => {
        const { eventId } = event.params;
        await db.recursiveDelete(db.collection("events").doc(eventId));
        logger.info(`Cleaned up subcollections for deleted event: ${eventId}`);
    },
);

/**
 * 団体ドキュメント削除時（管理画面からのBAN削除等）にサブコレクション・関連イベント・
 * スカウト・Storage画像・Firebase Authアカウントを自動一掃する。
 * 本人退会（deleteMyAccount）による削除の場合は重複処理を避けるためスキップする。
 */
exports.onOrganizationDeleted = onDocumentDeleted(
    { document: "organizations/{orgId}", maxInstances: 5 },
    async (event) => {
        const { orgId } = event.params;

        if (await consumeSelfDeleteTriggerMarker(orgId, "pendingOrgTrigger")) {
            logger.info(
                `Skipped duplicate trigger cleanup for self-deleted organization: orgId=${orgId}`,
            );
            return;
        }

        await db.recursiveDelete(db.collection("organizations").doc(orgId));
        await cleanupRelatedAccountData(orgId, {
            cleanStudentData: false,
            cleanOrgData: true,
        });

        // 同UIDの学生ドキュメントが存在しないことを確認したうえでAuthアカウントも削除
        const userDoc = await db.collection("users").doc(orgId).get();
        if (!userDoc.exists) {
            await deleteAuthUserIdempotent(orgId);
        }
        logger.info(`Cleaned up deleted organization account: orgId=${orgId}`);
    },
);

/**
 * 学生ユーザードキュメント削除時（管理画面からの削除等）に private サブコレクション・
 * スカウト・イベント申込・大学メール一意性ロック・Storage・Authアカウントを自動一掃する。
 * 本人退会（deleteMyAccount）による削除の場合は重複処理を避けるためスキップする。
 */
exports.onUserDeleted = onDocumentDeleted(
    { document: "users/{userId}", maxInstances: 5 },
    async (event) => {
        const { userId } = event.params;

        if (await consumeSelfDeleteTriggerMarker(userId, "pendingUserTrigger")) {
            logger.info(
                `Skipped duplicate trigger cleanup for self-deleted student: userId=${userId}`,
            );
            return;
        }

        const privateSnap = await db
            .collection("users")
            .doc(userId)
            .collection("private")
            .doc("verification")
            .get();
        const universityEmail = privateSnap.data()?.universityEmail;

        // 途中エラー後のリトライ時にも確実にロックを解放できるよう、private削除より先に解除する
        await releaseUniversityEmailLock(userId, universityEmail);
        await db.recursiveDelete(db.collection("users").doc(userId));

        await cleanupRelatedAccountData(userId, {
            cleanStudentData: true,
            cleanOrgData: false,
        });

        const orgDoc = await db.collection("organizations").doc(userId).get();
        if (!orgDoc.exists) {
            await deleteAuthUserIdempotent(userId);
        }
        logger.info(`Cleaned up deleted student account: userId=${userId}`);
    },
);

// ============================================================================
// P3-4: 通報・団体審査申請の運営メール通知トリガー（「24時間以内確認」の運用担保）
// ============================================================================

/**
 * 運営通知メール用の SMTP トランスポーターと送信元アドレスを取得する。
 * 環境変数 ADMIN_SMTP_USER / ADMIN_SMTP_PASS が設定されている場合は学生認証コードとは別の専用送信元を使い、
 * 未設定の場合は既存の SMTP_USER / SMTP_PASS にフォールバックする（いずれの場合もトランザクション流量制限を適用）。
 * @return {{ transporter: import("nodemailer").Transporter, senderEmail: string }} 送信コンテキスト
 */
function createAdminAlertSmtpContext() {
    const dedicatedUser = (process.env.ADMIN_SMTP_USER || "").trim();
    const dedicatedPass = process.env.ADMIN_SMTP_PASS || "";
    if (dedicatedUser && dedicatedPass) {
        return {
            senderEmail: dedicatedUser,
            transporter: nodemailer.createTransport({
                service: "gmail",
                auth: {
                    user: dedicatedUser,
                    pass: dedicatedPass,
                },
            }),
        };
    }
    return {
        senderEmail: SMTP_USER.value(),
        transporter: createSmtpTransporter(),
    };
}

/**
 * 運営通知の重複送信防止とグローバル件数制限（1時間最大5通・24時間最大20通）を
 * 単一トランザクションで行い、学生認証コードのSMTP配信枠を保護しつつメール通知と監査記録を行う。
 * @param {object} params 通知パラメータ
 */
async function sendAdminAlertOnce({
    notificationId,
    type,
    targetId,
    escapedTargetName,
    subject,
    textBody,
    htmlBody,
}) {
    const noteRef = db.collection("admin_notifications").doc(notificationId);
    const rateLimitRef = db
        .collection(ADMIN_ALERT_RATE_LIMIT_COLLECTION)
        .doc(ADMIN_ALERT_RATE_LIMIT_DOC_ID);
    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";

    // At-least-once 配信での重複防止とグローバル送信件数制限を単一トランザクションでアトミックに判定
    const decision = await db.runTransaction(async (tx) => {
        const [existing, rateSnap] = await Promise.all([
            tx.get(noteRef),
            tx.get(rateLimitRef),
        ]);
        if (existing.exists) {
            return { action: "duplicate" };
        }

        const nowMs = Date.now();
        const rateData = rateSnap.exists ? rateSnap.data() || {} : {};

        let hourWindowStartMs =
            typeof rateData.hourWindowStartMs === "number"
                ? rateData.hourWindowStartMs
                : nowMs;
        let hourSentCount =
            typeof rateData.hourSentCount === "number"
                ? rateData.hourSentCount
                : 0;
        if (nowMs - hourWindowStartMs >= ONE_HOUR_MS) {
            hourWindowStartMs = nowMs;
            hourSentCount = 0;
        }

        let dayWindowStartMs =
            typeof rateData.dayWindowStartMs === "number"
                ? rateData.dayWindowStartMs
                : nowMs;
        let daySentCount =
            typeof rateData.daySentCount === "number"
                ? rateData.daySentCount
                : 0;
        if (nowMs - dayWindowStartMs >= ONE_DAY_MS) {
            dayWindowStartMs = nowMs;
            daySentCount = 0;
        }

        const suppressedCount =
            typeof rateData.suppressedSinceLastEmail === "number"
                ? rateData.suppressedSinceLastEmail
                : 0;

        // 上限到達時は監査ドキュメントのみ記録し、SMTP送信をスキップして認証コード配信を保護する
        if (
            hourSentCount >= MAX_ADMIN_ALERT_EMAILS_PER_HOUR ||
            daySentCount >= MAX_ADMIN_ALERT_EMAILS_PER_DAY
        ) {
            tx.set(noteRef, {
                type,
                targetId,
                escapedTargetName,
                subject,
                status: "rate_limited",
                rateLimitedAt: FieldValue.serverTimestamp(),
                createdAt: FieldValue.serverTimestamp(),
            });
            tx.set(rateLimitRef, {
                hourWindowStartMs,
                hourSentCount,
                dayWindowStartMs,
                daySentCount,
                suppressedSinceLastEmail: suppressedCount + 1,
                updatedAt: FieldValue.serverTimestamp(),
            });
            return { action: "rate_limited" };
        }

        const nextHourCount = hourSentCount + 1;
        const nextDayCount = daySentCount + 1;
        const isReachingLimitNow =
            nextHourCount >= MAX_ADMIN_ALERT_EMAILS_PER_HOUR ||
            nextDayCount >= MAX_ADMIN_ALERT_EMAILS_PER_DAY;

        tx.set(noteRef, {
            type,
            targetId,
            escapedTargetName,
            subject,
            status: isEmulator ? "mock_emulator" : "sending",
            priorSuppressedCount: suppressedCount,
            reachedRateLimit: isReachingLimitNow,
            createdAt: FieldValue.serverTimestamp(),
        });
        tx.set(rateLimitRef, {
            hourWindowStartMs,
            hourSentCount: nextHourCount,
            dayWindowStartMs,
            daySentCount: nextDayCount,
            suppressedSinceLastEmail: 0,
            updatedAt: FieldValue.serverTimestamp(),
        });

        return {
            action: "send",
            priorSuppressedCount: suppressedCount,
            isReachingLimitNow,
        };
    });

    if (decision.action === "duplicate") return;
    if (decision.action === "rate_limited") {
        logger.warn(
            `Admin alert email suppressed by rate limit: id=${notificationId} type=${type}`,
        );
        return;
    }

    if (isEmulator) {
        logger.info(`[MOCK] Admin alert (${type}): ${subject}`);
        return;
    }

    const extraTextNotes = [];
    const extraHtmlNotes = [];
    if (decision.priorSuppressedCount > 0) {
        extraTextNotes.push(
            `※直前の流量制限中に他 ${decision.priorSuppressedCount} 件の通知メールが省略されています。管理画面で未確認の項目をすべて確認してください。`,
        );
        extraHtmlNotes.push(
            `<p style="padding: 10px; background: #fff8e1; border-left: 4px solid #f9a825; font-size: 13px;">※直前の流量制限中に他 <strong>${decision.priorSuppressedCount}件</strong> の通知メールが省略されています。管理画面で未確認の項目をすべて確認してください。</p>`,
        );
    }
    if (decision.isReachingLimitNow) {
        extraTextNotes.push(
            `※短時間に通知が集中したため、認証コード配信保護のためこれ以降の通知メールを一時制限します（1時間最大${MAX_ADMIN_ALERT_EMAILS_PER_HOUR}通・24時間最大${MAX_ADMIN_ALERT_EMAILS_PER_DAY}通）。管理画面から全件確認してください。`,
        );
        extraHtmlNotes.push(
            `<p style="padding: 10px; background: #ffebee; border-left: 4px solid #d32f2f; font-size: 13px;">※短時間に通知が集中したため、認証コード配信保護のためこれ以降の通知メールを一時制限します（1時間最大${MAX_ADMIN_ALERT_EMAILS_PER_HOUR}通・24時間最大${MAX_ADMIN_ALERT_EMAILS_PER_DAY}通）。管理画面から全件確認してください。</p>`,
        );
    }

    const finalTextBody =
        extraTextNotes.length > 0
            ? `${textBody}\n\n${extraTextNotes.join("\n")}`
            : textBody;
    const finalHtmlBody =
        extraHtmlNotes.length > 0
            ? `${htmlBody}\n${extraHtmlNotes.join("\n")}`
            : htmlBody;

    const { transporter, senderEmail } = createAdminAlertSmtpContext();
    const adminRecipient =
        (process.env.ADMIN_NOTIFY_EMAIL || "").trim() || senderEmail;

    try {
        await transporter.sendMail({
            from: `"D-Hub 監視通知" <${senderEmail}>`,
            to: adminRecipient,
            subject,
            text: finalTextBody,
            html: finalHtmlBody,
        });
        await noteRef.update({
            status: "sent",
            sentAt: FieldValue.serverTimestamp(),
        });
        logger.info(`Admin alert sent: id=${notificationId}`);
    } catch (error) {
        await noteRef.update({
            status: "failed",
            errorMessage: String(error.message || error),
        });
        logger.error(`Failed to send admin alert: id=${notificationId}`, error);
    }
}

/**
 * 新規通報（reports/{reportId}）が作成された際に運営へメール通知する（件数制限付き）
 */
exports.onReportCreated = onDocumentCreated(
    {
        document: "reports/{reportId}",
        secrets: [SMTP_USER, SMTP_PASS],
        maxInstances: 5,
    },
    async (event) => {
        const data = event.data?.data();
        if (!data || data.isReviewSeed === true) return;

        const { reportId } = event.params;
        const cleanReason = sanitizeSingleLine(data.reason || "不明");
        const cleanTargetName = sanitizeSingleLine(data.targetName || "不明");
        const safeTargetName = escapeHtml(cleanTargetName || "不明");
        const safeTargetType = escapeHtml(data.targetType || "不明");
        const safeTargetId = escapeHtml(data.targetId || "不明");
        const safeReason = escapeHtml(cleanReason || "不明");
        const safeReporterRole = escapeHtml(data.reporterRole || "不明");
        const safeDetail = escapeHtml(data.detail || "（補足なし）");

        const subject = `【D-Hub 要確認】新規通報を受信しました（理由: ${cleanReason || "不明"}）`;
        const textBody = [
            "D-Hub で新しい通報が送信されました。24時間以内に管理画面から内容を確認してください。",
            "",
            `通報ID: ${reportId}`,
            `対象種別: ${data.targetType || "不明"}`,
            `対象名: ${cleanTargetName || "不明"} (${data.targetId || "不明"})`,
            `通報理由: ${cleanReason || "不明"}`,
            `通報者種別: ${data.reporterRole || "不明"}`,
            `補足内容: ${data.detail || "（補足なし）"}`,
        ].join("\n");

        const htmlBody = `
        <div style="font-family: sans-serif; color: #333;">
            <h2>【D-Hub】新規通報のお知らせ</h2>
            <p>新しい通報が送信されました。利用規約に基づき<strong>24時間以内</strong>に管理画面から確認してください。</p>
            <ul>
                <li><strong>通報ID:</strong> ${escapeHtml(reportId)}</li>
                <li><strong>対象種別:</strong> ${safeTargetType}</li>
                <li><strong>対象:</strong> ${safeTargetName} (<code>${safeTargetId}</code>)</li>
                <li><strong>理由:</strong> ${safeReason}</li>
                <li><strong>通報者種別:</strong> ${safeReporterRole}</li>
            </ul>
            <p><strong>補足内容:</strong></p>
            <pre style="padding: 12px; background: #f5f5f5; border-radius: 6px; white-space: pre-wrap;">${safeDetail}</pre>
        </div>
        `;

        await sendAdminAlertOnce({
            notificationId: `report_${reportId}`,
            type: "report",
            targetId: reportId,
            escapedTargetName: safeTargetName,
            subject,
            textBody,
            htmlBody,
        });
    },
);

/**
 * 団体アカウントの審査申請（proofImageUrl が初めて設定された update または直接 create）が行われた際に運営へメール通知する。
 * サインアップ時の仮ドキュメント（name: '団体名未設定', proofImageUrl 未設定）では通知しない。
 */
exports.onOrganizationApplicationSubmitted = onDocumentWritten(
    {
        document: "organizations/{orgId}",
        secrets: [SMTP_USER, SMTP_PASS],
        maxInstances: 5,
    },
    async (event) => {
        const beforeData = event.data?.before?.data();
        const afterData = event.data?.after?.data();

        if (
            !afterData ||
            afterData.isReviewSeed === true ||
            afterData.status !== "pending"
        ) {
            return;
        }

        const beforeProofUrl =
            typeof beforeData?.proofImageUrl === "string"
                ? beforeData.proofImageUrl.trim()
                : "";
        const afterProofUrl =
            typeof afterData.proofImageUrl === "string"
                ? afterData.proofImageUrl.trim()
                : "";

        // proofImageUrl が未設定（空）から初めて設定された書き込みのみを通知契機とする
        if (beforeProofUrl.length > 0 || afterProofUrl.length === 0) {
            return;
        }

        const { orgId } = event.params;
        const cleanOrgName = sanitizeSingleLine(afterData.name || "団体名未設定");
        const cleanCampus = sanitizeSingleLine(afterData.campus || "未設定");
        const cleanInstagram = sanitizeSingleLine(
            afterData.instagramUrl || "（未入力）",
        );
        const safeOrgName = escapeHtml(cleanOrgName || "団体名未設定");
        const safeCampus = escapeHtml(cleanCampus || "未設定");
        const safeInstagram = escapeHtml(cleanInstagram || "（未入力）");

        const subject = `【D-Hub 審査依頼】団体作成の申請が提出されました（${cleanOrgName || "団体名未設定"}）`;
        const textBody = [
            "D-Hub で団体アカウントの活動証明画像が提出されました（ステータス: pending）。",
            "管理画面の「団体管理」タブから証明画像・活動内容を確認し、24時間以内に承認・却下の審査を行ってください。",
            "",
            `団体UID: ${orgId}`,
            `団体名: ${cleanOrgName || "団体名未設定"}`,
            `キャンパス: ${cleanCampus || "未設定"}`,
            `Instagram: ${cleanInstagram || "（未入力）"}`,
        ].join("\n");

        const htmlBody = `
        <div style="font-family: sans-serif; color: #333;">
            <h2>【D-Hub】団体審査申請のお知らせ</h2>
            <p>活動証明画像付きの団体申請が提出されました。管理画面から実在確認・審査を行ってください。</p>
            <ul>
                <li><strong>団体UID:</strong> <code>${escapeHtml(orgId)}</code></li>
                <li><strong>団体名:</strong> ${safeOrgName}</li>
                <li><strong>キャンパス:</strong> ${safeCampus}</li>
                <li><strong>Instagram:</strong> ${safeInstagram}</li>
            </ul>
        </div>
        `;

        await sendAdminAlertOnce({
            notificationId: `org_${orgId}`,
            type: "organization_pending",
            targetId: orgId,
            escapedTargetName: safeOrgName,
            subject,
            textBody,
            htmlBody,
        });
    },
);

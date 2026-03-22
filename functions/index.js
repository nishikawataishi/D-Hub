const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const nodemailer = require("nodemailer");
const crypto = require("crypto");
const admin = require("firebase-admin");
const { Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

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

    // レート制限チェック
    const userDoc = await userRef.get();
    if (userDoc.exists) {
        const data = userDoc.data();
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
    const existingData = userDoc.exists ? userDoc.data() : {};
    const existingWindowStart = existingData.codeSentWindowStart?.toDate();
    const hourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    const resetWindow = !existingWindowStart || existingWindowStart <= hourAgo;

    // Firestoreにハッシュ化コード + メタデータを保存
    await userRef.set({
        codeHashedValue: hashedCode,
        universityEmail: normalizedEmail,
        codeExpiresAt: Timestamp.fromDate(expiresAt),
        verificationAttempts: 0,
        lastCodeSentAt: FieldValue.serverTimestamp(),
        codeSentCount: resetWindow ? 1 : FieldValue.increment(1),
        codeSentWindowStart: resetWindow
            ? FieldValue.serverTimestamp()
            : existingData.codeSentWindowStart,
        isStudentVerified: false,
    }, { merge: true });

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
        subject: "【D.scout】学生認証コードのお知らせ",
        text: `D.scout をご利用いただきありがとうございます。\n\n以下の6桁の認証コードをアプリに入力して、学生認証を完了してください。\n\n認証コード: ${code}\n\n※このコードの有効期限は${CODE_EXPIRY_MINUTES}分です。\n※心当たりがない場合は、このメールを破棄してください。`,
        html: `
        <div style="font-family: sans-serif; color: #333;">
            <h2>D.scout 学生認証</h2>
            <p>D.scout をご利用いただきありがとうございます。</p>
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

    // トランザクションで試行回数チェック + 検証をアトミックに実行
    const result = await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
            throw new HttpsError("not-found", "ユーザー情報が見つかりません。");
        }

        const data = userDoc.data();
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
            transaction.update(userRef, {
                verificationAttempts: attempts + 1,
            });
            return {
                success: false,
                message: `確認コードが一致しません（残り${MAX_VERIFY_ATTEMPTS - attempts - 1}回）`,
            };
        }

        // 認証成功: isStudentVerified = true に更新 + コード削除
        transaction.update(userRef, {
            isStudentVerified: true,
            verifiedAt: FieldValue.serverTimestamp(),
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

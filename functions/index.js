const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const nodemailer = require("nodemailer");

const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");

exports.sendVerificationCode = onCall(
    { secrets: [SMTP_USER, SMTP_PASS] },
    async (request) => {
    // 認証済みかチェック
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'ログインが必要です。');
    }

    const { email, code } = request.data;
    if (!email || !code) {
        throw new HttpsError('invalid-argument', '必須パラメータ (email, code) が不足しています。');
    }

    // 大学ドメインの簡易チェック
    const allowedDomainPattern = /^.+@(mail[1-9]?\.doshisha\.ac\.jp|dwc\.doshisha\.ac\.jp)$/;
    if (!allowedDomainPattern.test(email)) {
        throw new HttpsError('invalid-argument', '許可されていないドメインです。');
    }

    // エミュレーター環境では実際のメール送信をスキップして成功をモックする
    if (process.env.FUNCTIONS_EMULATOR === 'true') {
        logger.info(`[MOCK] Verification code ${code} pseudo-sent to ${email}`);
        return { success: true };
    }

    const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
            user: SMTP_USER.value(),
            pass: SMTP_PASS.value()
        }
    });

    const mailOptions = {
        from: `"D.scout 運営" <${SMTP_USER.value()}>`,
        to: email,
        subject: '【D.scout】学生認証コードのお知らせ',
        text: `D.scout をご利用いただきありがとうございます。\n\n以下の6桁の認証コードをアプリに入力して、学生認証を完了してください。\n\n認証コード: ${code}\n\n※このコードの有効期限は30分です。\n※心当たりがない場合は、このメールを破棄してください。`,
        html: `
        <div style="font-family: sans-serif; color: #333;">
            <h2>D.scout 学生認証</h2>
            <p>D.scout をご利用いただきありがとうございます。</p>
            <p>以下の6桁の認証コードをアプリに入力して、学生認証を完了してください。</p>
            <div style="padding: 16px; background-color: #f4f4f4; border-radius: 8px; font-size: 24px; font-weight: bold; letter-spacing: 4px; text-align: center;">
                ${code}
            </div>
            <p style="color: #666; font-size: 12px; margin-top: 24px;">
                ※このコードの有効期限は30分です。<br>
                ※心当たりがない場合は、このメールを破棄してください。
            </p>
        </div>
        `
    };

    try {
        await transporter.sendMail(mailOptions);
        logger.info(`Verification code sent to ${email}`);
        return { success: true };
    } catch (error) {
        logger.error(`Failed to send email to ${email}`, error);
        throw new HttpsError('internal', 'メールの送信に失敗しました。');
    }
});

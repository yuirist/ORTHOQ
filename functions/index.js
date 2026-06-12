const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const nodemailer = require('nodemailer');

initializeApp();

const smtpUser = defineSecret('SMTP_USER');
const smtpPassword = defineSecret('SMTP_APP_PASSWORD');

exports.sendOutboundMail = onDocumentCreated(
  {
    document: 'outbound_mail/{mailId}',
    secrets: [smtpUser, smtpPassword],
    region: 'asia-southeast1',
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    if (!data || data.status !== 'pending') return;

    const mailId = event.params.mailId;
    const db = getFirestore();
    const mailRef = db.collection('outbound_mail').doc(mailId);

    const to = (data.to || '').trim();
    if (!to) {
      await mailRef.update({
        status: 'failed',
        error: 'Recipient email is empty',
        processedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: smtpUser.value(),
        pass: smtpPassword.value(),
      },
    });

    try {
      const info = await transporter.sendMail({
        from: `"OrthoQ" <${smtpUser.value()}>`,
        to,
        subject: data.subject || 'OrthoQ Notification',
        html: data.html || '',
        text: data.text || '',
      });

      await mailRef.update({
        status: 'sent',
        messageId: info.messageId || null,
        processedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error(`sendOutboundMail failed for ${mailId}:`, error);
      await mailRef.update({
        status: 'failed',
        error: String(error),
        processedAt: FieldValue.serverTimestamp(),
      });
    }
  },
);

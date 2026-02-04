const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.notifyCourierOnNewOrder = functions.firestore
    .document('agent_orders/{orderId}')
    .onCreate(async (snap, context) => {
        const orderData = snap.data();
        const courierId = orderData.courierId;

        // جلب توكن المندوب من كوليكشن users
        const userDoc = await admin.firestore().collection('users').doc(courierId).get();
        const fcmToken = userDoc.data().fcmToken;

        if (fcmToken) {
            const message = {
                notification: {
                    title: '📦 أوردر جديد بانتظارك!',
                    body: `لديك مهمة توصيل للعميل: ${orderData.customerName}`,
                },
                token: fcmToken,
            };
            return admin.messaging().send(message);
        }
    });
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// Doit correspondre à _androidChannel.id dans notification_service.dart
const CHANNEL_ID = "nouvelles_commandes";
const MAX_MULTICAST_TOKENS = 500;

async function sendToUser(uid, order, orderId, title) {
  const db = getFirestore();
  let userRef = db.collection("users").doc(uid);
  let snap = await userRef.get();
  if (!snap.exists) {
    // Si non trouvé par ID de document, recherche par le champ email
    const byEmail = await db.collection("users").where("email", "==", uid).limit(1).get();
    if (!byEmail.empty) {
      snap = byEmail.docs[0];
      userRef = snap.ref;
    } else {
      return;
    }
  }
  const storedTokens = snap.get("fcmTokens");
  const tokens = Array.isArray(storedTokens)
    ? [...new Set(storedTokens.filter((token) => typeof token === "string" && token.length > 0))]
    : [];
  if (!tokens.length) return;

  const dead = [];
  for (let i = 0; i < tokens.length; i += MAX_MULTICAST_TOKENS) {
    const batch = tokens.slice(i, i + MAX_MULTICAST_TOKENS);
    const result = await getMessaging().sendEachForMulticast({
      tokens: batch,
      notification: {
        title,
        body: `Commande #${order.displayNumber || orderId} - Total : ${order.total ?? "—"} ${order.currency || "TND"}`,
      },
      data: { orderId: String(orderId) },
      android: {
        priority: "high",
        notification: { channelId: CHANNEL_ID, sound: "default" },
      },
      apns: { payload: { aps: { sound: "default" } } },
    });

    result.responses.forEach((response, index) => {
      const code = response.error && response.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        dead.push(batch[index]);
      }
    });
  }

  for (let i = 0; i < dead.length; i += MAX_MULTICAST_TOKENS) {
    await userRef.update({
      fcmTokens: FieldValue.arrayRemove(...dead.slice(i, i + MAX_MULTICAST_TOKENS)),
    });
  }
}

// Nouvelle commande : notifie le livreur assigné + tous les admins
exports.onNewOrder = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data ? event.data.data() : null;
  if (!order) return;
  const orderId = event.params.orderId;

  const admins = await getFirestore().collection("users").where("role", "==", "admin").get();
  const recipients = new Set(admins.docs.map((admin) => admin.id));

  const livreurId = order.livreurId || order.driverId || (order.driver && order.driver.id);
  if (typeof livreurId === "string" && livreurId.length > 0) {
    recipients.add(livreurId);
  }

  await Promise.all(
    [...recipients].map((uid) => sendToUser(uid, order, orderId, "Nouvelle commande reçue !")),
  );
});

// Commande (ré)assignée à un livreur après création
exports.onOrderAssigned = onDocumentUpdated("orders/{orderId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before ? event.data.before.data() : {};
  const after = event.data.after ? event.data.after.data() : {};

  const beforeLivreur = before.livreurId || before.driverId || (before.driver && before.driver.id);
  const afterLivreur = after.livreurId || after.driverId || (after.driver && after.driver.id);

  if (
    typeof afterLivreur === "string" &&
    afterLivreur.length > 0 &&
    (afterLivreur !== beforeLivreur || (before.status !== after.status && after.status === "confirmed"))
  ) {
    await sendToUser(afterLivreur, after, event.params.orderId, "Commande assignée !");
  }
});
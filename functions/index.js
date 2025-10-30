/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { setGlobalOptions } = require("firebase-functions");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Inicializa Firebase Admin
admin.initializeApp();

// Opciones globales (opcional)
setGlobalOptions({ maxInstances: 10 });

/**
 * ✅ Cloud Function para asignar roles personalizados (Custom Claims)
 *    Solo usuarios con el claim `admin` pueden asignar roles.
 */
exports.setUserRole = onCall(async (request) => {
  const { uid, role } = request.data;
  const context = request.auth;

  // 🔒 Verifica si el usuario autenticado tiene rol admin
//  if (!context || !context.token?.admin) {
if (!context || !context.token || !context.token.admin) {
    throw new Error("Permiso denegado: solo un administrador puede asignar roles.");
  }

  // 🔧 Asigna el rol al usuario
  await admin.auth().setCustomUserClaims(uid, { role });

  return {
    success: true,
    message: `Rol '${role}' asignado correctamente al usuario con UID ${uid}`,
  };
});

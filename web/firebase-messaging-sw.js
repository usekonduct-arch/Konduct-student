// Push notifications for the Konduct web app (Firebase Cloud Messaging). The Firebase SDK finds this
// file by name. A notification that arrives while the app is closed is shown by the SDK; tapping it
// brings the app to the front (the message is in the inbox).
//
// Keep the version in step with firebase_core_web's supportedFirebaseJsSdkVersion.

// Registered before the SDK's own handler, which only acts on notifications that carry a link.
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    (async () => {
      const open = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
      for (const c of open) if ("focus" in c) return c.focus();
      return self.clients.openWindow("./");
    })(),
  );
});

importScripts("https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBsD0Oh0_IkMFMLsu4jedXGUPp8TSX65Ms",
  authDomain: "konduct-10ffb.firebaseapp.com",
  projectId: "konduct-10ffb",
  storageBucket: "konduct-10ffb.firebasestorage.app",
  messagingSenderId: "1046053007846",
  appId: "1:1046053007846:web:7f62bf12cebb5af507a627",
});
firebase.messaging();

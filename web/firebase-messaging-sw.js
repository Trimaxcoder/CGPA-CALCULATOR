importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAiKozGsi5w0ftbHYUL6E7L39Tv7_t2wvQ",
  authDomain: "cgpa-calculator-8e6ae.firebaseapp.com",
  projectId: "cgpa-calculator-8e6ae",
  storageBucket: "cgpa-calculator-8e6ae.appspot.com",
  messagingSenderId: "672646882187",
  appId: "1:672646882187:web:fdc0178e7a7c68ae3f058e"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Background message received:', payload);

  const notificationTitle = payload.notification?.title || 'Gradex';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
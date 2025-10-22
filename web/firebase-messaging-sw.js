importScripts('https://www.gstatic.com/firebasejs/9.6.11/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.11/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDaXqWdZgxXkjhAsn2TFOXPPUL9xSXbDZw",
  authDomain: "albo-car-ride.firebaseapp.com",
  projectId: "albo-car-ride",
  messagingSenderId: "167231435552",
  appId: "1:167231435552:web:bc6cf32c6b5d9e8ac99d45"
});

const messaging = firebase.messaging();
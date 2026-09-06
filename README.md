# 💕 MatchUp — Flutter Frontend

**MatchUp** is a modern Flutter-based frontend application designed for connecting users, real-time conversations, calling, and social interactions.

This repository contains **only the frontend application** of MatchUp.

---

## 🚀 Features

* 🔐 User Authentication

  * Login
  * Registration
  * OTP Verification
  * Forgot Password / Password Reset

* 👤 User Profile

  * Profile information
  * Profile image
  * User details

* 💕 Matching System

  * Discover users
  * Like / Pass
  * Match interactions

* 💬 Real-Time Chat

  * One-to-one messaging
  * Real-time message delivery
  * Typing indicator
  * Message timestamps
  * Chat history

* 📞 Real-Time Calling

  * Outgoing call screen
  * Incoming call screen
  * Incoming ringtone
  * Accept / Reject call
  * End call

* 🔔 Real-Time Notifications

  * New messages
  * Calls
  * Match-related notifications

* 🟢 Online / Offline Status

  * Real-time connection status
  * Socket reconnection handling

* 🎨 Modern UI

  * Responsive Flutter interface
  * Clean navigation
  * Consistent theme
  * Mobile-first design

---

## 🛠️ Tech Stack

| Technology                          | Purpose                 |
| ----------------------------------- | ----------------------- |
| Flutter                             | Frontend Framework      |
| Dart                                | Programming Language    |
| REST API                            | Backend Communication   |
| Socket.IO / WebSocket               | Real-Time Communication |
| Provider / State Management         | Application State       |
| HTTP / Dio                          | API Requests            |
| Shared Preferences / Secure Storage | Local Data              |
| WebRTC                              | Real-Time Calling       |

> The exact packages may vary depending on the current implementation of the project.

---

## 📁 Project Structure

```text
MatchUp-app/
│
├── android/
├── ios/
├── assets/
│   ├── images/
│   ├── icons/
│   └── sounds/
│
├── lib/
│   │
│   ├── main.dart
│   │
│   ├── config/
│   │   ├── api_config.dart
│   │   └── socket_config.dart
│   │
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── message_model.dart
│   │   └── call_model.dart
│   │
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── socket_service.dart
│   │   └── call_service.dart
│   │
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── chat_provider.dart
│   │   └── call_provider.dart
│   │
│   ├── screens/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── profile/
│   │   ├── chat/
│   │   └── call/
│   │
│   ├── widgets/
│   │   ├── chat_bubble.dart
│   │   ├── typing_indicator.dart
│   │   └── user_card.dart
│   │
│   └── utils/
│       ├── constants.dart
│       └── helpers.dart
│
├── test/
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

> Folder names can differ from the actual project structure. Update this section whenever the architecture changes.

---

## ⚙️ Requirements

Before running the project, make sure you have:

* Flutter SDK
* Dart SDK
* Android Studio or VS Code
* Android Emulator / Physical Android Device
* Xcode for iOS development
* Git

Check Flutter installation:

```bash
flutter doctor
```

---

## 📥 Installation

Clone the repository:

```bash
git clone <YOUR_REPOSITORY_URL>
```

Move into the project:

```bash
cd MatchUp-app
```

Install dependencies:

```bash
flutter pub get
```

---

## ▶️ Run the Application

For development:

```bash
flutter run
```

Run on a specific device:

```bash
flutter devices
```

Then:

```bash
flutter run -d <device-id>
```

---

## 🔧 Configuration

The frontend communicates with the MatchUp backend through APIs and real-time socket connections.

Configure the production/development server URL according to your environment.

Example:

```dart
const String apiBaseUrl = "https://your-production-server.com";
```

For Socket.IO:

```dart
const String socketUrl = "https://your-production-server.com";
```

### ⚠️ Important

Do **not** use:

```text
http://localhost:PORT
```

for a production mobile build.

On a physical phone, `localhost` refers to the phone itself, not your deployed backend server.

For production, use the deployed backend URL and secure connections (`HTTPS` / secure WebSocket transport where applicable).

---

## 🔄 Real-Time Architecture

MatchUp frontend uses real-time communication for chat, typing indicators, notifications, and calls.

### Message Flow

```text
User A
   │
   ▼
MatchUp Flutter App
   │
   ▼
Socket Connection
   │
   ▼
Backend
   │
   ▼
User B Socket
   │
   ▼
MatchUp Flutter App
   │
   ▼
Message appears
```

### Typing Indicator

```text
User A starts typing
        │
        ▼
typing_start
        │
        ▼
Backend
        │
        ▼
User B
        │
        ▼
"User is typing..."
```

When the user stops typing:

```text
typing_stop
     │
     ▼
Backend
     │
     ▼
User B
     │
     ▼
Typing indicator disappears
```

---

## 📞 Calling Flow

```text
User A
  │
  │ Call
  ▼
Flutter
  │
  ▼
Socket
  │
  ▼
Backend
  │
  ▼
User B
  │
  ▼
Incoming Call Screen
  │
  ├── Accept
  │
  └── Reject
```

The frontend handles:

* Calling UI
* Incoming call UI
* Ringtone
* Accept call
* Reject call
* End call
* Call state changes

---

## 💬 Chat

The chat interface supports real-time one-to-one communication.

Typical message object:

```json
{
  "messageId": "message_id",
  "senderId": "user_a",
  "receiverId": "user_b",
  "conversationId": "conversation_id",
  "text": "Hello!",
  "createdAt": "2026-09-06T10:00:00Z",
  "messageType": "text"
}
```

The frontend uses `senderId`, `receiverId`, and `conversationId` to correctly determine whether a message is incoming or outgoing.

---

## 🔐 Authentication

The frontend authentication flow includes:

```text
Register
   ↓
OTP Verification
   ↓
Account Created
   ↓
Login
   ↓
Authentication Token
   ↓
Authenticated Application
```

Password recovery:

```text
Login
   ↓
Forgot Password
   ↓
Email / Phone
   ↓
OTP
   ↓
Verify OTP
   ↓
New Password
   ↓
Password Updated
   ↓
Login
```

Authentication credentials/tokens should be stored securely on the device.

---

## 📱 Build APK

Generate a release APK:

```bash
flutter build apk --release
```

APK will be generated under:

```text
build/app/outputs/flutter-apk/release/
```

For a Play Store release, an Android App Bundle can be generated:

```bash
flutter build appbundle --release
```

---

## 🧪 Testing

Run Flutter tests:

```bash
flutter test
```

Analyze the project:

```bash
flutter analyze
```

Format the code:

```bash
dart format .
```

---

## 🔍 Production Testing Checklist

Before releasing the application, verify:

* [ ] Registration works
* [ ] OTP verification works
* [ ] Login works
* [ ] Forgot Password works
* [ ] Profile loads correctly
* [ ] Matching works
* [ ] Chat history loads
* [ ] Messages are delivered in real time
* [ ] Typing indicator works
* [ ] Online/offline status works
* [ ] Incoming call screen appears
* [ ] Incoming ringtone works
* [ ] Accept call works
* [ ] Reject call works
* [ ] End call works
* [ ] Real-time notifications work
* [ ] Socket reconnect works
* [ ] Production API URL is configured
* [ ] No localhost URL remains in production configuration
* [ ] Release APK works on a physical device

---

## 🔒 Security

Never commit sensitive credentials to GitHub.

Avoid committing:

```text
API keys
JWT secrets
Passwords
Private tokens
Production credentials
```

Use environment/configuration management for sensitive values.

---

## 📌 Project Status

**MatchUp Frontend:** 🚧 In Development

The application is actively being developed with a focus on:

* Real-time communication
* Messaging
* Calling
* Matching
* User experience
* Production stability

---

## 👨‍💻 Frontend

**MatchUp-app**

Built with ❤️ using **Flutter & Dart**.

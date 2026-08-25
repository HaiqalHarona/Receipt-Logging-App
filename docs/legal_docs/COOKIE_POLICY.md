# Cookie & Local Storage Policy for SancFund

**Effective Date:** August 25, 2026  
**Last Updated:** August 25, 2026

This Cookie & Local Storage Policy explains how **SancFund** ("we," "us," or "our") uses device-level local storage technologies across our mobile application and related services.

Because SancFund is a native mobile application, **we do not use traditional browser tracking cookies, third-party advertising cookies, or cross-site tracking pixels**. Instead, we utilize platform-native local storage mechanisms on your device to enable offline functionality, secure your account, and preserve your preferences.

---

## 1. What Are Local Storage Technologies?

Local storage technologies are secure storage areas provided by your mobile operating system that allow applications to save information directly on your physical device. This enables offline access, preserves user settings across application restarts, and securely manages authentication tokens without sending passwords across the network on every action.

---

## 2. On-Device Storage Mechanisms Used

SancFund utilizes only **Essential** and **Functional** local storage mechanisms. We do **NOT** use any advertising, behavioral tracking, or data-sharing storage.

### A. Secure Authentication & Session Tokens (Essential)
- **Purpose:** Securely holds cryptographic session tokens when you are logged into User Mode so you remain signed in without exposing your password.
- **Location:** Stored within your mobile device's hardware-backed secure enclave and keychain storage.
- **Duration:** Retained until you log out or your session expires.
- **Control:** Automatically and permanently erased whenever you log out.

### B. On-Device Database Storage (Essential / Functional)
- **Purpose:** Stores your offline-first transaction records, receipt details, category assignments, and conversation history so the application works seamlessly without an internet connection.
- **Location:** Stored locally within the application's isolated sandbox on your device.
- **Duration:** Persistent on your device until manually deleted.
- **Control:** Can be cleared at any time via in-app settings or by uninstalling the application.

### C. Display & Formatting Preferences (Functional)
- **Purpose:** Remembers your chosen visual theme (Dark, Light, System), color preset, font scaling factor, selected currency symbol, and legal onboarding consent status.
- **Location:** Stored in your device's application configuration storage.
- **Duration:** Persistent across app sessions.
- **Control:** Can be modified or reset at any time in the application settings.

### D. Temporary Image & Thumbnail Cache (Performance)
- **Purpose:** Ephemerally caches receipt photo thumbnails to deliver smooth scrolling and minimize mobile data usage.
- **Location:** Stored in the application's temporary cache directory.
- **Duration:** Automatically managed and pruned as needed.
- **Control:** Automatically cleared upon logout or through your device's system storage settings.

---

## 3. Network Communication & Authorization Headers

When the application communicates with our backend cloud servers:
- **Secure Authorization Headers:** Session authentication is transmitted via standard, encrypted request headers rather than tracking cookies.
- **Fair-Use Protection:** Temporary, anonymous request counters are maintained in short-lived server memory to prevent automated abuse and service overload. These counters expire automatically within seconds and do not track individual browsing habits.

---

## 4. Third-Party Trackers & Advertising

- **Zero Advertising Trackers:** We do not partner with third-party ad networks or embed behavioral tracking SDKs.
- **Zero Cross-App Tracking:** We do not monitor your activity across other applications or websites.
- **Privacy Signal Respect:** Because we do not track users across the web or sell personal data, our systems operate in full compliance with Global Privacy Control (GPC) and Do Not Track (DNT) standards.

---

## 5. How to Manage and Erase Local Data

You have complete control over the information stored on your device:
- **In-App Logout (User Mode):** Tapping `Settings -> Log Out` immediately wipes all hardware-stored authentication tokens, purges the local image cache, and clears on-device records.
- **System-Level Data Clearing:** You can erase all application data at any time via your mobile operating system settings (`Device Settings -> Apps -> SancFund -> Storage -> Clear Data / Storage`).
- **Account Deletion:** Deleting your cloud account via `Settings -> Account -> Delete Account` permanently removes your cloud-synchronized data from our servers.

---

## 6. Updates to This Policy

We may update this Cookie & Local Storage Policy as our application evolves. Any updates will be published with a revised "Last Updated" date at the top of this page.

---

## 7. Contact Us

If you have any questions regarding our storage practices, please contact us at:

- **Privacy Inquiries:** `support@sanctum.com`
- **Customer Support:** `support@sanctum.com`
- **In-App Navigation:** `Settings -> Legal & Compliance -> Cookie & Storage Policy`

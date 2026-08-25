# Privacy Policy for SancFund

**Effective Date:** August 25, 2026  
**Last Updated:** August 25, 2026

Welcome to **SancFund** ("we," "us," or "our"). We are committed to protecting your privacy and ensuring you understand how your financial data, receipts, and personal information are handled.

This Privacy Policy explains our privacy practices, the differences between our **Guest Mode** and **User Mode**, our data encryption and zero-training AI commitments, and your legal rights under the **General Data Protection Regulation (GDPR)**, the **UK Data Protection Act**, the **California Consumer Privacy Act as amended by the California Privacy Rights Act (CCPA/CPRA)**, and other applicable data protection regulations.

---

## 1. Who We Are & Scope

SancFund is a personal expense tracking and receipt management mobile application designed with a **privacy-first, offline-resilient architecture**.

- **Application Name:** SancFund
- **Operator:** SancFund Team
- **Privacy & Data Protection Inquiries:** `support@sanctum.com`
- **Customer Support:** `support@sanctum.com`

This Privacy Policy applies to the SancFund mobile application, the backend cloud services, and any related software features (collectively, the "Service").

---

## 2. Core Operating Modes: Guest Mode vs. User Mode

SancFund is built to provide you with complete control over where your financial information resides.

### A. Guest Mode (Offline-First / Unauthenticated)
- **Strictly Local Storage:** All user-generated data—including receipt photos, merchant details, transaction amounts, itemized lists, categories, currency preferences, and conversational history—are stored **exclusively on your physical device**.
- **No Cloud Account:** You are not required to create an account, register an email address, or provide any personal identification to use the core features of the Service.
- **Ephemeral Processing:** When you scan a receipt or request AI conversational assistance in Guest Mode, image data and conversational contexts are transmitted solely in-memory to perform the requested extraction and are discarded immediately upon completion without persistent cloud storage.
- **Complete Local Control:** You can permanently erase all local records, cached files, and images at any time through the in-app settings or by deleting the application from your device.

### B. User Mode (Encrypted Cloud Synchronization)
- **Cloud Backup & Synchronization:** If you choose to register an account, your receipt records, line items, user preferences, and conversation history are synchronized to secure cloud infrastructure to enable multi-device access and backup.
- **Strong Encryption at Rest:** All sensitive financial records, merchant details, transaction amounts, line items, and conversational logs stored in our cloud databases are protected using **industry-standard authenticated encryption at rest**.
- **Segregated Storage for Images:** Uploaded receipt images are stored in access-controlled, isolated cloud directories accessible strictly through authenticated requests linked to your account.
- **Secure Token Management:** Authentication credentials and session tokens are stored on your device using hardware-backed cryptographic vaults provided by your mobile operating system.

---

## 3. Information We Do NOT Collect

We believe that personal financial management should remain private:
- **No Third-Party Advertising Trackers:** We do not embed third-party advertising networks, marketing pixels, or cross-app tracking identifiers.
- **No Contact Book or Calendar Scraping:** We never access, read, or upload your personal contact lists or address books.
- **No Precise Geolocation Tracking:** We do not track or log your continuous GPS location.
- **No Biometric Data Storage:** Any biometric authentication features (such as fingerprint or facial recognition unlock) are handled entirely on-device by your mobile operating system. We never receive or store your biometric templates.
- **No Sale of Personal Information:** We do not sell, rent, lease, or monetize your personal information or financial data to data brokers, advertisers, or third parties.

---

## 4. Information We Collect and How We Use It

### A. Information You Provide to Us
- **Account Credentials (User Mode Only):** When creating an account, we collect your chosen username, email address, password (stored solely as a secure, salted cryptographic one-way hash; plaintext passwords are never stored or logged), and optional phone number for account recovery.
- **User Preferences:** Display themes, contrast preferences, font scaling, and default currency selections.
- **Receipt Content & Photographs:** Images of receipts you photograph or import from your photo gallery, along with extracted transaction data such as merchant name, purchase date, item descriptions, taxes, and total amounts.
- **Conversational Queries:** Questions, prompts, and financial inquiries you submit to the AI Financial Assistant.

### B. Automatically Collected Operational Data
- **Anonymous Device Identifiers:** A securely hashed, anonymous device token used strictly to enforce fair-use request limits and maintain session security.
- **Operational & Security Logs:** Transient access logs (such as request timestamps, error codes, and anonymized network routing data) retained temporarily to prevent malicious attacks, brute-force attempts, and service disruptions.

---

## 5. Artificial Intelligence Processing & Zero-Training Commitment

SancFund employs advanced Optical Character Recognition (OCR) and Artificial Intelligence (AI) technologies to extract transaction details and provide conversational spending summaries.

We uphold the following strict commitments:
- **Zero AI Model Training:** Your uploaded receipt images, itemized financial records, personal notes, and conversational inquiries are **NEVER used to train, retrain, or fine-tune foundational AI models**.
- **Transient Document Extraction:** When you submit a receipt for scanning, the image is processed in temporary memory to extract structured text and values. The raw processing buffers are purged immediately after extraction.
- **Encrypted Transmission:** All communications with AI inference services take place over modern encrypted transport protocols (TLS 1.3) under enterprise-grade confidentiality terms.

---

## 6. Local Storage Technologies on Your Device

SancFund is a native mobile application and does **not** use traditional browser-based tracking cookies. Instead, the application utilizes secure, platform-native local storage mechanisms:

- **Hardware-Backed Secure Storage:** Stores authenticated session tokens in your device's secure hardware enclave until you log out.
- **On-Device Database Storage:** Stores offline-first receipt records, line items, and conversation threads directly on your device.
- **Application Preferences Storage:** Remembers your visual theme, font scaling, currency code, and legal onboarding consent flags.
- **Temporary Image Cache:** Stores temporary image thumbnails to provide smooth scrolling and reduce data consumption, which can be purged at any time.

---

## 7. Third-Party Service Providers (Sub-Processors)

We engage a limited number of vetted third-party service providers to assist in delivering the Service. All sub-processors are bound by strict data processing agreements and confidentiality obligations:

- **Cloud Database & Hosting Infrastructure:** Provides secure cloud hosting, encrypted database storage, and access-controlled file storage for User Mode accounts.
- **Artificial Intelligence & OCR Inference:** Provides real-time optical character recognition and natural language processing under strict zero-data-retention enterprise terms.
- **Distributed Session & Rate-Limiting Cache:** Provides temporary, in-memory caching to enforce fair-use limits and mitigate denial-of-service threats.

---

## 8. Data Retention & Account Deletion (Right to be Forgotten)

- **Guest Mode Data:** Exists exclusively on your device. Deleting the application or resetting data within the app permanently and irreversibly deletes all stored records.
- **User Mode Data:** Retained in our encrypted database for as long as your account remains active.
- **Account Deletion:** You may permanently delete your account and all associated cloud data at any time directly within the app settings (`Settings -> Account -> Delete Account`) or by contacting `support@sanctum.com`. Upon account deletion, all user profile information, encrypted receipts, storage images, and conversation histories are **permanently and irreversibly destroyed**.

---

## 9. Security Safeguards

We implement defense-in-depth security measures to protect your personal and financial information:
- **Transport Layer Security:** All data transmitted between your device, our backend servers, and authorized sub-processors is encrypted using **TLS 1.3 / HTTPS**.
- **Authenticated Encryption at Rest:** Cloud-stored receipt contents and conversational histories are secured with industry-standard authenticated encryption algorithms.
- **Secure Password Protection:** User passwords are encrypted using state-of-the-art cryptographic hashing algorithms with unique per-user salts.
- **Automated Threat Mitigation:** Rate limiters and monitoring systems protect user accounts against credential stuffing and automated abuse.

---

## 10. Your Rights under GDPR & UK Data Protection Laws

If you reside in the European Economic Area (EEA), the United Kingdom, or Switzerland, you have the following statutory rights under the GDPR / UK GDPR:
- **Right of Access:** Obtain confirmation of whether your personal data is being processed and receive a copy of that data.
- **Right to Rectification:** Request correction of inaccurate or incomplete personal information.
- **Right to Erasure ("Right to be Forgotten"):** Request the permanent deletion of your personal data.
- **Right to Data Portability:** Request an export of your transaction records in a structured, machine-readable format.
- **Right to Restrict or Object to Processing:** Request that we restrict or cease processing your data under certain circumstances.
- **Right to Lodge a Complaint:** Lodge a complaint with your national Data Protection Authority if you believe your rights have been infringed.

To exercise any of these rights, contact us at `support@sanctum.com`.

---

## 11. Your Rights under California Law (CCPA / CPRA & CalOPPA)

If you are a California resident, the CCPA/CPRA provides you with specific privacy protections:
- **Right to Know & Access:** Request information on the categories and specific pieces of personal information collected, used, and disclosed.
- **Right to Delete:** Request deletion of personal information collected from you.
- **Right to Correct:** Request correction of inaccurate personal information.
- **Right to Opt-Out of Sale or Sharing:** We do not sell or share personal information for cross-context behavioral advertising.
- **Non-Discrimination:** We will never discriminate against you (e.g., through price differences or degraded quality) for exercising your legal privacy rights.

---

## 12. Children's Privacy

SancFund is not intended for individuals under the age of **13** (or **16** in the European Economic Area and United Kingdom). We do not knowingly collect personal information from children. If we discover that a child has provided us with personal information, we will take immediate steps to delete such data.

---

## 13. Changes to This Privacy Policy

We may update this Privacy Policy periodically to reflect enhancements to our Service, technological updates, or changes in legal requirements. Material changes will be communicated via in-app notifications or by updating the "Last Updated" date at the top of this document.

---

## 14. Contact Us

If you have questions, feedback, or requests regarding this Privacy Policy or our data protection practices, please contact us:

- **Privacy & Legal Inquiries:** `support@sanctum.com`
- **Customer Support:** `support@sanctum.com`
- **In-App Navigation:** `Settings -> Legal & Compliance -> Privacy Policy`

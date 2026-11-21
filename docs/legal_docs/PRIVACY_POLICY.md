# Privacy Policy for SancFund

**Effective Date:** August 25, 2026  
**Last Updated:** November 10, 2026

Welcome to **SancFund** ("we," "us," or "our"). We are committed to protecting your privacy and ensuring you understand how your financial data, receipts, and personal information are handled.

This Privacy Policy explains our privacy practices, the differences between our **Guest Mode** and **User Mode**, our data encryption and zero-training AI commitments, and your statutory rights under the **Singapore Personal Data Protection Act 2012 (PDPA)**, the **General Data Protection Regulation (GDPR)**, the **UK Data Protection Act**, the **California Consumer Privacy Act as amended by the California Privacy Rights Act (CCPA/CPRA)**, and other applicable data protection regulations.

---

## 1. Who We Are & Scope

SancFund is a personal expense tracking and receipt management mobile application designed with a **privacy-first, offline-resilient architecture**.

- **Application Name:** SancFund
- **Operator:** SancFund Team
- **Designated Data Protection Officer (DPO):** Data Protection Officer, SancFund
- **DPO Contact & Legal Inquiries:** `fayrd06@gmail.com`
- **Customer Support:** `fayrd06@gmail.com`
- **Jurisdiction & Operations:** Singapore & International Operations

This Privacy Policy applies to the SancFund mobile application, the backend cloud services, the public web portal, and any related software features (collectively, the "Service").

---

## 2. Core Operating Modes: Guest Mode vs. User Mode

SancFund is built to provide you with complete control over where your financial information resides.

### A. Guest Mode (Offline-First / Unauthenticated)
- **Strictly Local Storage:** All user-generated data—including receipt photos, merchant details, transaction amounts, itemized lists, categories, currency preferences, and conversational history—are stored **exclusively on your physical device**.
- **No Cloud Account:** You are not required to create an account, register an email address, or provide any personal identification to use the core features of the Service.
- **Ephemeral Processing:** When you scan a receipt or request AI conversational assistance in Guest Mode, image data and conversational contexts are transmitted solely in-memory over encrypted channels to perform the requested extraction and are discarded immediately upon completion without persistent cloud storage.
- **Complete Local Control:** You can permanently erase all local records, cached files, and images at any time through the in-app settings or by deleting the application from your device.

### B. User Mode (Encrypted Cloud Synchronization)
- **Cloud Backup & Synchronization:** If you choose to register an account, your receipt records, line items, user preferences, and conversation history are synchronized to secure cloud infrastructure to enable multi-device access and backup.
- **Strong Encryption at Rest:** All sensitive financial records, merchant details, transaction amounts, line items, and conversational logs stored in our cloud databases are protected using **authenticated AES-256-GCM envelope encryption at rest under per-user Data Encryption Keys (DEKs)**.
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
- **Account Credentials (User Mode Only):** When creating an account, we collect your chosen username, email address, password (stored solely as a cryptographically salted one-way hash; plaintext passwords are never stored or logged), and optional phone number for account recovery.
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

- **Cloud Database & Storage Infrastructure (Supabase Cloud):** Provides secure cloud hosting, PostgreSQL database storage, and access-controlled binary storage for User Mode accounts, hosted in AWS Asia-Pacific (Singapore `ap-southeast-1` primary, with US failover).
- **Encrypted Distributed Backup Archives (Cloudflare R2):** Provides encrypted, immutable disaster recovery backup archives operating across global edge storage networks.
- **Artificial Intelligence & OCR Inference (Google Gemini API):** Provides real-time optical character recognition and natural language processing hosted in United States data centers under strict zero-data-retention enterprise confidentiality terms.
- **Distributed Session & Rate-Limiting Cache (Redis):** Provides temporary, in-memory caching to enforce fair-use limits and mitigate denial-of-service threats.

---

## 8. Data Retention & Account Deletion (Right to be Forgotten)

- **Guest Mode Data:** Exists exclusively on your device. Deleting the application or resetting data within the app permanently and irreversibly deletes all stored records.
- **User Mode Data:** Retained in our encrypted database for as long as your account remains active.
- **In-App Account Deletion:** You may permanently delete your account and all associated cloud data at any time directly within the app settings (`Settings -> Contact & Security -> Delete Account`).
- **Web-Based Account Deletion URL:** In compliance with store privacy policies, you may also request full account and data deletion from any browser without reinstalling the app at `https://<backend-domain>/delete-account` or by contacting `fayrd06@gmail.com`.
- **Crypto-Shredding of Data Encryption Keys (DEKs):** Account deletion triggers immediate **cryptographic shredding** of your unique, per-user Data Encryption Key (DEK). Because all stored receipt records, OCR extractions, images, and AI conversation histories are encrypted using envelope encryption bound to your per-user DEK, destroying this key mathematically and irreversibly renders all persisted cloud ciphertext into permanent mathematical noise that is impossible to decrypt or reconstruct.
- **Device Fingerprint Retention under Legitimate Interest:** In accordance with **GDPR Article 6(1)(f) (Legitimate Interest)** and PDPA guidelines, we retain a one-way, non-reversible cryptographic fingerprint of hardware devices (`SHA-256(device_id + salt)`). This retention is strictly limited to fraud mitigation, preventing free trial recycling abuse, and enforcing fair use. Upon account deletion, the device fingerprint is **fully unlinked** from all user identity records, email addresses, usernames, and APNS/FCM push notification tokens. It cannot be used to trace, identify, or reconstruct the identity or financial activities of the former user.
- **Offline Backup Scrubbing & Snapshot Aging:** Encrypted disaster recovery snapshots and database backup archives are maintained under an immutable rolling retention schedule (30-day lifecycle) before being permanently scrubbed and overwritten. Because the user's per-user DEK is purged at the moment of account deletion, any residual ciphertext existing within pre-existing backup snapshots prior to their expiration remains undecryptable mathematical noise throughout the remainder of the aging lifecycle.

---

## 9. Security Safeguards

We implement defense-in-depth security measures to protect your personal and financial information:
- **Envelope Encryption & Per-User DEK Architecture:** SancFund employs a multi-tiered envelope encryption model. Each registered user account is provisioned with an isolated, unique Data Encryption Key (DEK) operating with authenticated **AES-256-GCM** encryption. All sensitive financial records, merchant details, OCR line items, and conversational logs are encrypted at rest under the user's specific DEK. The DEK itself is encrypted and protected by a root Key Encryption Key (KEK) hierarchy.
- **Crypto-Shredding on Account Deletion:** By segregating each user's data under a distinct DEK, account termination instantly executes crypto-shredding: the destruction of the DEK permanently renders all associated database rows and cloud storage objects irrecoverable mathematical noise across all primary and secondary datastores.
- **Transport Layer Security (TLS 1.3):** All data transmitted between your device, our backend servers, and authorized sub-processors is encrypted using **TLS 1.3 / HTTPS** with forward secrecy.
- **Hardware-Backed Key Storage:** Client-side cryptographic tokens and session keys are secured using platform-native hardware enclaves (iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and Android KeyStore with EncryptedSharedPreferences).
- **Secure Password Protection:** User passwords are encrypted using state-of-the-art cryptographic hashing algorithms with unique per-user salts. Plaintext passwords are never logged, transmitted in cleartext, or stored in persistent storage.
- **Automated Threat Mitigation:** Rate limiters, automated threat detection, and session security systems protect user accounts against credential stuffing, brute-force attempts, and automated abuse.

---

## 10. Singapore Personal Data Protection Act (PDPA 2012) Statutory Notice

If you reside in Singapore or access the Service within Singapore, the Personal Data Protection Act 2012 (PDPA) and the Personal Data Protection Regulations 2021 govern the collection, use, disclosure, and care of your personal data.

### A. Designation of Data Protection Officer (DPO) (§ 11 & § 20)
In accordance with PDPA § 11(5), SancFund has designated a Data Protection Officer (DPO) responsible for overseeing our compliance with the PDPA. For any inquiries, feedback, or requests concerning your personal data or this Privacy Policy, you may contact our DPO electronically at:
- **Email:** `fayrd06@gmail.com` (Subject: Attention: Data Protection Officer)

### B. Compliance with the 9 PDPA Data Protection Obligations
We adhere strictly to the nine core Data Protection Obligations set out under the PDPA:

1. **Consent Obligation (§ 13–§ 17):** We collect, use, and disclose personal data only with your informed consent, obtained upon initial onboarding and prior to activating User Mode cloud synchronization. You may withdraw your consent at any time through in-app settings (`Settings -> Contact & Security -> Delete Account`), through our public web deletion page, or by contacting our DPO.
2. **Purpose Limitation Obligation (§ 18):** Personal data is collected solely for the purposes of expense logging, receipt Optical Character Recognition (OCR), itemized financial analytics, and conversational assistance. We never sell, rent, or repurpose your data for marketing or behavioral profiling.
3. **Notification Obligation (§ 20):** We inform you of the purposes for which your data is collected before or at the time of collection through in-app onboarding notices and this Privacy Policy.
4. **Access and Correction Obligations (§ 21 & § 22):** You have the right to request access to your personal data in our possession or control, as well as information on how it has been used or disclosed within the past 12 months. You may also request the correction of any errors or omissions. We commit to responding to all formal requests within **30 calendar days**.
5. **Accuracy Obligation (§ 23):** We take reasonable steps to ensure your personal data is accurate and complete, providing in-app tools to edit extracted receipt details, correct merchant information, and update user preferences.
6. **Protection Obligation (§ 24):** We protect personal data with robust administrative, physical, and technical safeguards, including isolated per-user Data Encryption Keys (DEKs) using AES-256-GCM, TLS 1.3 transit encryption, cryptographic password hashing with per-user salts, and instantaneous crypto-shredding upon account termination.
7. **Retention Limitation Obligation (§ 25):** We cease retention of personal data as soon as the purpose for collection is no longer served and retention is no longer necessary for legal or operational purposes. In-app and web account deletion immediately shreds encryption keys and purges active database records, with immutable backup archives aged and overwritten within a 30-day lifecycle.
8. **Transfer Limitation Obligation (§ 26 - Cross-Border Transfers):** Disclosed in subsection C below.
9. **Accountability Obligation (§ 11 & § 12):** We maintain comprehensive data protection policies, documented encryption architecture, immutable deletion audit logs (`deletion_audit_log`), and an appointed DPO to ensure ongoing compliance.

### C. Cross-Border Data Transfers & Comparable Protection (§ 26)
While SancFund is managed from Singapore, delivering a resilient cloud service requires engaging specialized cloud infrastructure sub-processors located outside Singapore:
- **Supabase Cloud Infrastructure:** Primary encrypted PostgreSQL datastores and file storage are hosted on AWS in Asia-Pacific (Singapore `ap-southeast-1` primary region, with secondary high-availability failover in the United States).
- **Cloudflare R2 Storage:** Disaster recovery backups and encrypted snapshots are stored on Cloudflare's distributed edge storage network across North America and Asia-Pacific.
- **Google Gemini API:** AI-assisted receipt vision OCR and natural language inference take place within Google Cloud data centers in the United States.

**Comparable Protection Safeguards:** In accordance with PDPA § 26 and Part 3 of the Personal Data Protection Regulations 2021, we ensure that every overseas recipient is legally bound by enforceable Data Processing Agreements (DPAs) or enterprise terms that provide a standard of protection comparable to that under the PDPA. Furthermore, all sensitive user data remains protected in transit via TLS 1.3 and at rest via envelope encryption (AES-256-GCM), ensuring overseas hosting providers hold only encrypted ciphertext without access to decryption keys.

### D. Mandatory Data Breach Notification (§ 26A–§ 26E)
In the event of a data security incident, SancFund complies with the Personal Data Protection (Amendment) Act 2020:
- We will assess whether a security breach is a **notifiable data breach** (i.e. one that results in, or is likely to result in, significant harm to affected individuals, or involves 500 or more individuals).
- If notifiable, we commit to notifying the **Personal Data Protection Commission (PDPC)** and all affected individuals as soon as practicable and no later than **3 calendar days (72 hours)** after making the determination.

---

## 11. Your Rights under GDPR & UK Data Protection Laws

If you reside in the European Economic Area (EEA), the United Kingdom, or Switzerland, you have the following statutory rights under the GDPR / UK GDPR:
- **Right of Access:** Obtain confirmation of whether your personal data is being processed and receive a copy of that data.
- **Right to Rectification:** Request correction of inaccurate or incomplete personal information.
- **Right to Erasure ("Right to be Forgotten"):** Request the permanent deletion of your personal data.
- **Right to Data Portability:** Request an export of your transaction records in a structured, machine-readable format.
- **Right to Restrict or Object to Processing:** Request that we restrict or cease processing your data under certain circumstances.
- **Right to Lodge a Complaint:** Lodge a complaint with your national Data Protection Authority if you believe your rights have been infringed.

To exercise any of these rights, contact us at `fayrd06@gmail.com`.

---

## 12. Your Rights under California Law (CCPA / CPRA & CalOPPA)

If you are a California resident, the CCPA/CPRA provides you with specific privacy protections:
- **Right to Know & Access:** Request information on the categories and specific pieces of personal information collected, used, and disclosed.
- **Right to Delete:** Request deletion of personal information collected from you.
- **Right to Correct:** Request correction of inaccurate personal information.
- **Right to Opt-Out of Sale or Sharing:** We do not sell or share personal information for cross-context behavioral advertising.
- **Non-Discrimination:** We will never discriminate against you (e.g., through price differences or degraded quality) for exercising your legal privacy rights.

---

## 13. Children's Privacy

SancFund is not intended for individuals under the age of **13** (or **16** in the European Economic Area and United Kingdom). We do not knowingly collect personal information from children. If we discover that a child has provided us with personal information, we will take immediate steps to delete such data.

---

## 14. Changes to This Privacy Policy

We may update this Privacy Policy periodically to reflect enhancements to our Service, technological updates, or changes in legal requirements. Material changes will be communicated via in-app notifications or by updating the "Last Updated" date at the top of this document.

---

## 15. Contact Us

If you have questions, feedback, or requests regarding this Privacy Policy or our data protection practices, please contact us:

- **Designated Data Protection Officer (DPO):** Data Protection Officer, SancFund
- **DPO Email & Legal Inquiries:** `fayrd06@gmail.com`
- **Customer Support:** `fayrd06@gmail.com`
- **In-App Navigation:** `Settings -> Legal & Compliance -> Privacy Policy`
- **Web Deletion Portal:** `https://sancfund.effoc.org/delete-account`

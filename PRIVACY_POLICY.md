# Privacy Policy for Household Docs App

**Last Updated: December 8, 2025**

## Introduction

Household Docs App ("we", "our", or "the app") is committed to protecting your privacy. This Privacy Policy explains how we handle your information when you use our mobile application, including our optional premium cloud synchronization features.

## Information We Collect

### For Free Users (Local Storage Only)

The app stores the following information locally on your device:

- **Document Information**: Titles, categories, notes, and creation dates of documents you create
- **File Attachments**: References to files you attach to documents (the actual files remain in their original location on your device)
- **Renewal Dates**: Dates you set for document renewals or payment due dates
- **Notification Preferences**: Settings for renewal reminders

### For Premium Users (Cloud Sync Enabled)

If you purchase a premium subscription and enable cloud synchronization, we collect and store:

- **Account Information**: Email address for authentication and account management
- **Document Metadata**: Titles, categories, notes, creation dates, and modification timestamps
- **File Attachments**: The actual files you attach to documents (stored encrypted in AWS S3)
- **Sync Information**: Device identifiers, sync timestamps, and sync status
- **Subscription Information**: Subscription status, purchase receipts, and billing period

### Information We Do NOT Collect

- We do **NOT** access or analyze the content of your documents for any purpose other than synchronization
- We do **NOT** share your information with third parties for marketing purposes
- We do **NOT** track your usage or behavior for advertising
- We do **NOT** use analytics or tracking tools beyond basic error reporting

## How We Use Your Information

### Free Users

All information you enter into the app is used solely for the following purposes:

1. **Document Management**: To display and organize your household documents
2. **File Access**: To allow you to view and open your attached files
3. **Reminders**: To send you local notifications about upcoming renewal dates
4. **Search and Filter**: To help you find specific documents by category

### Premium Users

For users with cloud synchronization enabled, we additionally use your information for:

1. **Authentication**: To verify your identity and secure access to your cloud data
2. **Synchronization**: To keep your documents consistent across all your devices
3. **Backup**: To provide secure cloud backup of your documents and files
4. **Conflict Resolution**: To detect and help resolve conflicts when the same document is edited on multiple devices
5. **Storage Management**: To track your storage usage and enforce quota limits

**We do NOT access or analyze the content of your documents for any purpose other than providing synchronization services.**

## Data Storage

### Free Users - Local Storage Only

- All data is stored exclusively on your device using SQLite database
- No data is transmitted over the internet
- No cloud backup or synchronization occurs
- Your data never leaves your device

### Premium Users - AWS Cloud Storage

When you enable cloud synchronization, your data is stored in Amazon Web Services (AWS):

#### Document Metadata Storage
- **Service**: AWS DynamoDB (NoSQL database)
- **Location**: Your selected AWS region (typically closest to your location)
- **Encryption**: AES-256 encryption at rest
- **Access Control**: Restricted to your authenticated account only

#### File Attachment Storage
- **Service**: AWS S3 (Simple Storage Service)
- **Location**: Your selected AWS region
- **Encryption**: AES-256 encryption at rest
- **Access Control**: Private buckets with user-specific access policies

#### Authentication
- **Service**: AWS Cognito
- **Purpose**: Secure user authentication and authorization
- **Data Stored**: Email address, encrypted password hash, authentication tokens

### File Access

- The app only accesses files you explicitly select through the file picker
- File paths are stored to allow you to reopen files later
- The app does not scan, modify, or access any other files on your device

## Permissions

The app requires the following permissions:

### Storage/File Access
- **Purpose**: To allow you to select and attach files to your documents
- **Usage**: Only activated when you tap "Attach Files" button
- **Scope**: Limited to files you explicitly select

### Notifications
- **Purpose**: To send you reminders about upcoming renewal dates
- **Usage**: Only for documents where you've set a renewal date
- **Control**: You can disable notifications in your device settings

## Data Security

### Local Security (All Users)
- Your data is protected by your device's security measures (PIN, password, biometric authentication)
- We recommend keeping your device locked and secure
- Local data is stored in the app's private storage area, inaccessible to other apps

### Cloud Security (Premium Users)

We implement industry-standard security measures to protect your data:

#### Encryption in Transit
- **Protocol**: TLS 1.3 (Transport Layer Security)
- **Purpose**: All data transmitted between your device and AWS is encrypted
- **Protection**: Prevents interception and eavesdropping during transmission

#### Encryption at Rest
- **Algorithm**: AES-256 (Advanced Encryption Standard)
- **Scope**: All documents and files stored in AWS are encrypted
- **Key Management**: AWS manages encryption keys using AWS Key Management Service (KMS)

#### Access Control
- **Authentication**: AWS Cognito verifies your identity before allowing access
- **Authorization**: IAM (Identity and Access Management) policies enforce least-privilege access
- **Isolation**: Your data is isolated from other users and cannot be accessed by anyone else

#### Security Monitoring
- AWS provides continuous security monitoring and threat detection
- We follow AWS security best practices and compliance standards
- Regular security updates are applied to all infrastructure components

## Your Rights and Control

You have complete control over your data:

### Access
- You can view all your documents and information within the app at any time
- Premium users can access their data from any connected device

### Modification
- You can edit or update any document information
- You can add or remove file attachments
- Changes sync automatically across all your devices (premium users)

### Deletion
- You can delete individual documents at any time
- Deleting a document removes it from the app's database
- For premium users, deleted documents are removed from cloud storage
- Note: Deleting a document does not delete the original files from your device

### Account Deletion (Premium Users)
If you wish to delete your premium account and all associated data:
1. Contact us through the app or app store to request account deletion
2. We will permanently delete all your data from AWS within **30 days**
3. This includes:
   - All document metadata from DynamoDB
   - All file attachments from S3
   - Your authentication information from Cognito
   - All sync history and device registrations
4. This action is **irreversible** - deleted data cannot be recovered

### Complete Data Removal (Free Users)
To completely remove all app data:
1. Uninstall the app from your device
2. This will delete the app's database and all document information
3. Your original files will remain on your device

## Children's Privacy

The app does not knowingly collect information from children under 13. The app is designed for household document management and is suitable for all ages. Since all data is stored locally and no information is collected or transmitted, there are no special privacy concerns for children using the app.

## Third-Party Services

### No Third-Party Data Sharing
- We do not share your document content with third parties
- We do not sell or rent your personal information
- We do not use third-party analytics services for tracking
- We do not display advertisements

### Amazon Web Services (AWS) - Premium Users Only

For premium cloud synchronization, we use Amazon Web Services (AWS):

- **Purpose**: Secure cloud storage and synchronization infrastructure
- **Services Used**: 
  - AWS Cognito (authentication)
  - AWS DynamoDB (document metadata storage)
  - AWS S3 (file attachment storage)
- **Data Processing**: AWS processes your data solely for providing synchronization services
- **AWS Privacy**: AWS complies with industry-standard privacy and security certifications (SOC 2, ISO 27001, GDPR)
- **Data Location**: Your data is stored in AWS data centers in your selected region
- **AWS Access**: AWS does not access your document content; they only provide infrastructure

### Payment Processing - Premium Users Only

- **In-App Purchases**: Processed by Google Play Store or Apple App Store
- **Information Shared**: Purchase receipts are shared with us to verify subscription status
- **Payment Details**: We do not receive or store your credit card or payment information
- **Privacy Policies**: Subject to Google's and Apple's respective privacy policies

### Third-Party Libraries
The app uses the following open-source libraries for functionality:
- **Flutter Framework**: For app development
- **SQLite (sqflite)**: For local database storage
- **file_picker**: For selecting files from your device
- **open_file**: For opening files with system default apps
- **flutter_local_notifications**: For scheduling local notifications
- **AWS Amplify**: For cloud synchronization (premium users only)

These libraries operate locally on your device or connect only to AWS services (for premium users).

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time. Any changes will be reflected in the "Last Updated" date at the top of this policy. Continued use of the app after changes constitutes acceptance of the updated policy.

## Data Retention

### Free Users
- Data is retained on your device until you delete it or uninstall the app
- There is no automatic data deletion or expiration
- You control how long your data is stored

### Premium Users

#### Active Subscription
- Your data is retained in AWS cloud storage as long as your subscription is active
- You can delete individual documents or files at any time
- Deleted items are permanently removed from cloud storage

#### Subscription Cancellation
- If you cancel your subscription, your data remains accessible until the end of your billing period
- After subscription expiration, your data remains in cloud storage for **30 days** (grace period)
- During the grace period, you can reactivate your subscription to regain access
- After 30 days, if you do not reactivate, your data is permanently deleted from AWS

#### Account Deletion
- If you request account deletion, all your data is permanently deleted from AWS within **30 days**
- This includes all documents, files, and account information
- Deletion is irreversible and data cannot be recovered

#### Inactive Devices
- Devices that haven't synced in 90 days are marked as inactive
- Inactive devices can be removed from your account
- Removing a device does not delete your documents, only the device registration

## International Users

### Free Users
Since all data is stored locally on your device and no data is transmitted:
- There are no cross-border data transfers
- No data residency concerns
- GDPR, CCPA, and other privacy regulations are not applicable as no personal data is collected or processed by us

### Premium Users

#### Data Location
- Your data is stored in AWS data centers in your selected region
- You can choose the AWS region closest to your location during setup
- Data does not leave the selected AWS region except for synchronization to your devices

#### GDPR Compliance (European Users)
If you are located in the European Economic Area (EEA):
- You have the right to access your personal data
- You have the right to rectify inaccurate data
- You have the right to erasure ("right to be forgotten")
- You have the right to data portability
- You have the right to restrict processing
- You have the right to object to processing
- You can exercise these rights by contacting us through the app

#### CCPA Compliance (California Users)
If you are a California resident:
- You have the right to know what personal information we collect
- You have the right to delete your personal information
- You have the right to opt-out of the sale of personal information (we do not sell personal information)
- You have the right to non-discrimination for exercising your rights

#### Cross-Border Transfers
- Data is transferred between your devices and AWS data centers using encrypted connections
- AWS complies with international data transfer regulations
- We use AWS regions that comply with local data protection laws

## Contact Information

If you have questions about this Privacy Policy or the app's privacy practices, you can:

- Review the app's source code (if open source)
- Contact the developer through the app store listing
- Submit issues or questions through the app's support channels

## Your Consent

By using the Household Docs App, you consent to this Privacy Policy.

## Summary

### For Free Users

**In Plain English:**

- ✅ All your data stays on your device
- ✅ We don't collect, transmit, or share any information
- ✅ No internet connection required for the app to work
- ✅ You have complete control over your data
- ✅ No accounts, no tracking, no analytics
- ✅ Your documents and files are private and secure

**What We Know About You:** Nothing. We literally cannot see your data because it never leaves your device.

### For Premium Users (Cloud Sync)

**In Plain English:**

- ✅ Your data is encrypted in transit (TLS 1.3) and at rest (AES-256)
- ✅ Stored securely in AWS with industry-standard security
- ✅ We do NOT access or analyze your document content
- ✅ You can delete your account and all data within 30 days
- ✅ Your data is isolated and accessible only to you
- ✅ No sharing with third parties for marketing
- ✅ Compliant with GDPR, CCPA, and international privacy laws

**What We Know About You:** Your email address and the metadata of your documents (titles, dates, categories). We do NOT read or analyze the content of your documents or files.

---

**This privacy policy reflects the app's current functionality with optional premium cloud synchronization features powered by AWS.**

# Household Documents App

A Flutter mobile app for managing household documents like insurance policies and mortgages with renewal reminders.

## Features

- Store documents for Home Insurance, Car Insurance, Mortgages, and more
- Attach files to each document
- Set renewal dates with automatic reminders
- Filter documents by category
- **Upcoming Renewals** - View all documents due within the next 30 days
- Visual alerts for urgent renewals (7 days or less)
- SQLite local database storage

## Getting Started

### Prerequisites

- Flutter SDK (3.0.6 or higher)
- Android Studio / Xcode for mobile development
- A physical device or emulator

### Installation

1. Navigate to the project directory:
```bash
cd household_docs_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Platform-Specific Setup

#### Android
For notifications to work, ensure your `android/app/src/main/AndroidManifest.xml` includes notification permissions.

#### iOS
For file picker and notifications, ensure proper permissions are set in `ios/Runner/Info.plist`.

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/
│   └── document.dart                  # Document data model
├── services/
│   ├── database_service.dart          # SQLite database operations
│   └── notification_service.dart      # Local notifications
└── screens/
    ├── home_screen.dart               # Main screen with document list
    ├── add_document_screen.dart       # Add new document form
    └── document_detail_screen.dart    # View document details
```

## Usage

1. Tap the + button to add a new document
2. Fill in the title, category, and optional renewal date
3. Attach a file if needed
4. View all documents on the home screen
5. Filter by category using the chips at the top
6. Tap the notification bell icon or the banner to view upcoming renewals
7. Tap a document to view details or delete it

## Next Steps

To enable notifications:
1. Initialize the notification service in `main.dart`
2. Request notification permissions on app start
3. Schedule reminders when documents with renewal dates are created

## License

This project is open source and available for personal use.

# PayPoint POS 💳

A modern, cross-platform Point of Sale (POS) application built with Flutter. PayPoint POS provides a complete retail management solution with offline-first capabilities and cloud synchronization.

![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?style=flat&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=flat&logo=supabase&logoColor=white)
![License](https://img.shields.io/badge/License-Private-red?style=flat)

---

## ✨ Features

### 📦 Product Management
- Add, edit, and delete products with barcode support
- Barcode scanning using device camera
- Organize products with categories
- Track inventory levels

### 🛒 Point of Sale
- Intuitive POS interface for quick sales
- Cart management with quantity adjustments
- Multiple payment method support
- Modern glassmorphism UI design

### 💰 Sales & Transactions
- Complete sales history with detailed views
- Day-wise cash book reports
- PDF invoice generation and sharing
- Sales analytics and reporting

### 📊 Financial Management
- Expense tracking and categorization
- Comprehensive ledger system
- Daily, weekly, and monthly reports
- Revenue and profit analytics

### 🔐 Authentication & Security
- Secure user authentication via Supabase
- Organization/Shop management
- Multi-user support with role-based access

### ☁️ Cloud & Offline Support
- Offline-first architecture with local SQLite database
- Real-time cloud synchronization with Supabase
- Connectivity status monitoring
- Seamless data sync across devices

---

## 🏗️ Project Structure

```
lib/
├── config/              # App configuration (Supabase, etc.)
├── database/            # Local SQLite database helpers
├── models/              # Data models
│   ├── expense.dart
│   ├── organization.dart
│   ├── product.dart
│   ├── sale.dart
│   ├── sale_item.dart
│   └── user.dart
├── providers/           # State management (Provider)
│   ├── auth_provider.dart
│   ├── cart_provider.dart
│   ├── expense_provider.dart
│   ├── product_provider.dart
│   ├── sales_provider.dart
│   └── sync_provider.dart
├── screens/             # UI screens
│   ├── add_expense_screen.dart
│   ├── add_product_screen.dart
│   ├── barcode_scanner_screen.dart
│   ├── day_cashbook_screen.dart
│   ├── expenses_screen.dart
│   ├── home_screen.dart
│   ├── ledger_screen.dart
│   ├── login_screen.dart
│   ├── main_navigation_screen.dart
│   ├── payment_screen.dart
│   ├── pos_screen.dart
│   ├── products_screen.dart
│   ├── register_screen.dart
│   ├── reports_screen.dart
│   ├── sale_detail_screen.dart
│   ├── sales_history_screen.dart
│   └── settings_screen.dart
├── services/            # Business logic services
│   ├── auth_service.dart
│   ├── connectivity_service.dart
│   ├── pdf_service.dart
│   ├── supabase_service.dart
│   └── sync_service.dart
└── main.dart            # App entry point
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.10.3 or higher)
- [Dart SDK](https://dart.dev/get-dart) (3.10.3 or higher)
- A [Supabase](https://supabase.com/) account and project

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/paypoint_mobile.git
   cd paypoint_mobile
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   
   Create or update `lib/config/supabase_config.dart`:
   ```dart
   class SupabaseConfig {
     static const String supabaseUrl = 'YOUR_SUPABASE_URL';
     static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   }
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 📱 Supported Platforms

| Platform | Status |
|----------|--------|
| Android  | ✅ Supported |
| iOS      | ✅ Supported |
| Windows  | ✅ Supported |
| macOS    | ✅ Supported |
| Linux    | ✅ Supported |
| Web      | ✅ Supported |

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.10+ |
| **Language** | Dart 3.10+ |
| **State Management** | Provider |
| **Backend** | Supabase |
| **Local Database** | SQLite (sqflite) |
| **PDF Generation** | pdf, printing |
| **Barcode Scanning** | mobile_scanner |
| **Network** | http, connectivity_plus |
| **Storage** | shared_preferences |

---

## 📦 Dependencies

```yaml
dependencies:
  # State Management
  provider: ^6.1.1
  
  # Local Database
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0
  path_provider: ^2.1.1
  
  # Backend
  supabase_flutter: ^2.0.0
  connectivity_plus: ^5.0.2
  http: ^0.13.4
  
  # PDF & Printing
  pdf: ^3.10.7
  printing: ^5.11.1
  
  # Utilities
  intl: ^0.18.1
  uuid: ^4.2.2
  share_plus: ^7.2.1
  mobile_scanner: ^5.1.1
```

---

## 🔧 Development Commands

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release

# Build for Windows
flutter build windows --release

# Run tests
flutter test

# Analyze code
flutter analyze
```

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the issues page.

---

## 📄 License

This project is private and not available for public distribution.

---

## 👨‍💻 Author

**PayPoint Mobile Team**

---

<p align="center">
  Made with ❤️ using Flutter
</p>

# SplitWise Smart - Group Expense Splitter & Debt Simplification

An offline-first, mobile-first Flutter application tailored for group trips and outings. It tracks shared expenses and uses graph theory algorithms to minimize the total number of transactions needed to settle all debts.

Live Demo: https://scintillating-tartufo-71fcd6.netlify.app

---

## Key Features

- **Smart Debt Simplification Algorithm**:
  - Computes net balance vectors (Total Paid - Total Owed + Total Settled).
  - Uses bipartite greedy matching and exact zero-sum subset pairing to reduce complex web debts into the minimum possible transactions (O(N log N)).
  - Guarantees at most N - 1 payments to resolve all debts.
- **Connected Subgraph Partitioning (No Stranger Debts)**:
  - Partitions debts across connected interaction subgraphs so separate excursion groups never cross-contaminate.
- **100% Offline-First Architecture**:
  - High-speed local persistence using Hive NoSQL storage with an in-memory fault-tolerant fallback.
- **Multi-Currency with Zero-Drift Closure**:
  - Support for USD, EUR, EGP, GBP, AED, SAR, CAD, and JPY.
  - Settle in local cash with "Full Settlement" closure that eliminates rounding dust.
- **Linked Settlements (No Ghost Debt Inversions)**:
  - Deleting an expense automatically cascades to attached settlements, preserving net balance integrity.
- **Dynamic Perspective Switcher**:
  - Switch active member perspectives in one click to view the app through any friend's eyes.
- **Receipt Scanner (OCR)**:
  - Interactive laser HUD scanner with real-world presets and auto-export into expense entry.
- **Spending Analytics**:
  - Custom canvas donut chart showing category breakdown (Food, Stay, Transport, Activities).
- **Dark and Light Modes**:
  - Modern Material 3 high-contrast palette (Indigo, Emerald, Rose, Slate).

---

## Architecture & Project Structure

The project follows Clean Architecture (Feature-First) and SOLID principles:

```
lib/
├── main.dart                                # MultiProvider wiring & Material 3 theme configuration
├── core/
│   ├── constants/                           # AppColors, AppTheme, AppConstants
│   ├── providers/                           # ThemeProvider
│   ├── utils/                               # CurrencyFormatter, DateFormatter
│   └── widgets/                             # AvatarWidget, SpendingDonutChart, EmptyStateWidget
├── database/                                # HiveBoxes, LocalStorageService
└── features/
    ├── auth_user/                           # User Profile & Perspective Switcher
    ├── groups/                              # Trip & Member Management, Dashboard, Trip Details
    ├── expenses/                            # Expense Logging, Multi-Payer & Dynamic Split Modes
    ├── debt_simplification/                 # Greedy Debt Simplifier, Debt Resolution Screen, Settle Dialog
    ├── ocr_scanner/                         # Receipt Scanner Screen & Parser Service
    └── seed_data/                           # Preloaded Demo Data (Dahab Trip, Dinners)
```

---

## Getting Started

### Prerequisites
- Flutter SDK (3.10.0 or later)
- Dart SDK (3.0.0 or later)

### Installation & Local Run

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY

# 2. Install dependencies
flutter pub get

# 3. Run unit tests
flutter test test/debt_simplifier_test.dart

# 4. Launch the application
flutter run
```

---

## Running the Unit Tests

The test suite covers algorithmic edge cases including circular debts, zero balances, disjoint connected components, exact subset matching, and multi-currency zero-drift settlements:

```bash
flutter test test/debt_simplifier_test.dart
```

---

## Building for Production

```bash
# Build for Web
flutter build web --release

# Build Android APK
flutter build apk --release

# Build Android App Bundle (Google Play)
flutter build appbundle --release

# Build Windows Desktop
flutter build windows --release
```

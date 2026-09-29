# 📸 Rate My Stuff

**Rate My Stuff** is an AI-powered Flutter application that analyzes, rates, and reviews your photos in real-time. Whether it's an outfit, a plate of food, a gaming setup, or a pet, **Rate My Stuff** uses multimodal Vision AI models to give you an honest 1.0 to 10.0 rating accompanied by witty roasts for bad photos or top-tier compliments for great ones!

---

## ✨ Key Features

- 🤖 **Dual-Engine AI Pipeline**:
  - **Primary**: Multi-key round-robin rotation via **Groq** (`qwen/qwen3.8-27b` vision model).
  - **Fallback**: Seamless failover to **Google Gemini 2.5 Flash** (`gemini-3.8-flash`).
- 🎯 **Smart Compliment vs. Roast AI Prompting**:
  - **Top-Tier Compliments**: High-quality, impressive photos receive genuine, glowing praise.
  - **Savage Roasts**: Low-effort or messy photos get hilarious, Gen-Z roasts.
- 🌐 **Multi-Language Vision Intelligence**:
  - Detects multilingual context or text inside photos and responds in the user's expected language.
- 📷 **Custom Live Camera & Gallery Picker**:
  - Features real-time camera preview with aspect ratio locking, flash control, front/back camera toggling, and device brightness adjustment.
- 🔒 **Encrypted Local Storage & History**:
  - Securely stores rating history and encrypted images on-device using **SQLCipher** and local cryptographic keys.
- ⚡ **Resiliency & Auto-Cooldown**:
  - Instant offline detection before hitting network endpoints.
  - Intelligent cooldown management for throttled (`429`) or unauthorized (`401`/`403`) API keys.
- 🎨 **Modern Glassmorphic UI**:
  - Smooth scanner overlay animations, dynamic category spotlight cards, interactive bottom sheets, and full sharing options via `share_plus`.

---

## 🛠️ Tech Stack & Dependencies

- **Framework**: [Flutter](https://flutter.dev/) (Dart SDK `^3.10.7`)
- **AI / Multimodal LLM**:
  - `google_generative_ai` (Gemini API)
  - `http` (Groq OpenAI-compatible Vision API endpoints)
- **Local Database & Security**:
  - `sqflite` / `sqflite_sqlcipher` (Encrypted SQLite Database)
  - `flutter_secure_storage` & `cryptography`
- **Media & Hardware**:
  - `camera` (Live camera preview & capture)
  - `image_picker` & `gal` (Gallery access & media saving)
  - `screen_brightness`
- **Utilities**:
  - `flutter_dotenv` (Environment variable management)
  - `share_plus` (Social sharing)
  - `path_provider` & `path`

---

## 📁 Project Architecture

```
lib/
├── main.dart                  # Application entry point & theme configuration
├── models/
│   ├── rating_category.dart    # Preset categories (Fashion, Food, Tech, Pets, etc.)
│   ├── rating_history_item.dart# Data model for stored scan history
│   └── scan_error.dart         # Custom scan exception definitions
├── screens/
│   ├── home_screen.dart        # Main dashboard with category spotlights & quick scan
│   ├── camera_capture_screen.dart # Custom camera interface with controls
│   ├── scanning_screen.dart    # Live scanning state & processing animation
│   ├── result_screen.dart      # Rating reveal screen with animations & share options
│   ├── history_screen.dart     # Searchable & filterable saved rating history
│   └── category_picker_sheet.dart # Category selection modal
├── services/
│   ├── ai_rating_service.dart  # Groq & Gemini Vision AI integration & key failover
│   ├── database_helper.dart    # SQLCipher database setup & CRUD operations
│   ├── encryption_service.dart # AES encryption for local stored images
│   └── rate_limit_service.dart # Key cooldowns & network throttle management
└── widgets/
    ├── category_spotlight_card.dart
    ├── encrypted_image_widget.dart
    ├── how_it_works_card.dart
    └── real_rating_card.dart
```

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.10.7 or higher)
- Android Studio / VS Code with Flutter extension
- An active **Groq API Key** and/or **Google Gemini API Key**

### 2. Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Gamvir-Khanal/Rate_My_Stuff.git
   cd Rate_My_Stuff
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables**:
   Create a `.env` file in the root directory of the project (or edit the existing `.env` file):

   ```env
   # Primary Vision Provider: Groq API Keys (Supports up to 20 keys for round-robin rotation)
   GROQ_API_KEY_1=gsk_your_groq_key_1
   GROQ_API_KEY_2=gsk_your_groq_key_2
   GROQ_MODEL=qwen/qwen3.8-27b

   # Fallback Vision Provider: Gemini API Keys (Supports up to 5 keys)
   GEMINI_API_KEY_1=your_gemini_api_key_1
   GEMINI_API_KEY_2=your_gemini_api_key_2
   ```

4. **Run the Application**:
   ```bash
   flutter run
   ```

---

## 🔒 Security & Privacy

- **Data Locality**: All photos and rating histories are stored locally on your device in an encrypted **SQLCipher** database.
- **Image Protection**: Captured images are encrypted using AES symmetric encryption before being written to disk.
- **No Third-Party Tracking**: API calls are made directly to official provider endpoints (Groq / Google Cloud) solely for image rating generation.


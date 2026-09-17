---
description: Detailed step-by-step workflow for the MindMate+ project.
---

# 🧠 MindMate+ Project Workflow

This document provides a detailed, step-by-step guide to setting up, running, and maintaining the MindMate+ ecosystem.

---

## 🏗️ System Overview
MindMate+ is a multi-platform assistive intelligence system consisting of:
1.  **AI Microservice**: Python FastAPI server for face recognition.
2.  **Patient App**: Flutter app for patients (face scanner, map, reminders).
3.  **Caregiver App**: Flutter app for caregivers (monitoring, registration).
4.  **Admin App**: Flutter app for administration.
5.  **Supabase**: Centralized database and authentication.
6.  **Firebase**: Push notifications (FCM) and background tasks.

---

## 🛠️ Step-by-Step Setup

### 1. Database & Backend (Supabase)
1.  **Create Project**: Go to [Supabase](https://supabase.com/) and create a new project.
2.  **Run Schema**: Open the **SQL Editor** in Supabase and execute the contents of `database_schema.sql` (found in the root folder). This creates all tables and RLS policies.
3.  **Configure Buckets**: Ensure `photos` and `audio_messages` buckets are created in Supabase Storage and set to **Public**.
4.  **Get Credentials**: Copy the `Project URL` and `anon` key from Project Settings > API.

### 2. AI Microservice (Python)
1.  **Navigate**: `cd ai_microservice`
2.  **Environment**: 
    ```bash
    python -m venv venv
    .\venv\Scripts\activate  # Windows
    source venv/bin/activate # Mac/Linux
    ```
3.  **Dependencies**:
    - Ensure you have **CMake** and **VS C++ Build Tools** installed (for `dlib`).
    - `pip install -r requirements.txt`
4.  **Configure**: Update `SUPABASE_URL` and `SUPABASE_KEY` in `main.py`.
5.  **Run**: `python main.py` (Starts on port 8000).

### 3. Flutter Applications
For each app (`mindmate_patient`, `mindmate_caregiver`, `mindmate_admin`):
1.  **Dependencies**: `flutter pub get`
2.  **Configure Supabase**: In `lib/main.dart`, update the `Supabase.initialize` call with your credentials.
3.  **Configure Firebase**: 
    - Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
    - Run `flutterfire configure` in each app directory to link your Firebase project.
4.  **Configure AI IP**: If testing on a physical device, run `.\Start-MindMate.ps1` to automatically map your local IP.

---

## 🏃 Running the Project

### Phase 1: Start the Backend
1.  Run the PowerShell automation script:
    ```powershell
    .\Start-MindMate.ps1
    ```
    *This script detects your IP, updates the Patient app config, and starts the AI Microservice.*

### Phase 2: Launch Apps
1.  **Patient App**:
    ```bash
    cd mindmate_patient
    flutter run
    ```
2.  **Caregiver App**:
    ```bash
    cd mindmate_caregiver
    flutter run
    ```
3.  **Admin App**:
    ```bash
    cd mindmate_admin
    flutter run
    ```

---

## 📦 Building for Production

### Android Build (APK/AAB)
1.  Prepare your `key.properties` for signing.
2.  Run the build command:
    ```bash
    flutter build apk --release
    ```
    *The output will be in `build/app/outputs/flutter-apk/app-release.apk`.*

### iOS Build
1.  Open `ios/Runner.xcworkspace` in Xcode.
2.  Configure Signing & Capabilities.
3.  Run `flutter build ios --release`.

---

## 🧪 Testing Face Recognition
1.  Log into the **Caregiver App**.
2.  Navigate to **Add Known Person**.
3.  Upload a clear photo of a family member.
4.  Log into the **Patient App** with the associated patient account.
5.  Open **Face Scanner** and point at the person.
6.  The app should identify the person and announce their name/relation.

---

## 🔧 Troubleshooting
-   **"Connection Refused"**: Ensure the phone and laptop are on the same Wi-Fi. Check if the IP in `api_config.dart` matches your computer's IP.
-   **"No Face Detected"**: Ensure good lighting and that the face is fully within the round overlay.
-   **Background Service Not Working**: Ensure you've granted "Always Allow" location permission and "Unrestricted" battery usage for the app.

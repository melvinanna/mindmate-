# 🏃 MindMate+ Running Guide

This document explains the steps to run your Flutter apps and connect your physical phone/emulator to your computer's local AI microservice effortlessly.

## The "Dynamic IP" Problem
When testing a mobile app on a physical device, the phone cannot connect to `localhost` or `127.0.0.1` because the phone treats "localhost" as the phone itself, not your computer. 

To fix this, the app requires your laptop's **local Wi-Fi IP Address** (e.g., `192.168.1.5`). However, since router IPs change randomly, updating the code manually every single time is painful.

## The Solution: Automatic Setup! 🚀

I've created an automated PowerShell script (`Start-MindMate.ps1`) that completely handles this mapping for you. 

### Step 1: Run the Automation Script
1. Ensure your **Laptop/Computer** and **Mobile Phone** are connected to the EXACT Same Wi-Fi Network.
2. Open PowerShell or Terminal in your project root (`C:\Jithin\MindMateNew`).
3. Run the following command:
   ```powershell
   .\Start-MindMate.ps1
   ```

**What the script does automatically:**
- Identifies your current computer IP address.
- Injects this IP properly into `mindmate_patient\lib\api_config.dart`.
- Installs Python requirements if missing.
- Boots up the Python FastAPI Microservice (`ai_microservice`) on your computer, listening on your network.

### Step 2: Leave it running
Do not close the PowerShell window where `uvicorn` or the FastAPI server is running. It must stay active to process images from the mobile app.

### Step 3: Start the Flutter App
While the server is running, open a **new** terminal (or run from VS Code/Android Studio).
Navigate into your patient application folder:

```bash
cd mindmate_patient
flutter run
```

When the Flutter app launches on your phone, you can now click **Face Scanner** or **Identify Person**. The app will automatically fire requests over your Wi-Fi to your laptop's newly updated IP address.

---

## 🔧 Database Details & Fixes applied:
- The backend `database_schema.sql` was checked, and a missing extension (`uuid-ossp`) was added so that Supabase tables will provision flawlessly without complaining about missing `uuid_generate_v4()`.
- The Face scanning HTTP post URL logic inside `face_scanner.dart` was thoroughly checked. The `ApiConfig.aiServiceUrl` setup correctly fetches from your base configuration. No logical bugs were found in the API connections.

Happy Coding! 🎉

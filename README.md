# 🧠 MINDMATE+
**An Assistive Intelligence Platform for Memory Recall**

MindMate+ is an AI-powered assistive platform developed to support individuals experiencing memory loss due to Alzheimer’s disease, brain injuries, or trauma. This system is designed to enhance patient independence, ensure safety, and reduce caregiver burden through intelligent monitoring and real-time assistance. MindMate+ integrates face recognition, voice interaction, reminders, and location tracking into a unified mobile and web-based solution.

---

## 🎯 Project Vision
To create a smart, reliable, and user-friendly assistive system that:
- Improves daily life for memory-impaired patients
- Strengthens communication between patients and caregivers
- Ensures safety through real-time monitoring
- Promotes emotional well-being and confidence

---

## 📊 Database Schema & Tables
The system relies on a central Supabase PostgreSQL database. The core tables include:
- **`tbl_patient`**: Stores patient profile information, safe zone parameters (latitude/longitude & radius), emergency statuses, and caregiver associations.
- **`tbl_caregiver`**: Stores caregiver credentials, contact info, and profile details.
- **`tbl_known_person`**: Crucial for the AI models. Stores the names, relations, image URLs (from Supabase Storage buckets), and optional voice message URLs of familiar individuals for each patient.
- **`tbl_reminder`**: Stores schedules for medication, physical activities, and routines to trigger local notifications and voice prompts on the patient's device.
- **`tbl_location_history`**: Tracks historical GPS data points for patients to identify wandering or exit events from their defined Safe Zone.

Check `database_schema.sql` at the root folder to easily spin up these required tables in your Supabase project.

---

## 🤖 AI Model & Algorithm Used

The **Face Recognition & Identification engine** runs on a dedicated Python FastAPI Microservice. 

### Algorithms & Architecture:
1. **Face Detection**: Uses **HOG (Histogram of Oriented Gradients)** combined with a Linear SVM to accurately find bounding boxes of faces in real-time, even on mobile images.
2. **Face Alignment & Extraction**: Detected faces are aligned using a facial landmark estimator (finding eyes, nose, and mouth) to standardize the crop.
3. **Face Embedding (Deep Learning)**: The aligned face is passed through a **Deep Convolutional Neural Network (CNN)**—specifically a ResNet architecture trained on a massive dataset of faces. This generates a **128-dimensional face encoding vector**.
4. **Classification & Matching**: We use the **Euclidean Distance (L2 norm)** to compare the 128-d encoding of the new face against the encoded known faces associated with the patient. A distance threshold of `0.6` is used; anything below this threshold is considered an authentic match.

---

## 📸 How Face Recognition Works in MindMate+

The pipeline is split into two phases across the Caregiver and Patient applications:

### 1. Training Phase (Caregiver & Patient Apps)
- A caregiver logs into the **Caregiver App** and navigates to the "Face Training Portal".
- They select a Patient, capture or pick a photo from the gallery of a loved one, and fill in the Name and Relation.
- The image is uploaded to Supabase Storage, and the metadata is inserted into `tbl_known_person`.

### 2. Inference Phase (Patient App)
- When a patient encounters someone they don't recognize, they can open the **Patient App** and tap "Identify Person" or "Face Scanner".
- The app captures a photo and sends an HTTP POST request to the Python AI Microservice with the image and the `patient_id`.
- **Microservice Logic**:
  1. The Python microservice uses the `patient_id` to query `tbl_known_person` from Supabase.
  2. It downloads the images of all registered family/friends for that specific patient.
  3. It extracts the 128-d encodings and compares the new image to these stored images simultaneously.
  4. If a match is found, it returns the `person_id` of the match to the Flutter application.
- **User Experience**: The app receives the ID, queries the database for the person's specific profile, immediately shows their face, their name, their relation (e.g., "This is John, your Son"), and plays any associated voice tags or uses Text-to-Speech (TTS) to audibly announce the person.

---

## 🏃 Steps: How to Run This Project

This project consists of three Flutter applications and a Python AI microservice. Follow the steps below to get the entire ecosystem running on your local machine.

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed and configured
- [Python 3.8+](https://www.python.org/downloads/) installed (with CMake and Visual Studio C++ Build Tools installed if on Windows, for the `face_recognition` library)
- (Optional but Recommended) A physical device or Android Emulator / iOS Simulator
- Supabase account

### Step 1: Set Up the Database
1. Go to your Supabase project.
2. Open the SQL Editor and run the SQL statements found in `database_schema.sql` located at the root of the project to create the necessary tables and policies.
3. Replace the `anonKey` and `apiUrl` in all the Dart files (`main.dart` / `api_config.dart`) with your own Supabase project details.

### Step 2: Running the AI Microservice (Python)

The `ai_microservice` handles the intensive Machine Learning computations.

1. **Navigate to the AI Microservice directory**:
   ```bash
   cd ai_microservice
   ```

2. **Create a Virtual Environment** (Highly Recommended):
   ```bash
   python -m venv venv
   # On Windows
   venv\Scripts\activate
   # On macOS/Linux
   source venv/bin/activate
   ```

3. **Install Dependencies**:
   Note: The `face_recognition` package requires a C++ compiler to build `dlib`. Make sure you have CMake installed on your machine.
   ```bash
   pip install -r requirements.txt
   ```

4. **Start the FastAPI Server**:
   ```bash
   python main.py
   # OR
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```
   *The server will start running on `http://0.0.0.0:8000`.*

### Step 3: Running the Flutter Apps

There are three distinct Flutter apps tailored to different user roles: `mindmate_admin`, `mindmate_caregiver`, and `mindmate_patient`.

1. **Navigate to the desired app directory** (e.g., patient app):
   ```bash
   cd mindmate_patient
   ```

2. **Get Flutter Packages**:
   ```bash
   flutter pub get
   ```

3. **Run the Application**:
   ```bash
   flutter run
   ```
   *(Repeat for `mindmate_caregiver` and `mindmate_admin` to open the different portals as needed.)*

---

## 🔗 Connecting Local Microservice to Mobile Devices

If running on a physical Mobile device, `localhost` (127.0.0.1) won't work to connect to the computer's python server.

### Connecting via Android Emulator
Use the special alias `10.0.2.2` in `api_config.dart`:
```dart
static const String aiServiceUrl = "http://10.0.2.2:8000/analyze-face";
```

### Connecting via Physical Device
Ensure both your computer and your mobile device are on the **same Wi-Fi network**. 
1. Find your computer's IP address (`ipconfig` on Windows, `ifconfig` on Mac/Linux).
2. Update the endpoint in your Flutter code `api_config.dart`:
```dart
static const String aiServiceUrl = "http://<YOUR_IP_ADDRESS>:8000/analyze-face";
```
3. Run the Python server bound to `0.0.0.0` (as defined in `main.py`).

---
🌟 **MindMate+ completely developed and integrated for intelligent memory assistance.**

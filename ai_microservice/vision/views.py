import os
import requests
import uuid
import numpy as np
import cv2
import face_recognition
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

# Global caches to avoid re-encoding on every request
ENCODING_CACHE = {} 
TIMESTAMP_CACHE = {}

def health_check(request):
    return JsonResponse({"status": "AI Vision Engine (Django) is Online and Ready."})

@csrf_exempt
def analyze_face(request):
    if request.method != 'POST':
        return JsonResponse({"status": "error", "message": "Method not allowed"}, status=405)
        
    image_file = request.FILES.get("image")
    
    if not image_file:
        return JsonResponse({
            "status": "error",
            "match_found": False,
            "confidence": 0.0,
            "message": "Missing image upload."
        }, status=400)
        
    try:
        # 1. Setup local storage path
        path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "media", "Assets", "train")
        if not os.path.exists(path):
            os.makedirs(path)

        # 2. Get list of files
        myList = os.listdir(path)
        valid_files = [f for f in myList if f.lower().endswith(('.png', '.jpg', '.jpeg'))]

        encodeListKnown = []
        validClassNames = []

        # 3. Load or Calculate Encodings (with Caching)
        for fileName in valid_files:
            filePath = os.path.join(path, fileName)
            person_id = os.path.splitext(fileName)[0]
            
            # Check if file has changed since last encoding
            file_mtime = os.path.getmtime(filePath)
            
            if person_id in ENCODING_CACHE and TIMESTAMP_CACHE.get(person_id) == file_mtime:
                # Use cached encoding
                encodeListKnown.append(ENCODING_CACHE[person_id])
                validClassNames.append(person_id)
            else:
                # Re-calculate encoding
                curImg = cv2.imread(filePath)
                if curImg is not None:
                    img_rgb = cv2.cvtColor(curImg, cv2.COLOR_BGR2RGB)
                    encodes = face_recognition.face_encodings(img_rgb)
                    if encodes:
                        ENCODING_CACHE[person_id] = encodes[0]
                        TIMESTAMP_CACHE[person_id] = file_mtime
                        encodeListKnown.append(encodes[0])
                        validClassNames.append(person_id)

        if not encodeListKnown:
            return JsonResponse({
                "status": "success",
                "match_found": False,
                "confidence": 0.0,
                "message": "No valid registered faces found locally or failed to encode."
            })

        # 4. Process incoming image from Flutter
        file_bytes = image_file.read()
        nparr = np.frombuffer(file_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            return JsonResponse({
                "status": "success",
                "match_found": False,
                "confidence": 0.0,
                "message": "Failed to process uploaded image."
            })

        # Resize for faster processing
        imgS = cv2.resize(img, (0, 0), None, 0.25, 0.25)
        imgS = cv2.cvtColor(imgS, cv2.COLOR_BGR2RGB)
        
        facesCurFrame = face_recognition.face_locations(imgS)
        encodesCurFrame = face_recognition.face_encodings(imgS, facesCurFrame)

        if not encodesCurFrame:
            return JsonResponse({
                "status": "success",
                "match_found": False,
                "confidence": 0.0,
                "message": "No face detected in the image."
              })

        # 5. Compare with known faces
        best_match_name = None
        best_match_distance = 1.0

        for encodeFace in encodesCurFrame:
            faceDis = face_recognition.face_distance(encodeListKnown, encodeFace)
            
            if len(faceDis) > 0:
                matchIndex = np.argmin(faceDis)
                
                if faceDis[matchIndex] < 0.50: # Threshold of 0.50 for strictness
                    if faceDis[matchIndex] < best_match_distance:
                        best_match_distance = faceDis[matchIndex]
                        best_match_name = validClassNames[matchIndex]

        if best_match_name is not None:
            confidence = float(1.0 - best_match_distance)
            return JsonResponse({
                "status": "success",
                "match_found": True,
                "confidence": confidence,
                "message": "Match Found",
                "person_id": best_match_name
            })
        else:
            return JsonResponse({
                "status": "success",
                "match_found": False,
                "confidence": 0.0,
                "message": "No match found."
            })

    except Exception as e:
        print(f"Analyze Face Error: {e}")
        return JsonResponse({
            "status": "error",
            "match_found": False,
            "confidence": 0.0,
            "message": str(e)
        }, status=500)

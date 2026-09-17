import os
import requests
from django.core.management.base import BaseCommand
from supabase import create_client, Client

class Command(BaseCommand):
    help = 'Fetches known persons from Supabase and stores their images locally for face recognition'

    def handle(self, *args, **options):
        self.stdout.write("Connecting to Supabase to fetch known persons...")
        SUPABASE_URL = "https://disbpshtlcxhvzozplpb.supabase.co"
        SUPABASE_KEY = "sb_publishable_EDMIfGN40YB3NVojTYxBhQ_2n6QrHC1"
        
        try:
            supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
            
            # Fetch all known persons
            res = supabase.table("tbl_known_person").select("*").execute()
            known_persons = res.data

            if not known_persons:
                self.stdout.write(self.style.WARNING("No known persons found in the database."))
                return

            # Setup destination path matching Teacher app pattern
            path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), "media", "Assets", "train")
            if not os.path.exists(path):
                os.makedirs(path)
            else:
                # Clear existing files to prevent stale names (like "me.jpg") from breaking UUID lookups
                for f in os.listdir(path):
                    if os.path.isfile(os.path.join(path, f)):
                        os.remove(os.path.join(path, f))
                self.stdout.write("Cleared existing face cache.")

            count = 0
            for person in known_persons:
                person_id = person.get("id")
                img_url = person.get("image_url")

                if not img_url or not person_id:
                    continue

                self.stdout.write(f"Downloading image for ID {person_id}...")
                img_resp = requests.get(img_url)
                
                if img_resp.status_code == 200:
                    file_path = os.path.join(path, f"{person_id}.jpg")
                    
                    with open(file_path, "wb") as f:
                        f.write(img_resp.content)
                    
                    count += 1
                else:
                    self.stdout.write(self.style.ERROR(f"Failed to download image for ID {person_id}"))

            self.stdout.write(self.style.SUCCESS(f"Successfully synced {count} faces to local storage!"))

        except Exception as e:
            self.stdout.write(self.style.ERROR(f"Error syncing faces: {e}"))

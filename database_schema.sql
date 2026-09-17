-- MindMate+ Supabase Database Schema Full Dump
-- ----------------------------------------------------
-- WARNING: Executing this will clear all existing data
-- ----------------------------------------------------

-- DROP EXISTING TABLES AND POLICIES TO CLEAR DATA --
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
DROP TABLE IF EXISTS public.tbl_medicine CASCADE;
DROP TABLE IF EXISTS public.tbl_appointment CASCADE;
DROP TABLE IF EXISTS public.tbl_complaint CASCADE;
DROP TABLE IF EXISTS public.tbl_location_history CASCADE;
DROP TABLE IF EXISTS public.tbl_known_person CASCADE;
DROP TABLE IF EXISTS public.tbl_reminder CASCADE;
DROP TABLE IF EXISTS public.tbl_patient CASCADE;
DROP TABLE IF EXISTS public.tbl_caregiver CASCADE;
DROP TABLE IF EXISTS public.tbl_admin CASCADE;

-- 1. Caregiver Table
CREATE TABLE public.tbl_caregiver (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    caregiver_name TEXT NOT NULL,
    caregiver_email TEXT UNIQUE NOT NULL,
    caregiver_password TEXT,
    caregiver_phone TEXT,
    caregiver_status INTEGER DEFAULT 0, -- 0: Pending, 1: Active, 2: Blocked
    fcm_token TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_caregiver ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Caregivers all operations" ON public.tbl_caregiver FOR ALL USING (true) WITH CHECK (true);

-- 2. Patient Table
CREATE TABLE public.tbl_patient (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    caregiver_id UUID REFERENCES public.tbl_caregiver(id) ON DELETE CASCADE,
    patient_name TEXT NOT NULL,
    patient_email TEXT UNIQUE NOT NULL,
    patient_password TEXT,
    patient_phone TEXT,
    patient_age INTEGER,
    patient_gender TEXT,
    patient_medical_condition TEXT,
    patient_photo TEXT,
    patient_status INTEGER DEFAULT 1, -- 0: Inactive, 1: Active, 2: SOS
    fcm_token TEXT,

    safe_zone_radius INTEGER DEFAULT 100, -- in meters
    safe_zone_lat DOUBLE PRECISION,
    safe_zone_lng DOUBLE PRECISION,
    last_known_location_lat DOUBLE PRECISION,
    last_known_location_lng DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_patient ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Patients all operations" ON public.tbl_patient FOR ALL USING (true) WITH CHECK (true);

-- 3. Reminders Table
CREATE TABLE public.tbl_reminder (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.tbl_patient(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    reminder_time TIME NOT NULL,
    is_long_term BOOLEAN DEFAULT FALSE,
    start_date DATE DEFAULT CURRENT_DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_reminder ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Reminders all operations" ON public.tbl_reminder FOR ALL USING (true) WITH CHECK (true);

-- 4. Known Persons (Face Recognition Data) Table
CREATE TABLE public.tbl_known_person (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.tbl_patient(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    relation TEXT,
    voice_prompt_message TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_known_person ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Known Person all operations" ON public.tbl_known_person FOR ALL USING (true) WITH CHECK (true);

-- 5. Admin Table
CREATE TABLE public.tbl_admin (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    admin_name TEXT NOT NULL,
    admin_email TEXT UNIQUE NOT NULL,
    admin_password TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_admin ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin all operations" ON public.tbl_admin FOR ALL USING (true) WITH CHECK (true);

-- 6. Location History Table
CREATE TABLE public.tbl_location_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.tbl_patient(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_location_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Location History all operations" ON public.tbl_location_history FOR ALL USING (true) WITH CHECK (true);

-- 7. Complaints Table
CREATE TABLE public.tbl_complaint (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- Caregiver or Patient ID
    complaint_title TEXT NOT NULL,
    complaint_description TEXT NOT NULL,
    admin_reply TEXT,
    complaint_status INTEGER DEFAULT 0, -- 0: Pending, 1: Resolved
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_complaint ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Complaints all operations" ON public.tbl_complaint FOR ALL USING (true) WITH CHECK (true);

-- 8. Appointment Table
CREATE TABLE public.tbl_appointment (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.tbl_patient(id) ON DELETE CASCADE,
    doctor_name TEXT NOT NULL,
    hospital_name TEXT,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    notes TEXT,
    status INTEGER DEFAULT 0, -- 0: Pending, 1: Completed, 2: Cancelled
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_appointment ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Appointments all operations" ON public.tbl_appointment FOR ALL USING (true) WITH CHECK (true);

-- 9. Medicine Table
CREATE TABLE public.tbl_medicine (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.tbl_patient(id) ON DELETE CASCADE,
    medicine_name TEXT NOT NULL,
    dosage TEXT NOT NULL,
    stock INTEGER DEFAULT 0,
    notification_time TIME,
    is_long_term BOOLEAN DEFAULT FALSE,
    end_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_medicine ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Medicine all operations" ON public.tbl_medicine FOR ALL USING (true) WITH CHECK (true);

-- STORAGE BUCKETS SETUP --
-- Note: 'storage.buckets' and 'storage.objects' require postgres privileges depending on Supabase version.
-- Run this block in the Supabase SQL Editor as an Administrator.

INSERT INTO storage.buckets (id, name, public) VALUES ('photos', 'photos', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('audio_messages', 'audio_messages', true) ON CONFLICT (id) DO NOTHING;

-- Bucket Public Access Policies (Storage Object table)
DROP POLICY IF EXISTS "Public Access Photos" ON storage.objects;
CREATE POLICY "Public Access Photos" ON storage.objects FOR ALL USING (bucket_id = 'photos') WITH CHECK (bucket_id = 'photos');

DROP POLICY IF EXISTS "Public Access Audio" ON storage.objects;
CREATE POLICY "Public Access Audio" ON storage.objects FOR ALL USING (bucket_id = 'audio_messages') WITH CHECK (bucket_id = 'audio_messages');

-- 10. Memory Notes Table
CREATE TABLE public.tbl_memory_note (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.tbl_patient(id) ON DELETE CASCADE,
    note_title TEXT NOT NULL,
    note_content TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_memory_note ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Memory Notes all operations" ON public.tbl_memory_note FOR ALL USING (true) WITH CHECK (true);

-- 11. Activity Log Table
CREATE TABLE public.tbl_activity_log (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID, -- Can be admin, patient, or caregiver
    user_type TEXT, -- 'admin', 'patient', 'caregiver'
    action TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.tbl_activity_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Activity Log all operations" ON public.tbl_activity_log FOR ALL USING (true) WITH CHECK (true);

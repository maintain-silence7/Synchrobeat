-- ==============================================================================
-- SynchroBeat Database Initialization Migration
-- Target Engine: PostgreSQL 15+ (Supabase)
-- ==============================================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. User Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name VARCHAR(50) NOT NULL CHECK (char_length(display_name) >= 3),
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. Communal Vault Audio Tracks Table
CREATE TABLE IF NOT EXISTS public.tracks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uploader_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    artist VARCHAR(255) DEFAULT 'Unknown Artist' NOT NULL,
    album VARCHAR(255) DEFAULT 'Unknown Album' NOT NULL,
    duration_seconds INTEGER NOT NULL CHECK (duration_seconds > 0),
    storage_path TEXT NOT NULL UNIQUE,
    cover_art_url TEXT,
    file_size_bytes BIGINT NOT NULL CHECK (file_size_bytes > 0),
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 4. Playback Rooms Table
CREATE TABLE IF NOT EXISTS public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_code VARCHAR(6) UNIQUE NOT NULL CHECK (room_code ~ '^[A-Z0-9]{6}$'),
    host_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    current_track_id UUID REFERENCES public.tracks(id) ON DELETE SET NULL,
    is_playing BOOLEAN DEFAULT FALSE NOT NULL,
    playhead_position_ms INTEGER DEFAULT 0 NOT NULL CHECK (playhead_position_ms >= 0),
    server_sync_timestamp TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 5. Collaborative Room Queue Table
CREATE TABLE IF NOT EXISTS public.room_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    track_id UUID NOT NULL REFERENCES public.tracks(id) ON DELETE CASCADE,
    added_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT unique_room_position UNIQUE(room_id, position)
);

-- 6. Indexes for High-Concurrency Performance
CREATE INDEX IF NOT EXISTS idx_tracks_uploader ON public.tracks(uploader_id);
CREATE INDEX IF NOT EXISTS idx_rooms_code ON public.rooms(room_code);
CREATE INDEX IF NOT EXISTS idx_queue_room_pos ON public.room_queue(room_id, position);

-- 7. Trigger to auto-create profile on auth.users sign-up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 8. Row Level Security (RLS) Policies
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_queue ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Profiles are viewable by authenticated users"
ON public.profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Tracks Policies (Communal Vault)
CREATE POLICY "Tracks are viewable by authenticated users"
ON public.tracks FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert tracks"
ON public.tracks FOR INSERT TO authenticated WITH CHECK (auth.uid() = uploader_id);

CREATE POLICY "Uploaders can delete their own tracks"
ON public.tracks FOR DELETE TO authenticated USING (auth.uid() = uploader_id);

-- Rooms Policies
CREATE POLICY "Rooms are viewable by authenticated users"
ON public.rooms FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can create rooms"
ON public.rooms FOR INSERT TO authenticated WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Only the host can update room playback state"
ON public.rooms FOR UPDATE TO authenticated USING (auth.uid() = host_id);

-- Queue Policies
CREATE POLICY "Room queue viewable by authenticated users"
ON public.room_queue FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can add tracks to room queue"
ON public.room_queue FOR INSERT TO authenticated WITH CHECK (auth.uid() = added_by);

CREATE POLICY "Queue positions can be updated by room host or item adder"
ON public.room_queue FOR UPDATE TO authenticated USING (
    EXISTS (
        SELECT 1 FROM public.rooms 
        WHERE rooms.id = room_queue.room_id AND rooms.host_id = auth.uid()
    ) OR added_by = auth.uid()
);

CREATE POLICY "Queue items can be deleted by room host or item adder"
ON public.room_queue FOR DELETE TO authenticated USING (
    EXISTS (
        SELECT 1 FROM public.rooms 
        WHERE rooms.id = room_queue.room_id AND rooms.host_id = auth.uid()
    ) OR added_by = auth.uid()
);

-- ==============================================================================
-- 9. Realtime Publication
-- ==============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'rooms'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'room_queue'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.room_queue;
    END IF;
END $$;

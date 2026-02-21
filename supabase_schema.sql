-- ============================================================
--  EVENTLY — Supabase Database Schema
--  Run this in your Supabase SQL Editor (in order)
-- ============================================================

-- 1. PROFILES TABLE (extends Supabase auth.users)
CREATE TABLE public.profiles (
  id          UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name   TEXT,
  avatar_url  TEXT,
  role        TEXT DEFAULT 'user' CHECK (role IN ('user','organizer','admin')),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile when user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 2. CATEGORIES TABLE
-- ============================================================
CREATE TABLE public.categories (
  id          SERIAL PRIMARY KEY,
  name        TEXT UNIQUE NOT NULL,
  emoji       TEXT NOT NULL,
  color       TEXT NOT NULL DEFAULT '#7c6aff',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.categories (name, emoji, color) VALUES
  ('Music',         '🎵', '#7c6aff'),
  ('Entertainment', '🎭', '#ff5fa0'),
  ('Sports',        '⚽', '#00e5c3'),
  ('Food',          '🍜', '#ff8c42'),
  ('Tech',          '💻', '#4ea8de'),
  ('Art',           '🎨', '#f0c040'),
  ('Comedy',        '😂', '#b5e853'),
  ('Wellness',      '🧘', '#da77f2');

-- ============================================================
-- 3. EVENTS TABLE
-- ============================================================
CREATE TABLE public.events (
  id            BIGSERIAL PRIMARY KEY,
  title         TEXT NOT NULL,
  description   TEXT,
  category      TEXT NOT NULL REFERENCES public.categories(name),
  emoji         TEXT DEFAULT '🎫',
  event_date    DATE NOT NULL,
  event_time    TIME,
  venue         TEXT NOT NULL,
  address       TEXT,
  latitude      DOUBLE PRECISION,
  longitude     DOUBLE PRECISION,
  price         INTEGER DEFAULT 0,          -- price in paise/cents; 0 = free
  ticket_limit  INTEGER DEFAULT 100,
  organizer_id  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  image_url     TEXT,
  is_published  BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX idx_events_category ON public.events(category);
CREATE INDEX idx_events_date     ON public.events(event_date);
CREATE INDEX idx_events_location ON public.events USING GIST (
  ll_to_earth(latitude, longitude)
);

-- Seed with sample events
INSERT INTO public.events (title, category, emoji, event_date, event_time, venue, latitude, longitude, price, description) VALUES
('Neon Nights Music Festival', 'Music',         '🎵', '2025-03-15', '18:00', 'JLN Stadium, New Delhi',       28.5854, 77.2333, 1499, 'A massive open-air electronic music festival with 20+ artists.'),
('Stand-Up Comedy Gala',       'Comedy',        '😂', '2025-03-20', '20:00', 'Hard Rock Café, Mumbai',       19.0596, 72.8295, 799,  'Top comedians from across India — a night of pure laughter.'),
('IPL Opening Ceremony',       'Sports',        '⚽', '2025-03-22', '15:30', 'Wankhede Stadium, Mumbai',     18.9388, 72.8258, 2499, 'The grand opening of IPL 2025 with live performances.'),
('Indie Craft Beer Festival',  'Food',          '🍺', '2025-03-28', '12:00', 'Cubbon Park, Bangalore',       12.9762, 77.5929, 699,  '100+ craft beers, live bands, and street food from across India.'),
('AI & Future Tech Summit',    'Tech',          '💻', '2025-04-02', '09:00', 'Pragati Maidan, New Delhi',    28.6183, 77.2411, 3999, 'India''s biggest tech conference — speakers from Google, OpenAI.'),
('Contemporary Art Exhibition','Art',           '🎨', '2025-04-05', '10:00', 'NGMA, Mumbai',                 19.0237, 72.8367, 299,  'Featuring 50 emerging artists from the Indian subcontinent.'),
('Bollywood Night',            'Entertainment', '🎭', '2025-04-08', '19:30', 'JN Stadium, New Delhi',        28.5681, 77.2379, 1299, 'Dance, drama, and live Bollywood performances.'),
('Morning Yoga & Wellness',    'Wellness',      '🧘', '2025-04-10', '06:00', 'Lodhi Garden, New Delhi',      28.5931, 77.2215, 0,    'A sunrise wellness experience — yoga, meditation, and nutrition.'),
('Rock the Stage 2025',        'Music',         '🎸', '2025-04-12', '17:00', 'Palace Grounds, Bangalore',    13.0046, 77.5666, 1899, 'Biggest rock concert of the year with 10 legendary bands.'),
('Food & Spice Trail',         'Food',          '🍛', '2025-04-15', '11:00', 'India Gate Lawns, New Delhi',  28.6129, 77.2295, 499,  'A culinary journey across 29 Indian states in one venue.');

-- ============================================================
-- 4. BOOKINGS TABLE
-- ============================================================
CREATE TABLE public.bookings (
  id            BIGSERIAL PRIMARY KEY,
  event_id      BIGINT NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  quantity      INTEGER NOT NULL DEFAULT 1 CHECK (quantity >= 1 AND quantity <= 10),
  unit_price    INTEGER NOT NULL,            -- price at time of booking (paise)
  platform_fee  INTEGER NOT NULL DEFAULT 0,
  total_amount  INTEGER NOT NULL,
  status        TEXT DEFAULT 'confirmed' CHECK (status IN ('pending','confirmed','cancelled','refunded')),
  booking_ref   TEXT UNIQUE DEFAULT concat('EVT-', upper(substr(md5(random()::text), 1, 8))),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bookings_user  ON public.bookings(user_id);
CREATE INDEX idx_bookings_event ON public.bookings(event_id);

-- ============================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS
ALTER TABLE public.profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings   ENABLE ROW LEVEL SECURITY;

-- PROFILES: users can read any profile, edit only their own
CREATE POLICY "Profiles are viewable by everyone"     ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile"          ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- EVENTS: published events readable by all; organizers manage their own
CREATE POLICY "Published events visible to all"       ON public.events FOR SELECT USING (is_published = true);
CREATE POLICY "Organizers can insert events"          ON public.events FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Organizers can update their events"    ON public.events FOR UPDATE USING (auth.uid() = organizer_id);
CREATE POLICY "Organizers can delete their events"    ON public.events FOR DELETE USING (auth.uid() = organizer_id);

-- CATEGORIES: public read
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Categories visible to all"             ON public.categories FOR SELECT USING (true);

-- BOOKINGS: users see only their own bookings
CREATE POLICY "Users see own bookings"                ON public.bookings FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create bookings"             ON public.bookings FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can cancel own bookings"         ON public.bookings FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================
-- 6. HELPER VIEWS
-- ============================================================

-- Events with booking count
CREATE VIEW public.events_with_stats AS
SELECT 
  e.*,
  p.full_name AS organizer_name,
  COUNT(b.id) AS total_bookings,
  COALESCE(SUM(b.quantity), 0) AS tickets_sold,
  (e.ticket_limit - COALESCE(SUM(b.quantity), 0)) AS tickets_remaining
FROM public.events e
LEFT JOIN public.profiles p ON p.id = e.organizer_id
LEFT JOIN public.bookings b ON b.event_id = e.id AND b.status = 'confirmed'
GROUP BY e.id, p.full_name;

-- ============================================================
-- HOW TO CONNECT TO YOUR APP:
--
-- 1. Go to https://supabase.com → New Project
-- 2. Run all of the above SQL in the SQL Editor
-- 3. Go to Project Settings → API
-- 4. Copy your Project URL and anon public key
-- 5. In evently.html, replace:
--      const SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co';
--      const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
-- 6. Add the Supabase JS client in the <head>:
--      <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
-- 7. Initialize the client:
--      const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
-- 8. Replace the TODO comments in the JS with real Supabase calls
-- ============================================================

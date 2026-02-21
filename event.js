const SUPABASE_URL = 'https://zghpqhvvsbbaoovvtonj.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpnaHBxaHZ2c2JiYW9vdnZ0b25qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2MTQ1NjEsImV4cCI6MjA4NzE5MDU2MX0._Dg_-QCqrmIOWn6HCPBB6znAVjiQH-6ZzARrCWT2ZX0';

// ADD THIS LINE
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
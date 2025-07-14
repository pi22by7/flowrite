-- Supabase database schema for Flowrite app
-- Run these SQL commands in your Supabase SQL editor

-- Create user_files table first
CREATE TABLE IF NOT EXISTS user_files (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  content TEXT,
  last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security on the table
ALTER TABLE user_files ENABLE ROW LEVEL SECURITY;

-- Create RLS policy after table exists
CREATE POLICY "Users can only access their own files" ON user_files
  FOR ALL USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_files_user_id ON user_files(user_id);
CREATE INDEX IF NOT EXISTS idx_user_files_last_modified ON user_files(last_modified);
CREATE INDEX IF NOT EXISTS idx_user_files_created_at ON user_files(created_at);

-- Create a function to automatically update the updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_user_files_updated_at 
  BEFORE UPDATE ON user_files 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT ALL ON user_files TO authenticated;
GRANT ALL ON user_files TO service_role;

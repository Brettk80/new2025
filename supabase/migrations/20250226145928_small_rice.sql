/*
  # Initial Schema for Fax Application

  1. New Tables
    - users
      - Core user information and settings
    - fax_documents
      - Stores fax document metadata
    - fax_recipients
      - Stores recipient information for fax broadcasts
    - block_lists
      - Stores blocked fax numbers
    - fax_broadcasts
      - Stores broadcast job information
    - fax_delivery_status
      - Tracks delivery status for each fax

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
    - Ensure users can only access their own data
*/

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  company_name text,
  phone text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Fax documents table
CREATE TABLE IF NOT EXISTS fax_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  file_path text NOT NULL,
  page_count integer NOT NULL,
  file_size bigint NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Fax recipients table
CREATE TABLE IF NOT EXISTS fax_recipients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  fax_number text NOT NULL,
  to_header text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Block lists table
CREATE TABLE IF NOT EXISTS block_lists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  fax_number text NOT NULL,
  reason text,
  source text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, fax_number)
);

-- Fax broadcasts table
CREATE TABLE IF NOT EXISTS fax_broadcasts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('draft', 'pending_test', 'scheduled', 'in_progress', 'paused', 'completed', 'cancelled')),
  billing_code text,
  scheduled_time timestamptz,
  test_fax_number text,
  test_fax_status text CHECK (test_fax_status IN ('pending', 'delivered', 'failed')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Fax broadcast documents junction table
CREATE TABLE IF NOT EXISTS fax_broadcast_documents (
  broadcast_id uuid REFERENCES fax_broadcasts(id) ON DELETE CASCADE,
  document_id uuid REFERENCES fax_documents(id) ON DELETE CASCADE,
  sequence_order integer NOT NULL,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (broadcast_id, document_id)
);

-- Fax delivery status table
CREATE TABLE IF NOT EXISTS fax_delivery_status (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id uuid REFERENCES fax_broadcasts(id) ON DELETE CASCADE,
  recipient_id uuid REFERENCES fax_recipients(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('pending', 'in_progress', 'delivered', 'failed')),
  error_message text,
  delivery_time timestamptz,
  retry_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE fax_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE fax_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE block_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE fax_broadcasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE fax_broadcast_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE fax_delivery_status ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Users can read/update their own data
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (auth.uid() = auth_id);

CREATE POLICY "Users can update own data" ON users
  FOR UPDATE USING (auth.uid() = auth_id);

-- Documents policies
CREATE POLICY "Users can read own documents" ON fax_documents
  FOR SELECT USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can insert own documents" ON fax_documents
  FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can update own documents" ON fax_documents
  FOR UPDATE USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Recipients policies
CREATE POLICY "Users can read own recipients" ON fax_recipients
  FOR SELECT USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can manage own recipients" ON fax_recipients
  FOR ALL USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Block list policies
CREATE POLICY "Users can read own block list" ON block_lists
  FOR SELECT USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can manage own block list" ON block_lists
  FOR ALL USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Broadcast policies
CREATE POLICY "Users can read own broadcasts" ON fax_broadcasts
  FOR SELECT USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can manage own broadcasts" ON fax_broadcasts
  FOR ALL USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Broadcast documents policies
CREATE POLICY "Users can read own broadcast documents" ON fax_broadcast_documents
  FOR SELECT USING (
    broadcast_id IN (
      SELECT id FROM fax_broadcasts WHERE user_id IN (
        SELECT id FROM users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can manage own broadcast documents" ON fax_broadcast_documents
  FOR ALL USING (
    broadcast_id IN (
      SELECT id FROM fax_broadcasts WHERE user_id IN (
        SELECT id FROM users WHERE auth_id = auth.uid()
      )
    )
  );

-- Delivery status policies
CREATE POLICY "Users can read own delivery status" ON fax_delivery_status
  FOR SELECT USING (
    broadcast_id IN (
      SELECT id FROM fax_broadcasts WHERE user_id IN (
        SELECT id FROM users WHERE auth_id = auth.uid()
      )
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_fax_documents_user_id ON fax_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_fax_recipients_user_id ON fax_recipients(user_id);
CREATE INDEX IF NOT EXISTS idx_block_lists_user_id ON block_lists(user_id);
CREATE INDEX IF NOT EXISTS idx_fax_broadcasts_user_id ON fax_broadcasts(user_id);
CREATE INDEX IF NOT EXISTS idx_fax_delivery_status_broadcast_id ON fax_delivery_status(broadcast_id);
CREATE INDEX IF NOT EXISTS idx_block_lists_fax_number ON block_lists(fax_number);
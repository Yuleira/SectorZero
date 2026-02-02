-- Migration: 016_message_delete_policy
-- Fix: Add DELETE RLS policy for channel_messages table
-- Users can only delete their own messages
--
-- IMPORTANT: Execute this SQL manually in Supabase Dashboard > SQL Editor

-- RLS Policy: Users can delete their own messages
CREATE POLICY "Users can delete their own messages" ON public.channel_messages
    FOR DELETE TO authenticated
    USING (auth.uid() = sender_id);

-- Optional: Add UPDATE policy if editing messages is needed in the future
-- CREATE POLICY "Users can update their own messages" ON public.channel_messages
--     FOR UPDATE TO authenticated
--     USING (auth.uid() = sender_id)
--     WITH CHECK (auth.uid() = sender_id);

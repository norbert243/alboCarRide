import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { user_id, title, body } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: profile, error } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', user_id)
      .single()

    if (error) {
      throw error
    }

    if (!profile || !profile.fcm_token) {
      return new Response(JSON.stringify({ error: 'FCM token not found for user' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      })
    }
    
    const fcmKey = Deno.env.get('FCM_SERVER_KEY')
    if(!fcmKey) {
       return new Response(JSON.stringify({ error: 'FCM server key not configured' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const message = {
      to: profile.fcm_token,
      notification: {
        title,
        body,
      },
    }

    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${fcmKey}`,
      },
      body: JSON.stringify(message),
    })

    const responseData = await response.json()

    return new Response(JSON.stringify(responseData), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(String(err?.message ?? err), { status: 500 })
  }
})

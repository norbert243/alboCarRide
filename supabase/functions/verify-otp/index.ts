import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { phoneNumber, otp, fullName, role } = await req.json()

    if (!phoneNumber || !otp) {
      return new Response(
        JSON.stringify({ error: 'Phone number and OTP are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Retrieve OTP record from database
    const { data: otpRecord, error: fetchError } = await supabaseClient
      .from('otp_verifications')
      .select('*')
      .eq('phone_number', phoneNumber)
      .single()

    if (fetchError || !otpRecord) {
      return new Response(
        JSON.stringify({ error: 'No OTP found for this phone number' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if OTP is already verified
    if (otpRecord.verified) {
      return new Response(
        JSON.stringify({ error: 'OTP already used' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if OTP has expired
    const expiresAt = new Date(otpRecord.expires_at)
    if (expiresAt < new Date()) {
      return new Response(
        JSON.stringify({ error: 'OTP has expired' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check maximum attempts (5 attempts allowed)
    if (otpRecord.attempts >= 5) {
      return new Response(
        JSON.stringify({ error: 'Maximum verification attempts exceeded' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify OTP
    if (otpRecord.otp_code !== otp) {
      // Increment attempts
      await supabaseClient
        .from('otp_verifications')
        .update({ attempts: otpRecord.attempts + 1 })
        .eq('phone_number', phoneNumber)

      return new Response(
        JSON.stringify({
          error: 'Invalid OTP',
          attemptsRemaining: 5 - (otpRecord.attempts + 1)
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // OTP is valid - mark as verified
    await supabaseClient
      .from('otp_verifications')
      .update({ verified: true })
      .eq('phone_number', phoneNumber)

    // Check if user already exists
    const { data: existingProfile } = await supabaseClient
      .from('profiles')
      .select('id, role')
      .eq('phone', phoneNumber)
      .single()

    let userId: string
    let isNewUser = false
    let session = null

    if (existingProfile) {
      // Existing user - sign them in
      userId = existingProfile.id

      // Create a session for existing user using admin API
      const { data: sessionData, error: sessionError } = await supabaseClient.auth.admin.generateLink({
        type: 'magiclink',
        email: `${phoneNumber}@albocarride.com`,
      })

      if (sessionError) {
        console.error('Session creation error:', sessionError)
      } else {
        session = sessionData
      }
    } else {
      // New user - create account
      isNewUser = true
      const email = `${phoneNumber}@albocarride.com`
      const password = `Alb0CarRide${Date.now()}`

      const { data: authData, error: authError } = await supabaseClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          phone: phoneNumber,
          full_name: fullName || '',
          role: role || 'customer',
        }
      })

      if (authError || !authData.user) {
        console.error('User creation error:', authError)
        return new Response(
          JSON.stringify({ error: 'Failed to create user account' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      userId = authData.user.id

      // Create profile
      await supabaseClient.from('profiles').upsert({
        id: userId,
        phone: phoneNumber,
        full_name: fullName || '',
        role: role || 'customer',
        updated_at: new Date().toISOString(),
      })

      // Create role-specific record
      if (role === 'driver') {
        await supabaseClient.from('drivers').upsert({
          id: userId,
          is_approved: false,
          is_online: false,
          rating: 0.0,
          total_rides: 0,
          updated_at: new Date().toISOString(),
        })
      } else {
        await supabaseClient.from('customers').upsert({
          id: userId,
          preferred_payment_method: 'cash',
          rating: 0.0,
          total_rides: 0,
          updated_at: new Date().toISOString(),
        })
      }

      // Generate session for new user
      const { data: sessionData, error: sessionError } = await supabaseClient.auth.admin.generateLink({
        type: 'magiclink',
        email,
      })

      if (sessionError) {
        console.error('Session creation error:', sessionError)
      } else {
        session = sessionData
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        userId,
        isNewUser,
        role: role || existingProfile?.role || 'customer',
        session,
        message: 'Phone number verified successfully'
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

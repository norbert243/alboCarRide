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
        JSON.stringify({ error: 'No verification code found. Please request a new code.' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if OTP is already verified
    if (otpRecord.verified) {
      return new Response(
        JSON.stringify({ error: 'This code has already been used. Please request a new code.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if OTP has expired
    const expiresAt = new Date(otpRecord.expires_at)
    if (expiresAt < new Date()) {
      return new Response(
        JSON.stringify({ error: 'Verification code expired. Please request a new code.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check maximum attempts (5 attempts allowed)
    if (otpRecord.attempts >= 5) {
      return new Response(
        JSON.stringify({ error: 'Too many incorrect attempts. Please request a new code.' }),
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

      const attemptsLeft = 5 - (otpRecord.attempts + 1)
      return new Response(
        JSON.stringify({
          error: `Incorrect verification code. ${attemptsLeft} ${attemptsLeft === 1 ? 'attempt' : 'attempts'} remaining.`,
          attemptsRemaining: attemptsLeft
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // OTP is valid - mark as verified
    await supabaseClient
      .from('otp_verifications')
      .update({ verified: true })
      .eq('phone_number', phoneNumber)

    // Check if user already exists in profiles
    const { data: existingProfile } = await supabaseClient
      .from('profiles')
      .select('id, role')
      .eq('phone', phoneNumber)
      .single()

    // Also check if auth user exists
    const email = `${phoneNumber}@albocarride.com`
    const { data: authUsers } = await supabaseClient.auth.admin.listUsers()
    const existingAuthUser = authUsers?.users?.find(u => u.email === email)

    let userId: string
    let isNewUser = false
    let password: string

    if (existingProfile || existingAuthUser) {
      // Existing user - just log them in
      userId = existingProfile?.id || existingAuthUser?.id || ''

      // For existing users, generate a new password for this session
      password = `Albo${Date.now()}${Math.random().toString(36).substr(2, 9)}`

      // Update user password to allow sign in
      const { error: updateError } = await supabaseClient.auth.admin.updateUserById(userId, {
        password: password,
      })

      if (updateError) {
        console.error('Password update error:', updateError)
        return new Response(
          JSON.stringify({ error: 'Unable to sign in. Please try again.' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    } else {
      // New user - create account
      isNewUser = true
      email = `${phoneNumber}@albocarride.com`
      password = `Albo${Date.now()}${Math.random().toString(36).substr(2, 9)}`

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
          JSON.stringify({ error: 'Unable to create account. Please try again.' }),
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
    }

    return new Response(
      JSON.stringify({
        success: true,
        userId,
        isNewUser,
        role: role || existingProfile?.role || 'customer',
        email,
        password,
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

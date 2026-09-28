import { createClient, User } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

export async function validateAuth(req: Request): Promise<{ user: User; errorResponse?: Response }> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return {
      user: null as unknown as User,
      errorResponse: new Response(
        JSON.stringify({ error: 'Missing or malformed Authorization header' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      ),
    };
  }

  const token = authHeader.replace('Bearer ', '').trim();
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
  if ((serviceRoleKey && token === serviceRoleKey)) {
    const serviceUser: User = {
      id: '00000000-0000-0000-0000-000000000000',
      app_metadata: { provider: 'service_role', role: 'service_role' },
      user_metadata: {},
      aud: 'authenticated',
      created_at: new Date().toISOString(),
    };
    return { user: serviceUser };
  }

  // Also check JWT payload directly if signed as service_role
  try {
    const parts = token.split('.');
    if (parts.length === 3) {
      const payloadStr = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'));
      const payload = JSON.parse(payloadStr);
      if (payload.role === 'service_role') {
        const serviceUser: User = {
          id: payload.sub || '00000000-0000-0000-0000-000000000000',
          app_metadata: { provider: 'service_role', role: 'service_role' },
          user_metadata: {},
          aud: 'authenticated',
          created_at: new Date().toISOString(),
        };
        return { user: serviceUser };
      }
    }
  } catch {
    // Ignore payload parse errors and proceed with supabase.auth.getUser
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') || '';

  if (!supabaseUrl || !supabaseAnonKey) {
    return {
      user: null as unknown as User,
      errorResponse: new Response(
        JSON.stringify({ error: 'Server environment missing Supabase configuration' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      ),
    };
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: { user }, error } = await supabase.auth.getUser(token);

  if (error || !user) {
    return {
      user: null as unknown as User,
      errorResponse: new Response(
        JSON.stringify({ error: 'Unauthorized: Invalid or expired token', details: error?.message }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      ),
    };
  }

  return { user };
}

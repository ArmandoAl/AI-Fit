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

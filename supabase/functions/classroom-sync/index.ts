import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.4';

Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const authHeader = request.headers.get('Authorization');
  if (!authHeader) return new Response('Unauthorized', { status: 401 });

  const client = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await client.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  const { classId } = await request.json();
  const { data: classRow } = await client.from('classes').select('id').eq('id', classId).eq('teacher_id', user.id).maybeSingle();
  if (!classRow) return new Response('Forbidden', { status: 403 });

  return Response.json({
    status: 'configuration_required',
    message: 'Configure GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, token encryption, and approved Classroom scopes before enabling synchronization.',
  }, { status: 501 });
});

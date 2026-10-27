import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

export const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

export const servicio = (): SupabaseClient =>
  createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });

/** true si la petición viene de un administrador con sesión iniciada (o de la tarea programada con su secreto). */
export async function esAdmin(req: Request): Promise<boolean> {
  const cronHdr = req.headers.get('x-cron-secret');
  if (cronHdr) { const cron = await config('CRON_TAREAS'); return !!cron && cronHdr === cron; }
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return false;
  const sb = servicio();
  const { data: u, error } = await sb.auth.getUser(token);
  if (error || !u?.user) return false;
  const { data } = await sb.from('admins').select('user_id').eq('user_id', u.user.id).maybeSingle();
  return !!data;
}

/** Lee un ajuste privado: primero de los secretos de la función y, si no está, de la tabla config_privada. */
export async function config(clave: string): Promise<string | undefined> {
  const env = Deno.env.get(clave);
  if (env) return env;
  const { data } = await servicio().from('config_privada').select('valor').eq('clave', clave).maybeSingle();
  return data?.valor ?? undefined;
}

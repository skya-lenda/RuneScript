import { supabase, verifyJWT, secureHeaders } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }
  if (!payload.isAdmin) return res.status(403).json({ error: 'Acesso negado.' });

  if (req.method === 'GET') {
    const { data } = await supabase.from('logs').select('usuario,modulo,termo,ts').order('ts', { ascending: false }).limit(500);
    return res.json(data || []);
  }

  if (req.method === 'DELETE') {
    await supabase.from('logs').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    return res.json({ ok: true });
  }

  return res.status(405).end();
}


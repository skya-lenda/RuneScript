import { supabase, verifyJWT, secureHeaders } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'GET') return res.status(405).end();

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }
  if (!payload.isAdmin) return res.status(403).json({ error: 'Acesso negado.' });

  const [{ count: totalUsers }, { data: logs }] = await Promise.all([
    supabase.from('usuarios').select('*', { count: 'exact', head: true }),
    supabase.from('logs').select('ts').order('ts', { ascending: false }).limit(500),
  ]);

  const today = new Date().toISOString().slice(0, 10);
  return res.json({
    totalUsers: totalUsers || 0,
    totalLogs: logs?.length || 0,
    logsHoje: logs?.filter(l => l.ts?.startsWith(today)).length || 0,
  });
}


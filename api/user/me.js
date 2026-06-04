import { supabase, verifyJWT, secureHeaders, getDailyCount, PLAN_CONFIG } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'GET') return res.status(405).end();

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }

  if (payload.isAdmin) return res.json({ isAdmin: true });

  const { data: user } = await supabase.from('usuarios')
    .select('username,plano').eq('id', payload.sub).single();

  if (!user) return res.status(404).json({ error: 'Usuário não encontrado.' });

  const cfg = PLAN_CONFIG[user.plano] || PLAN_CONFIG.Bronze;
  const used = await getDailyCount(user.username);

  return res.json({
    username: user.username,
    plano: user.plano,
    dailyUsed: used,
    dailyRemaining: Math.max(0, cfg.dailyLimit - used),
    dailyLimit: cfg.dailyLimit,
    modulesAllowed: cfg.modules,
  });
}


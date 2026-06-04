import { supabase, verifyJWT, secureHeaders, getDailyCount, incDailyCount, addLog, PLAN_CONFIG, sanitize } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'POST') return res.status(405).end();

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }

  const { data: user } = await supabase.from('usuarios').select('plano').eq('id', payload.sub).single();
  const cfg = PLAN_CONFIG[user?.plano] || PLAN_CONFIG.Bronze;
  if (!cfg.modules.includes('ip')) return res.status(403).json({ error: 'Módulo não disponível no seu plano.' });

  const used = await getDailyCount(payload.username);
  if (used >= cfg.dailyLimit) return res.status(429).json({ error: 'Limite diário atingido.' });

  const ip = sanitize(req.body?.termo || '');
  if (!/^(\d{1,3}\.){3}\d{1,3}$|^[0-9a-fA-F:]+$/.test(ip)) return res.status(400).json({ error: 'IP inválido.' });

  try {
    const r = await fetch(`https://ipapi.co/${ip}/json/`);
    const d = await r.json();
    if (d.error) return res.status(404).json({ error: 'IP não encontrado.' });

    await incDailyCount(payload.username);
    await addLog(payload.username, 'IP', ip);

    return res.json({ ip, pais: d.country_name, pais_code: d.country, cidade: d.city, asn: d.asn, org: d.org, timezone: d.timezone, latitude: d.latitude, longitude: d.longitude });
  } catch {
    return res.status(502).json({ error: 'Erro ao consultar IP.' });
  }
}


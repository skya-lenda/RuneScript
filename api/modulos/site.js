import { supabase, verifyJWT, secureHeaders, getDailyCount, incDailyCount, addLog, PLAN_CONFIG, sanitize } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'POST') return res.status(405).end();

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }

  const { data: user } = await supabase.from('usuarios').select('plano').eq('id', payload.sub).single();
  const cfg = PLAN_CONFIG[user?.plano] || PLAN_CONFIG.Bronze;
  if (!cfg.modules.includes('site')) return res.status(403).json({ error: 'Módulo não disponível no seu plano.' });

  const used = await getDailyCount(payload.username);
  if (used >= cfg.dailyLimit) return res.status(429).json({ error: 'Limite diário atingido.' });

  let target = sanitize(req.body?.termo || '');
  if (!/^https?:\/\//i.test(target)) target = 'https://' + target;
  let u; try { u = new URL(target); } catch { return res.status(400).json({ error: 'URL inválida.' }); }

  let ipAddr = '—';
  try {
    const dns = await fetch(`https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(u.hostname)}&type=A`, { headers: { Accept: 'application/dns-json' } });
    const dd = await dns.json();
    const ans = dd.Answer?.filter(r => r.type === 1).map(r => r.data);
    if (ans?.length) ipAddr = ans.join(', ');
  } catch {}

  await incDailyCount(payload.username);
  await addLog(payload.username, 'Site', u.hostname);

  return res.json({ url: target, hostname: u.hostname, ips: ipAddr, https: target.startsWith('https://') });
}


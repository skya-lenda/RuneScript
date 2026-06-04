import { supabase, verifyJWT, secureHeaders, getDailyCount, incDailyCount, addLog, PLAN_CONFIG, sanitize } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'POST') return res.status(405).end();

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }

  const { data: user } = await supabase.from('usuarios').select('plano').eq('id', payload.sub).single();
  const cfg = PLAN_CONFIG[user?.plano] || PLAN_CONFIG.Bronze;
  if (!cfg.modules.includes('dominio')) return res.status(403).json({ error: 'Módulo não disponível no seu plano.' });

  const used = await getDailyCount(payload.username);
  if (used >= cfg.dailyLimit) return res.status(429).json({ error: 'Limite diário atingido.' });

  const dominio = sanitize(req.body?.termo || '').replace(/^https?:\/\//i, '').replace(/\//g, '').toLowerCase();
  if (!dominio.includes('.') || dominio.length > 253) return res.status(400).json({ error: 'Domínio inválido.' });

  let rdapData = null, aRecords = '—';
  try {
    const tld = dominio.split('.').pop();
    const boot = await (await fetch('https://data.iana.org/rdap/dns.json')).json();
    for (const svc of boot.services) {
      if (svc[0].includes(tld)) { const rr = await fetch(`${svc[1][0]}domain/${dominio}`); if (rr.ok) rdapData = await rr.json(); break; }
    }
  } catch {}
  try {
    const dns = await fetch(`https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(dominio)}&type=A`, { headers: { Accept: 'application/dns-json' } });
    const dd = await dns.json();
    const ans = dd.Answer?.filter(r => r.type === 1).map(r => r.data);
    if (ans?.length) aRecords = ans.join(', ');
  } catch {}

  await incDailyCount(payload.username);
  await addLog(payload.username, 'Domínio', dominio);

  const registrar = rdapData?.entities?.find(e => e.roles?.includes('registrar'))?.vcardArray?.[1]?.find(v => v[0] === 'fn')?.[3] || '—';
  const created = rdapData?.events?.find(e => e.eventAction === 'registration')?.eventDate;
  const expires = rdapData?.events?.find(e => e.eventAction === 'expiration')?.eventDate;

  return res.json({ dominio, registrar, criado: created, expira: expires, nameservers: rdapData?.nameservers?.map(n => n.ldhName) || [], ips: aRecords });
}


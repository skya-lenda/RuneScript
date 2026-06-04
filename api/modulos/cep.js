import { supabase, verifyJWT, secureHeaders, getDailyCount, incDailyCount, addLog, PLAN_CONFIG, sanitize } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'POST') return res.status(405).end();

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }

  // Verifica plano server-side
  const { data: user } = await supabase.from('usuarios').select('plano').eq('id', payload.sub).single();
  const cfg = PLAN_CONFIG[user?.plano] || PLAN_CONFIG.Bronze;
  if (!cfg.modules.includes('cep')) return res.status(403).json({ error: 'Módulo não disponível no seu plano.' });

  const used = await getDailyCount(payload.username);
  if (used >= cfg.dailyLimit) return res.status(429).json({ error: 'Limite diário atingido.' });

  const cep = sanitize(req.body?.termo || '').replace(/\D/g, '');
  if (cep.length !== 8) return res.status(400).json({ error: 'CEP inválido.' });

  try {
    const r = await fetch(`https://viacep.com.br/ws/${cep}/json/`);
    const d = await r.json();
    if (d.erro) return res.status(404).json({ error: 'CEP não encontrado.' });

    await incDailyCount(payload.username);
    await addLog(payload.username, 'CEP', cep);

    return res.json({ cep: d.cep, logradouro: d.logradouro, bairro: d.bairro, cidade: d.localidade, uf: d.uf, ddd: d.ddd, ibge: d.ibge });
  } catch {
    return res.status(502).json({ error: 'Erro ao consultar ViaCEP.' });
  }
}


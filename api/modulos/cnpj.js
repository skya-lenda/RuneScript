import { supabase, verifyJWT, secureHeaders, getDailyCount, incDailyCount, addLog, PLAN_CONFIG, sanitize } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'POST') return res.status(405).end();

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }

  const { data: user } = await supabase.from('usuarios').select('plano').eq('id', payload.sub).single();
  const cfg = PLAN_CONFIG[user?.plano] || PLAN_CONFIG.Bronze;
  if (!cfg.modules.includes('cnpj')) return res.status(403).json({ error: 'Módulo não disponível no seu plano.' });

  const used = await getDailyCount(payload.username);
  if (used >= cfg.dailyLimit) return res.status(429).json({ error: 'Limite diário atingido.' });

  const cnpj = sanitize(req.body?.termo || '').replace(/\D/g, '');
  if (cnpj.length !== 14) return res.status(400).json({ error: 'CNPJ inválido.' });

  try {
    const r = await fetch(`https://receitaws.com.br/v1/cnpj/${cnpj}`, { headers: { Accept: 'application/json' } });
    if (r.status === 429) return res.status(429).json({ error: 'Limite da API. Aguarde 1 min.' });
    const d = await r.json();
    if (d.status === 'ERROR') return res.status(404).json({ error: d.message || 'CNPJ não encontrado.' });

    await incDailyCount(payload.username);
    await addLog(payload.username, 'CNPJ', cnpj);

    return res.json({ cnpj: d.cnpj, nome: d.nome, situacao: d.situacao, abertura: d.abertura, natureza_juridica: d.natureza_juridica, capital_social: d.capital_social, porte: d.porte, municipio: d.municipio, uf: d.uf, telefone: d.telefone, atividade_principal: d.atividade_principal?.[0]?.text || '—', socios: d.qsa?.map(s => s.nome) || [] });
  } catch {
    return res.status(502).json({ error: 'Erro ao consultar CNPJ.' });
  }
}


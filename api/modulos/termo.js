import { supabase, verifyJWT, secureHeaders, getDailyCount, incDailyCount, addLog, PLAN_CONFIG, sanitize } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'POST') return res.status(405).end();

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }

  const { data: user } = await supabase.from('usuarios').select('plano').eq('id', payload.sub).single();
  const cfg = PLAN_CONFIG[user?.plano] || PLAN_CONFIG.Bronze;
  if (!cfg.modules.includes('termo')) return res.status(403).json({ error: 'Módulo não disponível no seu plano.' });

  const used = await getDailyCount(payload.username);
  if (used >= cfg.dailyLimit) return res.status(429).json({ error: 'Limite diário atingido.' });

  const termo = sanitize(req.body?.termo || '', 300);
  if (!termo) return res.status(400).json({ error: 'Termo obrigatório.' });

  try {
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-api-key': process.env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514', max_tokens: 2000,
        tools: [{ type: 'web_search_20250305', name: 'web_search' }],
        system: 'Você é um motor OSINT. Retorne JSON puro sem markdown. JSON: {"results":[{source,title,summary,url,type}]}. type: social/news/forum/site/doc/gov. Máx 8 resultados.',
        messages: [{ role: 'user', content: `Busca OSINT sobre: "${termo}". Pesquise em fontes diversas e retorne JSON.` }]
      })
    });
    const d = await r.json();
    const text = d.content?.filter(c => c.type === 'text').map(c => c.text).join('') || '';
    let results = [];
    try { results = JSON.parse(text.replace(/```json|```/g, '').trim()).results || []; } catch {}

    await incDailyCount(payload.username);
    await addLog(payload.username, 'Termo', termo);

    return res.json({ results });
  } catch {
    return res.status(502).json({ error: 'Erro ao consultar.' });
  }
}


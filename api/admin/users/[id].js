import { supabase, verifyJWT, secureHeaders } from '../../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }
  if (!payload.isAdmin) return res.status(403).json({ error: 'Acesso negado.' });

  const { id } = req.query;

  // PUT — atualizar plano
  if (req.method === 'PUT') {
    const plano = ['Bronze','Gold','Diamond'].includes(req.body?.plano) ? req.body.plano : null;
    if (!plano) return res.status(400).json({ error: 'Plano inválido.' });
    await supabase.from('usuarios').update({ plano }).eq('id', id);
    return res.json({ ok: true });
  }

  // DELETE — excluir usuário
  if (req.method === 'DELETE') {
    await supabase.from('usuarios').delete().eq('id', id);
    return res.json({ ok: true });
  }

  return res.status(405).end();
}


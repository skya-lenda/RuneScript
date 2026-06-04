import bcrypt from 'bcryptjs';
import { supabase, verifyJWT, secureHeaders, sanitize } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }
  if (!payload.isAdmin) return res.status(403).json({ error: 'Acesso negado.' });

  // GET — listar usuários
  if (req.method === 'GET') {
    const { data } = await supabase.from('usuarios').select('id,username,plano,data_criacao').order('data_criacao', { ascending: false });
    return res.json(data || []);
  }

  // POST — criar usuário
  if (req.method === 'POST') {
    const username = sanitize(req.body?.username || '').toLowerCase();
    const password = sanitize(req.body?.password || '', 128);
    const plano = ['Bronze','Gold','Diamond'].includes(req.body?.plano) ? req.body.plano : 'Bronze';

    if (!username || !password) return res.status(400).json({ error: 'Campos obrigatórios.' });
    if (!/^[a-z0-9_]{3,20}$/.test(username)) return res.status(400).json({ error: 'Username inválido (3-20 chars).' });
    if (password.length < 6) return res.status(400).json({ error: 'Senha mínima: 6 caracteres.' });

    const { data: exists } = await supabase.from('usuarios').select('id').eq('username', username).single();
    if (exists) return res.status(409).json({ error: 'Usuário já existe.' });

    const senhaHash = await bcrypt.hash(password, 12);
    const { error } = await supabase.from('usuarios').insert({ username, senha_hash: senhaHash, plano });
    if (error) return res.status(500).json({ error: 'Erro ao criar.' });

    return res.status(201).json({ ok: true });
  }

  return res.status(405).end();
}


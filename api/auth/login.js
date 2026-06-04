import bcrypt from 'bcryptjs';
import { supabase, signJWT, secureHeaders, sanitize } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'POST') return res.status(405).end();

  const username = sanitize(req.body?.username || '').toLowerCase();
  const password = sanitize(req.body?.password || '', 128);
  if (!username || !password) return res.status(400).json({ error: 'Campos obrigatórios.' });

  // Delay anti-timing attack
  await new Promise(r => setTimeout(r, 300 + Math.random() * 200));

  try {
    // Admin
    if (username === process.env.ADMIN_USERNAME) {
      const valid = await bcrypt.compare(password, process.env.ADMIN_PASSWORD_HASH);
      if (!valid) return res.status(401).json({ error: 'Credenciais inválidas.' });
      const token = signJWT({ sub: 'admin', isAdmin: true, username });
      return res.json({ token, role: 'admin', username, hasPinSet: true });
    }

    // Usuário normal
    const { data: user } = await supabase.from('usuarios')
      .select('id,username,senha_hash,plano,pin_hash')
      .eq('username', username).single();

    if (!user) return res.status(401).json({ error: 'Credenciais inválidas.' });

    const valid = await bcrypt.compare(password, user.senha_hash);
    if (!valid) return res.status(401).json({ error: 'Credenciais inválidas.' });

    const token = signJWT({ sub: user.id, isAdmin: false, username: user.username, plano: user.plano });
    return res.json({ token, role: 'user', username: user.username, plano: user.plano, hasPinSet: !!user.pin_hash });
  } catch (err) {
    console.error('[login]', err.message);
    return res.status(500).json({ error: 'Erro interno.' });
  }
}


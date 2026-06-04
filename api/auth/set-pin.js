import bcrypt from 'bcryptjs';
import { supabase, verifyJWT, secureHeaders, sanitize } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'POST') return res.status(405).end();

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }

  const pin = sanitize(req.body?.pin || '', 6);
  if (!/^\d{6}$/.test(pin)) return res.status(400).json({ error: 'PIN deve ter 6 dígitos.' });

  const pinHash = await bcrypt.hash(pin, 12);

  try {
    if (payload.isAdmin) {
      await supabase.from('admin_pins').upsert({ username: payload.username, pin_hash: pinHash });
    } else {
      await supabase.from('usuarios').update({ pin_hash: pinHash }).eq('id', payload.sub);
    }
    return res.json({ ok: true });
  } catch {
    return res.status(500).json({ error: 'Erro interno.' });
  }
}


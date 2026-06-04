import bcrypt from 'bcryptjs';
import { supabase, verifyJWT, signJWT, secureHeaders, sanitize } from '../_lib.js';

export default async function handler(req, res) {
  secureHeaders(res);
  if (req.method !== 'POST') return res.status(405).end();

  let payload;
  try { payload = verifyJWT(req); } catch { return res.status(401).json({ error: 'Não autenticado.' }); }

  const pin = sanitize(req.body?.pin || '', 6);
  if (!/^\d{6}$/.test(pin)) return res.status(400).json({ error: 'PIN deve ter 6 dígitos.' });

  try {
    let storedHash;
    if (payload.isAdmin) {
      const { data } = await supabase.from('admin_pins').select('pin_hash').eq('username', payload.username).single();
      storedHash = data?.pin_hash;
    } else {
      const { data } = await supabase.from('usuarios').select('pin_hash').eq('id', payload.sub).single();
      storedHash = data?.pin_hash;
    }

    if (!storedHash) return res.json({ needsSetup: true });

    const valid = await bcrypt.compare(pin, storedHash);
    if (!valid) return res.status(401).json({ error: 'PIN incorreto.' });

    const token = signJWT({ ...payload, pinVerified: true });
    return res.json({ token, verified: true });
  } catch (err) {
    return res.status(500).json({ error: 'Erro interno.' });
  }
}


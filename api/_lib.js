// api/_lib.js — helpers compartilhados entre todas as functions
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

export const PLAN_CONFIG = {
  Bronze:  { modules: ['dominio','site'],                                     dailyLimit: 20  },
  Gold:    { modules: ['dominio','site','cep','username','termo'],             dailyLimit: 50  },
  Diamond: { modules: ['dominio','site','cep','username','termo','cnpj','ip'], dailyLimit: 120 },
};

// Verifica JWT e retorna payload
export function verifyJWT(req) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) throw new Error('Não autenticado.');
  return jwt.verify(header.slice(7), process.env.JWT_SECRET);
}

// Gera JWT
export function signJWT(payload) {
  return jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '8h' });
}

// Headers de segurança em toda resposta
export function secureHeaders(res) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
}

// Contador diário
export async function getDailyCount(usuario) {
  const today = new Date().toISOString().slice(0, 10);
  const { data } = await supabase.from('contadores_diarios')
    .select('total').eq('usuario', usuario).eq('data', today).single();
  return data?.total || 0;
}

export async function incDailyCount(usuario) {
  const today = new Date().toISOString().slice(0, 10);
  const { data } = await supabase.from('contadores_diarios')
    .select('id,total').eq('usuario', usuario).eq('data', today).single();
  if (data) {
    await supabase.from('contadores_diarios').update({ total: data.total + 1 }).eq('id', data.id);
  } else {
    await supabase.from('contadores_diarios').insert({ usuario, data: today, total: 1 });
  }
}

export async function addLog(usuario, modulo, termo) {
  await supabase.from('logs').insert({ usuario, modulo, termo });
}

export function sanitize(str, max = 200) {
  return String(str || '').trim().slice(0, max);
}


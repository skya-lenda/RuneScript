/**
 * DataGov OSINT — Backend Seguro
 * Stack: Node.js + Express + Supabase (server-side apenas)
 *
 * SEGREDOS: Nunca expostos ao frontend. Ficam em variáveis de ambiente (.env)
 *
 * Instalar: npm install express bcryptjs jsonwebtoken @supabase/supabase-js
 *           express-rate-limit helmet cors dotenv
 *
 * Rodar:    node server.js
 */

import 'dotenv/config';
import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { createClient } from '@supabase/supabase-js';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import cors from 'cors';
import crypto from 'crypto';

const app = express();

/* ═══════════════════════════════════════════════════════
   VARIÁVEIS DE AMBIENTE (.env) — NUNCA NO FRONTEND
   ═══════════════════════════════════════════════════════
   SUPABASE_URL=https://xxxx.supabase.co
   SUPABASE_SERVICE_KEY=eyJhbGci...          ← service_role key (não a anon!)
   JWT_SECRET=uma_string_aleatoria_longa_256bits
   ADMIN_USERNAME=dafyganggov               ← só no servidor
   ADMIN_PASSWORD_HASH=<bcrypt hash>         ← gere com: node -e "const b=require('bcryptjs');console.log(b.hashSync('suaSenha',12))"
   ANTHROPIC_API_KEY=sk-ant-...
   PORT=3001
   FRONTEND_ORIGIN=https://seudominio.com
*/

// ─── Verificar segredos obrigatórios ───
const REQUIRED_ENV = ['SUPABASE_URL','SUPABASE_SERVICE_KEY','JWT_SECRET','ADMIN_USERNAME','ADMIN_PASSWORD_HASH'];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.error(`FATAL: variável de ambiente ${key} não definida`);
    process.exit(1);
  }
}

// ─── Supabase (service key — só server-side) ───
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY,   // ← service_role, nunca a anon key!
  { auth: { autoRefreshToken: false, persistSession: false } }
);

const JWT_SECRET  = process.env.JWT_SECRET;
const JWT_EXPIRES = '8h';

/* ═══════════════════════════════════════════════════════
   CONFIGURAÇÃO DE PLANOS (server-side, não editável pelo cliente)
   ═══════════════════════════════════════════════════════ */
const PLAN_CONFIG = {
  Bronze:  { modules: ['dominio','site'],                                     dailyLimit: 20  },
  Gold:    { modules: ['dominio','site','cep','username','termo'],             dailyLimit: 50  },
  Diamond: { modules: ['dominio','site','cep','username','termo','cnpj','ip'], dailyLimit: 120 },
};

/* ══════════════════════════════════════════════════════════════════
   MIDDLEWARES DE SEGURANÇA
   ══════════════════════════════════════════════════════════════════ */

// 1. Cabeçalhos de segurança HTTP (helmet)
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc:     ["'self'"],
      scriptSrc:      ["'self'"],
      styleSrc:       ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com', 'https://cdnjs.cloudflare.com'],
      fontSrc:        ["'self'", 'https://fonts.gstatic.com', 'https://cdnjs.cloudflare.com'],
      imgSrc:         ["'self'", 'data:', 'https:'],
      connectSrc:     ["'self'"],     // frontend só fala com NOSSO backend
      frameSrc:       ["'none'"],
      objectSrc:      ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  crossOriginEmbedderPolicy: false,
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
}));

// 2. CORS — só aceita origem do frontend configurado
app.use(cors({
  origin: process.env.FRONTEND_ORIGIN || 'http://localhost:5500',
  credentials: true,
  methods: ['GET','POST','PUT','DELETE'],
  allowedHeaders: ['Content-Type','Authorization','X-CSRF-Token'],
}));

app.use(express.json({ limit: '16kb' }));   // limita payload para prevenir DoS

// 3. Rate limiting global
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,   // 15 minutos
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Muitas requisições. Tente novamente em alguns minutos.' },
});
app.use(globalLimiter);

// 4. Rate limiting agressivo para login (força bruta)
const loginLimiter = rateLimit({
  windowMs: 60 * 1000,        // 1 minuto
  max: 5,                     // máx 5 tentativas por IP por minuto
  skipSuccessfulRequests: true,
  message: { error: 'Muitas tentativas de login. Aguarde 1 minuto.' },
  keyGenerator: (req) => req.ip + ':' + (req.body?.username || ''),
});

// 5. Rate limiting para consultas de módulos
const consultLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  message: { error: 'Muitas consultas por minuto.' },
});

/* ══════════════════════════════════════════════════════════════════
   TOKENS CSRF
   ══════════════════════════════════════════════════════════════════ */
const csrfTokens = new Map(); // produção: usar Redis com TTL

function generateCsrfToken() {
  return crypto.randomBytes(32).toString('hex');
}

function validateCsrf(req, res, next) {
  const token = req.headers['x-csrf-token'];
  const sessionId = req.jwtPayload?.sub;
  if (!token || !sessionId || csrfTokens.get(sessionId) !== token) {
    return res.status(403).json({ error: 'Token CSRF inválido.' });
  }
  next();
}

/* ══════════════════════════════════════════════════════════════════
   MIDDLEWARE DE AUTENTICAÇÃO JWT
   ══════════════════════════════════════════════════════════════════ */
function requireAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Não autenticado.' });
  }
  try {
    const payload = jwt.verify(header.slice(7), JWT_SECRET);
    req.jwtPayload = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Token expirado ou inválido.' });
  }
}

function requireAdmin(req, res, next) {
  if (!req.jwtPayload?.isAdmin) {
    return res.status(403).json({ error: 'Acesso negado.' });
  }
  next();
}

/* ══════════════════════════════════════════════════════════════════
   HELPERS
   ══════════════════════════════════════════════════════════════════ */
function sanitizeString(str, maxLen = 200) {
  if (typeof str !== 'string') return '';
  return str.trim().slice(0, maxLen);
}

async function getPlanConfig(username) {
  const { data } = await supabase
    .from('usuarios')
    .select('plano')
    .eq('username', username)
    .single();
  return PLAN_CONFIG[data?.plano] || PLAN_CONFIG.Bronze;
}

async function getDailyCount(username) {
  const today = new Date().toISOString().slice(0, 10);
  const { data } = await supabase
    .from('contadores_diarios')
    .select('total')
    .eq('usuario', username)
    .eq('data', today)
    .single();
  return data?.total || 0;
}

async function incDailyCount(username) {
  const today = new Date().toISOString().slice(0, 10);
  const { data } = await supabase
    .from('contadores_diarios')
    .select('id,total')
    .eq('usuario', username)
    .eq('data', today)
    .single();
  if (data) {
    await supabase.from('contadores_diarios').update({ total: data.total + 1 }).eq('id', data.id);
  } else {
    await supabase.from('contadores_diarios').insert({ usuario: username, data: today, total: 1 });
  }
}

/* ══════════════════════════════════════════════════════════════════
   ROTAS DE AUTENTICAÇÃO
   ══════════════════════════════════════════════════════════════════ */

// GET /api/csrf — obter token CSRF após login
app.get('/api/csrf', requireAuth, (req, res) => {
  const token = generateCsrfToken();
  csrfTokens.set(req.jwtPayload.sub, token);
  res.json({ csrfToken: token });
});

// POST /api/auth/login
app.post('/api/auth/login', loginLimiter, async (req, res) => {
  const username = sanitizeString(req.body?.username || '').toLowerCase();
  const password  = sanitizeString(req.body?.password || '', 128);

  if (!username || !password) {
    return res.status(400).json({ error: 'Usuário e senha obrigatórios.' });
  }

  // Delay constante para prevenir timing attacks
  await new Promise(r => setTimeout(r, 300 + Math.random() * 200));

  try {
    // Admin
    if (username === process.env.ADMIN_USERNAME) {
      const valid = await bcrypt.compare(password, process.env.ADMIN_PASSWORD_HASH);
      if (!valid) return res.status(401).json({ error: 'Credenciais inválidas.' });

      const token = jwt.sign(
        { sub: `admin:${username}`, isAdmin: true, username },
        JWT_SECRET,
        { expiresIn: JWT_EXPIRES }
      );
      return res.json({ token, role: 'admin', username });
    }

    // Usuário regular
    const { data: user, error } = await supabase
      .from('usuarios')
      .select('id, username, senha_hash, plano, pin_hash')
      .eq('username', username)
      .single();

    if (error || !user) return res.status(401).json({ error: 'Credenciais inválidas.' });

    const valid = await bcrypt.compare(password, user.senha_hash);
    if (!valid) return res.status(401).json({ error: 'Credenciais inválidas.' });

    const token = jwt.sign(
      { sub: user.id, isAdmin: false, username: user.username, plano: user.plano },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES }
    );

    return res.json({
      token,
      role: 'user',
      username: user.username,
      plano: user.plano,
      hasPinSet: !!user.pin_hash,
    });
  } catch (err) {
    console.error('[login]', err.message);
    return res.status(500).json({ error: 'Erro interno.' });
  }
});

// POST /api/auth/verify-pin
app.post('/api/auth/verify-pin', requireAuth, async (req, res) => {
  const pin = sanitizeString(req.body?.pin || '', 6);
  if (!/^\d{6}$/.test(pin)) return res.status(400).json({ error: 'PIN deve ter 6 dígitos.' });

  const { sub, isAdmin, username } = req.jwtPayload;

  try {
    let storedHash;

    if (isAdmin) {
      // Admin: PIN salvo no banco de forma segura (não no localStorage!)
      const { data } = await supabase
        .from('admin_pins')
        .select('pin_hash')
        .eq('username', username)
        .single();
      storedHash = data?.pin_hash;
    } else {
      const { data } = await supabase
        .from('usuarios')
        .select('pin_hash')
        .eq('id', sub)
        .single();
      storedHash = data?.pin_hash;
    }

    if (!storedHash) return res.json({ needsSetup: true });

    const valid = await bcrypt.compare(pin, storedHash);
    if (!valid) return res.status(401).json({ error: 'PIN incorreto.' });

    // Emitir token "verified" com flag adicional
    const payload = { ...req.jwtPayload, pinVerified: true };
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES });
    return res.json({ token, verified: true });
  } catch (err) {
    console.error('[verify-pin]', err.message);
    return res.status(500).json({ error: 'Erro interno.' });
  }
});

// POST /api/auth/set-pin
app.post('/api/auth/set-pin', requireAuth, async (req, res) => {
  const pin = sanitizeString(req.body?.pin || '', 6);
  if (!/^\d{6}$/.test(pin)) return res.status(400).json({ error: 'PIN deve ter 6 dígitos.' });

  const { sub, isAdmin, username } = req.jwtPayload;
  const pinHash = await bcrypt.hash(pin, 12);

  try {
    if (isAdmin) {
      await supabase.from('admin_pins').upsert({ username, pin_hash: pinHash });
    } else {
      await supabase.from('usuarios').update({ pin_hash: pinHash }).eq('id', sub);
    }
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: 'Erro interno.' });
  }
});

/* ══════════════════════════════════════════════════════════════════
   ROTAS DE MÓDULOS — VALIDAÇÃO SERVER-SIDE DE PLANO E LIMITE
   ══════════════════════════════════════════════════════════════════ */

// Middleware: verifica plano e limite diário ANTES de executar qualquer módulo
async function requireModuleAccess(moduleId) {
  return async (req, res, next) => {
    if (req.jwtPayload.isAdmin) return next(); // admin tem acesso irrestrito

    const username = req.jwtPayload.username;

    // Re-busca plano no banco (não confia no JWT sozinho para permissões)
    const { data: user } = await supabase
      .from('usuarios')
      .select('plano')
      .eq('username', username)
      .single();

    const plano = user?.plano || 'Bronze';
    const cfg   = PLAN_CONFIG[plano] || PLAN_CONFIG.Bronze;

    // Verifica se o módulo está liberado para o plano
    if (!cfg.modules.includes(moduleId)) {
      return res.status(403).json({
        error: `Módulo "${moduleId}" não disponível no plano ${plano}.`
      });
    }

    // Verifica limite diário
    const used = await getDailyCount(username);
    if (used >= cfg.dailyLimit) {
      return res.status(429).json({
        error: `Limite diário de ${cfg.dailyLimit} consultas atingido.`
      });
    }

    req.userPlano = plano;
    next();
  };
}

// POST /api/modulos/cep
app.post('/api/modulos/cep', consultLimiter, requireAuth, await requireModuleAccess('cep'), async (req, res) => {
  const cep = sanitizeString(req.body?.termo || '').replace(/\D/g, '');
  if (cep.length !== 8) return res.status(400).json({ error: 'CEP inválido.' });

  try {
    const r = await fetch(`https://viacep.com.br/ws/${cep}/json/`);
    if (!r.ok) throw new Error('Serviço ViaCEP indisponível.');
    const d = await r.json();
    if (d.erro) return res.status(404).json({ error: 'CEP não encontrado.' });

    await incDailyCount(req.jwtPayload.username);
    await supabase.from('logs').insert({
      usuario: req.jwtPayload.username,
      modulo: 'CEP',
      termo: cep,
    });

    // Retorna só o necessário (nunca dados internos do Supabase)
    return res.json({
      cep: d.cep, logradouro: d.logradouro, bairro: d.bairro,
      cidade: d.localidade, uf: d.uf, ddd: d.ddd, ibge: d.ibge,
    });
  } catch (err) {
    return res.status(502).json({ error: err.message });
  }
});

// POST /api/modulos/cnpj
app.post('/api/modulos/cnpj', consultLimiter, requireAuth, await requireModuleAccess('cnpj'), async (req, res) => {
  const cnpj = sanitizeString(req.body?.termo || '').replace(/\D/g, '');
  if (cnpj.length !== 14) return res.status(400).json({ error: 'CNPJ inválido.' });

  try {
    const r = await fetch(`https://receitaws.com.br/v1/cnpj/${cnpj}`, {
      headers: { Accept: 'application/json' },
    });
    if (r.status === 429) return res.status(429).json({ error: 'Limite da API de CNPJ. Aguarde.' });
    if (!r.ok) throw new Error('Erro ao consultar CNPJ.');
    const d = await r.json();
    if (d.status === 'ERROR') return res.status(404).json({ error: d.message || 'CNPJ não encontrado.' });

    await incDailyCount(req.jwtPayload.username);
    await supabase.from('logs').insert({ usuario: req.jwtPayload.username, modulo: 'CNPJ', termo: cnpj });

    return res.json({
      cnpj: d.cnpj, nome: d.nome, situacao: d.situacao,
      abertura: d.abertura, natureza_juridica: d.natureza_juridica,
      capital_social: d.capital_social, porte: d.porte,
      municipio: d.municipio, uf: d.uf, telefone: d.telefone,
      atividade_principal: d.atividade_principal?.[0]?.text || '—',
      socios: d.qsa?.map(s => s.nome) || [],
    });
  } catch (err) {
    return res.status(502).json({ error: err.message });
  }
});

// POST /api/modulos/ip
app.post('/api/modulos/ip', consultLimiter, requireAuth, await requireModuleAccess('ip'), async (req, res) => {
  const ip = sanitizeString(req.body?.termo || '');
  if (!/^(\d{1,3}\.){3}\d{1,3}$|^[0-9a-fA-F:]+$/.test(ip)) {
    return res.status(400).json({ error: 'IP inválido.' });
  }

  try {
    const r = await fetch(`https://ipapi.co/${ip}/json/`);
    if (!r.ok) throw new Error('Serviço de IP indisponível.');
    const d = await r.json();
    if (d.error) return res.status(404).json({ error: 'IP não encontrado.' });

    await incDailyCount(req.jwtPayload.username);
    await supabase.from('logs').insert({ usuario: req.jwtPayload.username, modulo: 'IP', termo: ip });

    return res.json({
      ip, pais: d.country_name, pais_code: d.country,
      cidade: d.city, asn: d.asn, org: d.org, timezone: d.timezone,
      latitude: d.latitude, longitude: d.longitude,
    });
  } catch (err) {
    return res.status(502).json({ error: err.message });
  }
});

// POST /api/modulos/dominio
app.post('/api/modulos/dominio', consultLimiter, requireAuth, await requireModuleAccess('dominio'), async (req, res) => {
  const dominio = sanitizeString(req.body?.termo || '')
    .replace(/^https?:\/\//i, '').replace(/\//g, '').toLowerCase();
  if (!dominio.includes('.') || dominio.length > 253) {
    return res.status(400).json({ error: 'Domínio inválido.' });
  }

  try {
    let rdapData = null, aRecords = '—';

    // RDAP
    try {
      const tld = dominio.split('.').pop();
      const boot = await (await fetch('https://data.iana.org/rdap/dns.json')).json();
      for (const svc of boot.services) {
        if (svc[0].includes(tld)) {
          const rr = await fetch(`${svc[1][0]}domain/${dominio}`);
          if (rr.ok) rdapData = await rr.json();
          break;
        }
      }
    } catch {}

    // DNS
    try {
      const dns = await fetch(
        `https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(dominio)}&type=A`,
        { headers: { Accept: 'application/dns-json' } }
      );
      const dd = await dns.json();
      const ans = dd.Answer?.filter(r => r.type === 1).map(r => r.data);
      if (ans?.length) aRecords = ans.join(', ');
    } catch {}

    await incDailyCount(req.jwtPayload.username);
    await supabase.from('logs').insert({ usuario: req.jwtPayload.username, modulo: 'Domínio', termo: dominio });

    const registrar = rdapData?.entities?.find(e => e.roles?.includes('registrar'))
      ?.vcardArray?.[1]?.find(v => v[0] === 'fn')?.[3] || '—';
    const created = rdapData?.events?.find(e => e.eventAction === 'registration')?.eventDate;
    const expires = rdapData?.events?.find(e => e.eventAction === 'expiration')?.eventDate;
    const ns = rdapData?.nameservers?.map(n => n.ldhName) || [];

    return res.json({ dominio, registrar, criado: created, expira: expires, nameservers: ns, ips: aRecords });
  } catch (err) {
    return res.status(502).json({ error: err.message });
  }
});

// POST /api/modulos/site
app.post('/api/modulos/site', consultLimiter, requireAuth, await requireModuleAccess('site'), async (req, res) => {
  let target = sanitizeString(req.body?.termo || '');
  if (!/^https?:\/\//i.test(target)) target = 'https://' + target;
  let u;
  try { u = new URL(target); } catch { return res.status(400).json({ error: 'URL inválida.' }); }

  const hostname = u.hostname;
  let ipAddr = '—';

  try {
    const dns = await fetch(
      `https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(hostname)}&type=A`,
      { headers: { Accept: 'application/dns-json' } }
    );
    const dd = await dns.json();
    const ans = dd.Answer?.filter(r => r.type === 1).map(r => r.data);
    if (ans?.length) ipAddr = ans.join(', ');
  } catch {}

  await incDailyCount(req.jwtPayload.username);
  await supabase.from('logs').insert({ usuario: req.jwtPayload.username, modulo: 'Site', termo: hostname });

  return res.json({ url: target, hostname, ips: ipAddr, https: target.startsWith('https://') });
});

// POST /api/modulos/username  e  /api/modulos/termo  — usa API Anthropic server-side
async function callAnthropicServerSide(prompt) {
  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': process.env.ANTHROPIC_API_KEY,       // ← Chave segura no servidor
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1200,
      tools: [{ type: 'web_search_20250305', name: 'web_search' }],
      system: 'Você é um motor OSINT. Retorne JSON puro sem markdown. Nunca invente dados.',
      messages: [{ role: 'user', content: prompt }],
    }),
  });
  if (!r.ok) throw new Error(`Anthropic API: ${r.status}`);
  const data = await r.json();
  return data.content?.filter(c => c.type === 'text').map(c => c.text).join('') || '';
}

app.post('/api/modulos/username', consultLimiter, requireAuth, await requireModuleAccess('username'), async (req, res) => {
  const username = sanitizeString(req.body?.termo || '').replace(/^@/, '');
  if (!username || username.length < 2 || username.length > 50) {
    return res.status(400).json({ error: 'Username inválido.' });
  }

  try {
    const text = await callAnthropicServerSide(
      `Pesquise o username "@${username}" em GitHub, Instagram, Twitter/X, Reddit, TikTok, YouTube, LinkedIn, Twitch. ` +
      `Retorne JSON: {"results":[{platform,found,username,displayName,bio,followers,url}]}`
    );
    let results = [];
    try { results = JSON.parse(text.replace(/```json|```/g,'').trim()).results || []; } catch {}

    await incDailyCount(req.jwtPayload.username);
    await supabase.from('logs').insert({ usuario: req.jwtPayload.username, modulo: 'Username', termo: username });

    return res.json({ results });
  } catch (err) {
    return res.status(502).json({ error: err.message });
  }
});

app.post('/api/modulos/termo', consultLimiter, requireAuth, await requireModuleAccess('termo'), async (req, res) => {
  const termo = sanitizeString(req.body?.termo || '', 300);
  if (!termo) return res.status(400).json({ error: 'Termo obrigatório.' });

  try {
    const text = await callAnthropicServerSide(
      `Busca OSINT sobre: "${termo}". Pesquise em fontes diversas. ` +
      `JSON: {"results":[{source,title,summary,url,type}]}. type: social/news/forum/site/doc/gov. Máx 8 resultados.`
    );
    let results = [];
    try { results = JSON.parse(text.replace(/```json|```/g,'').trim()).results || []; } catch {}

    await incDailyCount(req.jwtPayload.username);
    await supabase.from('logs').insert({ usuario: req.jwtPayload.username, modulo: 'Termo', termo });

    return res.json({ results });
  } catch (err) {
    return res.status(502).json({ error: err.message });
  }
});

/* ══════════════════════════════════════════════════════════════════
   ROTAS DO DASHBOARD (dados do usuário logado)
   ══════════════════════════════════════════════════════════════════ */

// GET /api/user/me
app.get('/api/user/me', requireAuth, async (req, res) => {
  if (req.jwtPayload.isAdmin) return res.json({ isAdmin: true });

  const { data: user } = await supabase
    .from('usuarios')
    .select('username, plano')
    .eq('id', req.jwtPayload.sub)
    .single();

  if (!user) return res.status(404).json({ error: 'Usuário não encontrado.' });

  const used      = await getDailyCount(user.username);
  const cfg       = PLAN_CONFIG[user.plano] || PLAN_CONFIG.Bronze;
  const remaining = Math.max(0, cfg.dailyLimit - used);

  return res.json({
    username:        user.username,
    plano:           user.plano,
    dailyUsed:       used,
    dailyRemaining:  remaining,
    dailyLimit:      cfg.dailyLimit,
    modulesAllowed:  cfg.modules,
  });
});

/* ══════════════════════════════════════════════════════════════════
   ROTAS ADMIN — requer isAdmin + CSRF
   ══════════════════════════════════════════════════════════════════ */

// GET /api/admin/stats
app.get('/api/admin/stats', requireAuth, requireAdmin, async (req, res) => {
  const [{ count: users }, { data: logs }] = await Promise.all([
    supabase.from('usuarios').select('*', { count: 'exact', head: true }),
    supabase.from('logs').select('ts').order('ts', { ascending: false }).limit(500),
  ]);
  const today = new Date().toISOString().slice(0, 10);
  return res.json({
    totalUsers:    users,
    totalLogs:     logs?.length || 0,
    logsHoje:      logs?.filter(l => l.ts?.startsWith(today)).length || 0,
  });
});

// GET /api/admin/users
app.get('/api/admin/users', requireAuth, requireAdmin, async (req, res) => {
  const { data } = await supabase
    .from('usuarios')
    .select('id, username, plano, data_criacao')
    .order('data_criacao', { ascending: false });
  return res.json(data || []);
});

// POST /api/admin/users — criar usuário
app.post('/api/admin/users', requireAuth, requireAdmin, validateCsrf, async (req, res) => {
  const username = sanitizeString(req.body?.username || '').toLowerCase();
  const password = sanitizeString(req.body?.password || '', 128);
  const plano    = ['Bronze','Gold','Diamond'].includes(req.body?.plano) ? req.body.plano : 'Bronze';

  if (!username || !password) return res.status(400).json({ error: 'Campos obrigatórios.' });
  if (!/^[a-z0-9_]{3,20}$/.test(username)) return res.status(400).json({ error: 'Username inválido.' });
  if (password.length < 8) return res.status(400).json({ error: 'Senha mínima: 8 caracteres.' });

  const { data: exists } = await supabase.from('usuarios').select('id').eq('username', username).single();
  if (exists) return res.status(409).json({ error: 'Usuário já existe.' });

  // bcrypt server-side — nunca SHA-256 puro!
  const senhaHash = await bcrypt.hash(password, 12);
  const { error } = await supabase.from('usuarios').insert({ username, senha_hash: senhaHash, plano });
  if (error) return res.status(500).json({ error: 'Erro ao criar usuário.' });

  return res.status(201).json({ ok: true, username, plano });
});

// PUT /api/admin/users/:id/plano
app.put('/api/admin/users/:id/plano', requireAuth, requireAdmin, validateCsrf, async (req, res) => {
  const { id } = req.params;
  const plano = ['Bronze','Gold','Diamond'].includes(req.body?.plano) ? req.body.plano : null;
  if (!plano) return res.status(400).json({ error: 'Plano inválido.' });
  await supabase.from('usuarios').update({ plano }).eq('id', id);
  return res.json({ ok: true });
});

// DELETE /api/admin/users/:id
app.delete('/api/admin/users/:id', requireAuth, requireAdmin, validateCsrf, async (req, res) => {
  await supabase.from('usuarios').delete().eq('id', req.params.id);
  return res.json({ ok: true });
});

// GET /api/admin/logs
app.get('/api/admin/logs', requireAuth, requireAdmin, async (req, res) => {
  const { data } = await supabase
    .from('logs')
    .select('usuario, modulo, termo, ts')
    .order('ts', { ascending: false })
    .limit(500);
  return res.json(data || []);
});

// DELETE /api/admin/logs
app.delete('/api/admin/logs', requireAuth, requireAdmin, validateCsrf, async (req, res) => {
  await supabase.from('logs').delete().neq('id', '00000000-0000-0000-0000-000000000000');
  return res.json({ ok: true });
});

/* ══════════════════════════════════════════════════════════════════
   TRATAMENTO DE ERROS GLOBAL
   ══════════════════════════════════════════════════════════════════ */
app.use((err, req, res, _next) => {
  console.error('[server error]', err.message);
  // Nunca expor stack trace ao cliente
  res.status(500).json({ error: 'Erro interno do servidor.' });
});

// 404
app.use((req, res) => res.status(404).json({ error: 'Rota não encontrada.' }));

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`[DataGov API] rodando na porta ${PORT}`));


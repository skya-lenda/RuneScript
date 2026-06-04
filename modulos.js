// =============================================================================
// api/modulos.js — Roteador único para todos os módulos de consulta
//
// Uso: POST /api/modulos
// Body: { "tipo": "cep" | "cnpj" | "ip" | "dominio" | "site" | "termo" | "username", "termo": "..." }
//
// Planos e limites definidos em _lib.js:
//   Bronze  → dominio, site                                    (20/dia)
//   Gold    → dominio, site, cep, username, termo              (50/dia)
//   Diamond → dominio, site, cep, username, termo, cnpj, ip   (120/dia)
// =============================================================================

import {
  supabase,
  verifyJWT,
  secureHeaders,
  getDailyCount,
  incDailyCount,
  addLog,
  PLAN_CONFIG,
  sanitize,
} from './_lib.js';

// ─────────────────────────────────────────────────────────────────────────────
// MÓDULO: CEP
// Fonte: ViaCEP (https://viacep.com.br) — gratuito, sem chave
// Valida: exatamente 8 dígitos numéricos
// Retorna: logradouro, bairro, cidade, UF, DDD, código IBGE
// ─────────────────────────────────────────────────────────────────────────────
async function handleCEP(req, res, payload) {
  // Remove qualquer caractere não-numérico (ex: "01310-100" → "01310100")
  const cep = sanitize(req.body?.termo || '').replace(/\D/g, '');

  if (!cep) {
    return res.status(400).json({ error: 'CEP não informado.' });
  }
  if (cep.length !== 8) {
    return res.status(400).json({ error: 'CEP inválido. Informe 8 dígitos.' });
  }

  try {
    const response = await fetch(`https://viacep.com.br/ws/${cep}/json/`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(8000),
    });

    if (!response.ok) {
      return res.status(502).json({ error: 'ViaCEP indisponível. Tente novamente.' });
    }

    const data = await response.json();

    if (data.erro) {
      return res.status(404).json({ error: 'CEP não encontrado na base dos Correios.' });
    }

    await incDailyCount(payload.username);
    await addLog(payload.username, 'CEP', cep);

    return res.json({
      cep:        data.cep,
      logradouro: data.logradouro || '—',
      complemento: data.complemento || '—',
      bairro:     data.bairro || '—',
      cidade:     data.localidade,
      uf:         data.uf,
      ddd:        data.ddd || '—',
      ibge:       data.ibge || '—',
      gia:        data.gia || '—',
      siafi:      data.siafi || '—',
    });
  } catch (err) {
    if (err.name === 'TimeoutError') {
      return res.status(504).json({ error: 'Tempo limite excedido ao consultar ViaCEP.' });
    }
    return res.status(502).json({ error: 'Erro ao consultar ViaCEP.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MÓDULO: CNPJ
// Fonte: ReceitaWS (https://receitaws.com.br) — gratuito, sem chave
// Valida: exatamente 14 dígitos numéricos
// Retorna: razão social, situação, abertura, sócios, atividade, endereço
// ─────────────────────────────────────────────────────────────────────────────
async function handleCNPJ(req, res, payload) {
  // Remove pontuação: "12.345.678/0001-99" → "12345678000199"
  const cnpj = sanitize(req.body?.termo || '').replace(/\D/g, '');

  if (!cnpj) {
    return res.status(400).json({ error: 'CNPJ não informado.' });
  }
  if (cnpj.length !== 14) {
    return res.status(400).json({ error: 'CNPJ inválido. Informe 14 dígitos.' });
  }

  try {
    const response = await fetch(`https://receitaws.com.br/v1/cnpj/${cnpj}`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(10000),
    });

    // ReceitaWS retorna 429 quando o limite gratuito (1 req/min) é atingido
    if (response.status === 429) {
      return res.status(429).json({ error: 'Muitas consultas seguidas. Aguarde 1 minuto.' });
    }
    if (!response.ok) {
      return res.status(502).json({ error: 'ReceitaWS indisponível. Tente novamente.' });
    }

    const data = await response.json();

    if (data.status === 'ERROR') {
      return res.status(404).json({ error: data.message || 'CNPJ não encontrado na Receita Federal.' });
    }

    await incDailyCount(payload.username);
    await addLog(payload.username, 'CNPJ', cnpj);

    return res.json({
      cnpj:               data.cnpj,
      nome:               data.nome,
      fantasia:           data.fantasia || '—',
      situacao:           data.situacao,
      data_situacao:      data.data_situacao || '—',
      motivo_situacao:    data.motivo_situacao || '—',
      abertura:           data.abertura,
      natureza_juridica:  data.natureza_juridica,
      capital_social:     data.capital_social,
      porte:              data.porte,
      tipo:               data.tipo,
      logradouro:         data.logradouro || '—',
      numero:             data.numero || '—',
      complemento:        data.complemento || '—',
      bairro:             data.bairro || '—',
      municipio:          data.municipio,
      uf:                 data.uf,
      cep:                data.cep || '—',
      telefone:           data.telefone || '—',
      email:              data.email || '—',
      atividade_principal: data.atividade_principal?.[0]?.text || '—',
      atividades_secundarias: data.atividades_secundarias?.map(a => a.text) || [],
      socios: data.qsa?.map(s => ({
        nome:         s.nome,
        qualificacao: s.qual,
      })) || [],
    });
  } catch (err) {
    if (err.name === 'TimeoutError') {
      return res.status(504).json({ error: 'Tempo limite excedido ao consultar Receita Federal.' });
    }
    return res.status(502).json({ error: 'Erro ao consultar CNPJ.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MÓDULO: IP
// Fonte: ipapi.co — gratuito até 1.000 req/dia sem chave
// Valida: IPv4 (ex: 8.8.8.8) ou IPv6 (ex: 2001:4860:4860::8888)
// Retorna: país, cidade, ASN, organização, timezone, coordenadas
// ─────────────────────────────────────────────────────────────────────────────
async function handleIP(req, res, payload) {
  const ip = sanitize(req.body?.termo || '').trim();

  if (!ip) {
    return res.status(400).json({ error: 'IP não informado.' });
  }

  // Aceita IPv4 e IPv6
  const isIPv4 = /^(\d{1,3}\.){3}\d{1,3}$/.test(ip);
  const isIPv6 = /^[0-9a-fA-F:]+$/.test(ip) && ip.includes(':');
  if (!isIPv4 && !isIPv6) {
    return res.status(400).json({ error: 'Formato de IP inválido.' });
  }

  // Bloqueia IPs privados/reservados — sem sentido consultar
  if (/^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|127\.|0\.|169\.254\.)/.test(ip)) {
    return res.status(400).json({ error: 'IP privado ou reservado. Informe um IP público.' });
  }

  try {
    const response = await fetch(`https://ipapi.co/${ip}/json/`, {
      headers: { Accept: 'application/json', 'User-Agent': 'datagov-osint/1.0' },
      signal: AbortSignal.timeout(8000),
    });

    if (!response.ok) {
      return res.status(502).json({ error: 'Serviço de geolocalização indisponível.' });
    }

    const data = await response.json();

    if (data.error) {
      return res.status(404).json({ error: data.reason || 'IP não encontrado.' });
    }

    await incDailyCount(payload.username);
    await addLog(payload.username, 'IP', ip);

    return res.json({
      ip,
      versao:     isIPv4 ? 'IPv4' : 'IPv6',
      pais:       data.country_name || '—',
      pais_code:  data.country || '—',
      regiao:     data.region || '—',
      cidade:     data.city || '—',
      cep:        data.postal || '—',
      asn:        data.asn || '—',
      org:        data.org || '—',
      isp:        data.org || '—',
      timezone:   data.timezone || '—',
      latitude:   data.latitude ?? null,
      longitude:  data.longitude ?? null,
    });
  } catch (err) {
    if (err.name === 'TimeoutError') {
      return res.status(504).json({ error: 'Tempo limite excedido ao consultar geolocalização.' });
    }
    return res.status(502).json({ error: 'Erro ao consultar IP.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MÓDULO: DOMÍNIO
// Fontes: IANA RDAP (registro/expiração/registrar) + Cloudflare DNS (IPs)
// Valida: string com pelo menos um ponto, sem espaços, máx 253 chars
// Retorna: registrar, datas, nameservers, IPs (A records)
// ─────────────────────────────────────────────────────────────────────────────
async function handleDominio(req, res, payload) {
  // Normaliza: remove protocolo e barra final
  const dominio = sanitize(req.body?.termo || '')
    .replace(/^https?:\/\//i, '')
    .replace(/\/.*$/, '')
    .toLowerCase()
    .trim();

  if (!dominio) {
    return res.status(400).json({ error: 'Domínio não informado.' });
  }
  if (!dominio.includes('.') || dominio.length > 253 || /\s/.test(dominio)) {
    return res.status(400).json({ error: 'Domínio inválido.' });
  }

  let rdapData = null;
  let aRecords = [];
  const errors = [];

  // 1. Busca dados WHOIS via RDAP (protocolo aberto da IANA, sem chave)
  try {
    const tld = dominio.split('.').pop();
    const bootstrap = await fetch('https://data.iana.org/rdap/dns.json', {
      signal: AbortSignal.timeout(6000),
    });
    const { services } = await bootstrap.json();

    // Encontra o servidor RDAP responsável pelo TLD
    let rdapBase = null;
    for (const [tlds, servers] of services) {
      if (tlds.includes(tld) && servers[0]) {
        rdapBase = servers[0].endsWith('/') ? servers[0] : servers[0] + '/';
        break;
      }
    }

    if (rdapBase) {
      const rdapRes = await fetch(`${rdapBase}domain/${dominio}`, {
        headers: { Accept: 'application/rdap+json' },
        signal: AbortSignal.timeout(8000),
      });
      if (rdapRes.ok) {
        rdapData = await rdapRes.json();
      }
    }
  } catch {
    errors.push('RDAP indisponível para este TLD.');
  }

  // 2. Resolve IPs via Cloudflare DoH (DNS-over-HTTPS, sem chave)
  try {
    const dnsRes = await fetch(
      `https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(dominio)}&type=A`,
      {
        headers: { Accept: 'application/dns-json' },
        signal: AbortSignal.timeout(5000),
      }
    );
    const dnsData = await dnsRes.json();
    aRecords = dnsData.Answer?.filter(r => r.type === 1).map(r => r.data) || [];
  } catch {
    errors.push('Resolução DNS falhou.');
  }

  // Extrai campos do RDAP
  const registrar =
    rdapData?.entities
      ?.find(e => e.roles?.includes('registrar'))
      ?.vcardArray?.[1]
      ?.find(v => v[0] === 'fn')?.[3] || '—';

  const getEventDate = (action) =>
    rdapData?.events?.find(e => e.eventAction === action)?.eventDate || null;

  const nameservers = rdapData?.nameservers?.map(n => n.ldhName?.toLowerCase()) || [];
  const status = rdapData?.status || [];

  await incDailyCount(payload.username);
  await addLog(payload.username, 'Domínio', dominio);

  return res.json({
    dominio,
    registrar,
    status:      status.length ? status : ['—'],
    criado:      getEventDate('registration'),
    atualizado:  getEventDate('last changed'),
    expira:      getEventDate('expiration'),
    nameservers: nameservers.length ? nameservers : ['—'],
    ips:         aRecords.length ? aRecords : ['—'],
    ...(errors.length ? { avisos: errors } : {}),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MÓDULO: SITE
// Fonte: Cloudflare DoH — resolve hostname, verifica HTTPS, coleta headers
// Valida: URL com ou sem protocolo
// Retorna: hostname, IPs, HTTPS, status HTTP, headers de segurança
// ─────────────────────────────────────────────────────────────────────────────
async function handleSite(req, res, payload) {
  let target = sanitize(req.body?.termo || '').trim();

  if (!target) {
    return res.status(400).json({ error: 'URL não informada.' });
  }

  // Adiciona protocolo se não tiver
  if (!/^https?:\/\//i.test(target)) {
    target = 'https://' + target;
  }

  let parsed;
  try {
    parsed = new URL(target);
  } catch {
    return res.status(400).json({ error: 'URL inválida.' });
  }

  const hostname = parsed.hostname;
  let ips = [];
  let httpStatus = null;
  let headersInfo = {};

  // 1. Resolve IPs via Cloudflare DoH
  try {
    const dnsRes = await fetch(
      `https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(hostname)}&type=A`,
      {
        headers: { Accept: 'application/dns-json' },
        signal: AbortSignal.timeout(5000),
      }
    );
    const dnsData = await dnsRes.json();
    ips = dnsData.Answer?.filter(r => r.type === 1).map(r => r.data) || [];
  } catch { /* sem IPs */ }

  // 2. Faz HEAD request para verificar status e headers de segurança
  try {
    const headRes = await fetch(target, {
      method: 'HEAD',
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; datagov-osint/1.0)' },
      redirect: 'follow',
      signal: AbortSignal.timeout(8000),
    });
    httpStatus = headRes.status;

    // Verifica presença de headers de segurança importantes
    headersInfo = {
      strict_transport_security: headRes.headers.has('strict-transport-security'),
      content_security_policy:   headRes.headers.has('content-security-policy'),
      x_frame_options:           headRes.headers.has('x-frame-options'),
      x_content_type_options:    headRes.headers.has('x-content-type-options'),
      server:                    headRes.headers.get('server') || '—',
      powered_by:                headRes.headers.get('x-powered-by') || '—',
    };
  } catch { /* HEAD falhou */ }

  await incDailyCount(payload.username);
  await addLog(payload.username, 'Site', hostname);

  return res.json({
    url:         target,
    hostname,
    ips:         ips.length ? ips : ['—'],
    https:       target.startsWith('https://'),
    http_status: httpStatus,
    headers:     headersInfo,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MÓDULO: TERMO (busca OSINT por nome/e-mail/telefone/apelido)
// Fonte: DuckDuckGo HTML scraping + fallback API JSON — gratuito, sem chave
// Valida: string não vazia, máx 300 chars
// Retorna: lista de resultados com título, resumo, URL e tipo de fonte
// ─────────────────────────────────────────────────────────────────────────────
async function handleTermo(req, res, payload) {
  const termo = sanitize(req.body?.termo || '', 300);

  if (!termo) {
    return res.status(400).json({ error: 'Termo de busca não informado.' });
  }

  // Classifica o tipo de fonte pelo domínio da URL
  function classifyUrl(url = '') {
    if (/linkedin|twitter|x\.com|instagram|facebook|tiktok|github|reddit|youtube|twitch/i.test(url)) return 'social';
    if (/\.gov\.br|\.gov\.|\.jus\.br|\.mp\.br/i.test(url)) return 'gov';
    if (/forum|community|discuss|stackoverflow|quora|tapatalk/i.test(url)) return 'forum';
    if (/\.pdf($|\?)/i.test(url)) return 'doc';
    if (/g1\.|uol\.|folha\.|globo\.|r7\.|band\.|cnn\.|bbc\.|reuters\.|estadao\.|veja\./i.test(url)) return 'news';
    return 'site';
  }

  // Limpa tags HTML de uma string
  function stripHtml(str = '') {
    return str.replace(/<[^>]+>/g, '').replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#x27;/g, "'").trim();
  }

  const query = encodeURIComponent(termo);
  const results = [];

  // 1. Tentativa principal: scraping do HTML do DuckDuckGo
  try {
    const htmlRes = await fetch(`https://html.duckduckgo.com/html/?q=${query}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36',
        'Accept-Language': 'pt-BR,pt;q=0.9',
      },
      signal: AbortSignal.timeout(10000),
    });

    const html = await htmlRes.text();

    // Padrão de extração dos blocos de resultado do DDG
    const blockRe = /<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>([\s\S]*?)<\/a>[\s\S]*?class="result__url"[^>]*>([\s\S]*?)<\/[\w]+>[\s\S]*?class="result__snippet"[^>]*>([\s\S]*?)<\/a>/g;
    let match;
    while ((match = blockRe.exec(html)) !== null && results.length < 8) {
      const url     = match[1].startsWith('/') ? 'https://duckduckgo.com' + match[1] : match[1];
      const title   = stripHtml(match[2]);
      const source  = stripHtml(match[3]);
      const summary = stripHtml(match[4]);
      if (title && url && !url.includes('duckduckgo.com/y.js')) {
        results.push({ source, title, summary, url, type: classifyUrl(url) });
      }
    }
  } catch { /* segue para fallback */ }

  // 2. Fallback: API JSON pública do DuckDuckGo (InstantAnswer)
  if (results.length === 0) {
    try {
      const jsonRes = await fetch(
        `https://api.duckduckgo.com/?q=${query}&format=json&no_redirect=1&no_html=1&skip_disambig=1`,
        { signal: AbortSignal.timeout(8000) }
      );
      const jsonData = await jsonRes.json();
      const items = [
        ...(jsonData.RelatedTopics || []),
        ...(jsonData.Results || []),
      ];
      for (const item of items) {
        if (results.length >= 8) break;
        const url     = item.FirstURL || item.url || '';
        const text    = item.Text || item.snippet || '';
        const title   = text.split(' - ')[0] || url;
        const summary = text;
        if (url && title) {
          let source = '—';
          try { source = new URL(url).hostname; } catch {}
          results.push({ source, title, summary, url, type: classifyUrl(url) });
        }
      }
    } catch { /* nenhum resultado disponível */ }
  }

  await incDailyCount(payload.username);
  await addLog(payload.username, 'Termo', termo);

  return res.json({ results });
}

// ─────────────────────────────────────────────────────────────────────────────
// MÓDULO: USERNAME
// Fontes: GitHub API + Reddit API (públicas, sem chave) + HEAD nas demais
// Valida: mín 2 chars, remove @ inicial
// Retorna: por plataforma — found, displayName, bio, followers, url
// ─────────────────────────────────────────────────────────────────────────────
async function handleUsername(req, res, payload) {
  const username = sanitize(req.body?.termo || '').replace(/^@/, '').trim();

  if (!username) {
    return res.status(400).json({ error: 'Username não informado.' });
  }
  if (username.length < 2) {
    return res.status(400).json({ error: 'Username muito curto. Mínimo 2 caracteres.' });
  }
  if (username.length > 50) {
    return res.status(400).json({ error: 'Username muito longo. Máximo 50 caracteres.' });
  }

  const UA = 'Mozilla/5.0 (compatible; datagov-osint/1.0)';

  // Lista de plataformas a verificar
  // api:     endpoint com resposta JSON — extrai dados extras
  // apiKey:  campo no JSON que confirma existência
  // head:    apenas HEAD request — 200/301/302 = existe, 404 = não existe
  const PLATFORMS = [
    {
      platform: 'GitHub',
      url:      `https://github.com/${username}`,
      api:      `https://api.github.com/users/${username}`,
      apiKey:   'login',
      getExtra: (d) => ({
        displayName: d.name || null,
        bio:         d.bio || null,
        followers:   d.followers ?? null,
        repos:       d.public_repos ?? null,
      }),
    },
    {
      platform: 'Reddit',
      url:      `https://www.reddit.com/user/${username}`,
      api:      `https://www.reddit.com/user/${username}/about.json`,
      apiKey:   'name',
      getExtra: (d) => ({
        displayName: d.subreddit?.title || null,
        bio:         d.subreddit?.public_description || null,
        followers:   d.subreddit?.subscribers ?? null,
        karma:       (d.link_karma ?? 0) + (d.comment_karma ?? 0),
      }),
    },
    {
      platform: 'Instagram',
      url:      `https://www.instagram.com/${username}/`,
      head:     true,
    },
    {
      platform: 'TikTok',
      url:      `https://www.tiktok.com/@${username}`,
      head:     true,
    },
    {
      platform: 'Twitter / X',
      url:      `https://twitter.com/${username}`,
      head:     true,
    },
    {
      platform: 'YouTube',
      url:      `https://www.youtube.com/@${username}`,
      head:     true,
    },
    {
      platform: 'Twitch',
      url:      `https://www.twitch.tv/${username}`,
      head:     true,
    },
    {
      platform: 'LinkedIn',
      url:      `https://www.linkedin.com/in/${username}`,
      head:     true,
    },
    {
      platform: 'Pinterest',
      url:      `https://www.pinterest.com/${username}/`,
      head:     true,
    },
    {
      platform: 'Steam',
      url:      `https://steamcommunity.com/id/${username}`,
      head:     true,
    },
  ];

  // Verifica todas as plataformas em paralelo
  const checks = await Promise.allSettled(
    PLATFORMS.map(async (p) => {
      let found = false;
      let extra = { displayName: null, bio: null, followers: null };

      try {
        if (p.api) {
          // Plataformas com API pública JSON (GitHub, Reddit)
          const r = await fetch(p.api, {
            headers: { 'User-Agent': UA, Accept: 'application/json' },
            signal: AbortSignal.timeout(6000),
          });
          if (r.ok) {
            const data = await r.json();
            // Reddit aninha os dados em data.data
            const d = data.data || data;
            found = !!(d[p.apiKey]);
            if (found && p.getExtra) extra = p.getExtra(d);
          } else if (r.status === 404) {
            found = false;
          }
        } else if (p.head) {
          // Demais plataformas: HEAD request simples
          const r = await fetch(p.url, {
            method: 'HEAD',
            headers: { 'User-Agent': UA },
            redirect: 'follow',
            signal: AbortSignal.timeout(6000),
          });
          // 404 = não existe | qualquer outro 2xx/3xx = existe
          found = r.status !== 404 && r.status < 500;
        }
      } catch {
        // Timeout ou erro de rede — não confirma existência
        found = false;
      }

      return {
        platform:    p.platform,
        found,
        username:    found ? username : null,
        url:         found ? p.url : null,
        displayName: extra.displayName,
        bio:         extra.bio,
        followers:   extra.followers,
        ...(extra.repos  !== undefined ? { repos: extra.repos }  : {}),
        ...(extra.karma  !== undefined ? { karma: extra.karma }  : {}),
      };
    })
  );

  // Separa resultados bem-sucedidos dos que falharam
  const results = checks.map((c) =>
    c.status === 'fulfilled'
      ? c.value
      : { platform: '—', found: false, username: null, url: null }
  );

  const encontrados = results.filter(r => r.found).length;

  await incDailyCount(payload.username);
  await addLog(payload.username, 'Username', username);

  return res.json({ username, encontrados, results });
}

// =============================================================================
// ROTEADOR PRINCIPAL
// Valida JWT → verifica plano → verifica limite diário → chama o handler certo
// =============================================================================

const HANDLERS = {
  cep:      handleCEP,
  cnpj:     handleCNPJ,
  ip:       handleIP,
  dominio:  handleDominio,
  site:     handleSite,
  termo:    handleTermo,
  username: handleUsername,
};

export default async function handler(req, res) {
  secureHeaders(res);

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método não permitido. Use POST.' });
  }

  // 1. Autentica via JWT no header Authorization: Bearer <token>
  let payload;
  try {
    payload = verifyJWT(req);
  } catch {
    return res.status(401).json({ error: 'Não autenticado. Faça login novamente.' });
  }

  // 2. Valida o campo "tipo" do body
  const tipo = (req.body?.tipo || '').toLowerCase().trim();
  const fn = HANDLERS[tipo];
  if (!fn) {
    return res.status(400).json({
      error: `Módulo inválido. Opções: ${Object.keys(HANDLERS).join(', ')}.`,
    });
  }

  // 3. Verifica se o plano do usuário inclui este módulo
  const { data: user, error: userError } = await supabase
    .from('usuarios')
    .select('plano')
    .eq('id', payload.sub)
    .single();

  if (userError || !user) {
    return res.status(403).json({ error: 'Usuário não encontrado.' });
  }

  const cfg = PLAN_CONFIG[user.plano] || PLAN_CONFIG.Bronze;

  if (!cfg.modules.includes(tipo)) {
    return res.status(403).json({
      error: `O módulo "${tipo}" não está disponível no plano ${user.plano}.`,
    });
  }

  // 4. Verifica limite diário de consultas
  const used = await getDailyCount(payload.username);
  if (used >= cfg.dailyLimit) {
    return res.status(429).json({
      error: `Limite diário atingido (${cfg.dailyLimit} consultas). Volte amanhã.`,
      limite: cfg.dailyLimit,
      usado:  used,
    });
  }

  // 5. Delega para o handler do módulo
  return fn(req, res, payload, cfg);
}

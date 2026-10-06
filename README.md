# Policlínica Dr. Luiz Mansur — Landing Page | Unidade Xaxim

> **Cuidado e Excelência para Toda a Família — há mais de 35 anos.**
> Landing page institucional estática, otimizada para SEO local, performance e conversão via WhatsApp.

**Produção:** https://policlinicadrluizmansur.com.br/ · **Preview:** `*.vercel.app`
**Unidade:** Rua Francisco Derosso, 820 — Xaxim, Curitiba/PR — CEP 81710-000
**Contato:** Tel (41) 2170-1060 · WhatsApp (41) 99943-0296 · Seg–Sex 08h às 19h

---

## 1. Visão geral da clínica

A **Policlínica Dr. Luiz Mansur** atua há **mais de 35 anos** em Curitiba, com atendimento multidisciplinar, humanizado e preços acessíveis.

**Unidade Xaxim — destaques:**
- 14 especialidades no mesmo local: Cardiologia, Dermatologia, Ortopedia, Pediatria, Geriatria, Neurologia, Neurocirurgia, Psiquiatria, Psicologia, Urologia, Reumatologia, Oftalmologia, Massoterapia e Terapias Integrativas
- **Cartão VIP** com até **50% de desconto** em consultas e serviços — ideal para quem não tem convênio
- Atendimento **particular + convênios** (Unimed, Amil, Cassi, Copel, Sanepar, Saúde Caixa, MedPrev e outros — ver `assets/`)
- Agendamento rápido por **WhatsApp** + botão flutuante + CTAs em todas as seções
- SEO local completo: Schema.org `MedicalClinic` + `FAQPage`, Open Graph, Twitter Card, canonical e sitemap-ready

**Direção Técnica:**
> Diretor Técnico: Dr. _________________ — **CRM-PR XXXXXX**
> *TODO: preencher nome + CRM antes do go-live. O CRM deve constar no rodapé do site por exigência do CFM.*

**Slogan:** Cuidado e Excelência para Toda a Família
**Tom de voz:** acolhedor, profissional, confiável

---

## 2. Stack

| Camada | Tecnologia |
|---|---|
| Markup | **HTML5 semântico** — `header`, `main`, `section`, `footer`, `nav`, landmarks ARIA |
| Estilo | **CSS moderno puro** (sem framework) — CSS Variables, Flexbox/Grid, `clamp()`, media queries 1024/768/480px |
| Ícones | **Lucide Icons** via CDN (`https://unpkg.com/lucide@latest`) + `lucide.createIcons()` |
| Fontes | Google Fonts: `Playfair Display` (títulos) + `Inter` (corpo), com `preconnect` |
| Mapas | Google Maps `iframe` com `loading="lazy"` |
| Hospedagem | **Vercel Edge Network** — estático, `cleanUrls`, cache imutável de assets |
| Banco (opcional) | **Neon PostgreSQL** (serverless Postgres) para leads/agendamentos via Serverless Functions |
| Analytics (roadmap) | Plausible / GA4 — carregar só após consentimento LGPD |

Sem build step. Sem npm. Um único `index.html` + `assets/` = deploy em segundos.

---

## 3. Arquitetura estática otimizada

```
Visitante → Vercel Edge (CDN global, TLS, gzip/brotli)
  → index.html (único documento, CSS/JS inline crítico)
  → assets/* (imagens otimizadas, logos convênios, cache 1 ano)
  → APIs externas: Google Fonts, Lucide CDN, WhatsApp wa.me, Google Maps
  → (roadmap) /api/lead → Vercel Serverless Function → Neon PostgreSQL
```

**Por que estático:**
- TTFB baixo no Edge, LCP < 2.5s em 4G
- Zero superfície de ataque backend (sem PHP/Node exposto)
- Custo ~zero no plano Hobby, escala automática em picos (campanhas)
- SEO-first: HTML renderizado no primeiro byte, Schema.org legível por crawlers sem JS

**Otimizações aplicadas:**
- `foto-xaxim-opt.jpg` otimizada para OG/hero (manter original `foto-xaxim.jpg` fora do crítico)
- `preconnect` fonts + `display=swap` (evita FOIT)
- Lucide via CDN com fallback: se offline, textos/emoji mantêm sentido
- `loading="lazy"` em imagens abaixo da dobra e no iframe do Maps
- Headers de segurança + cache em `vercel.json` (ver §7)
- Contadores animados com `IntersectionObserver` (sem jQuery)

---

## 4. Estrutura de diretórios

```
landing-page-policlinica/
├── index.html            # Página única (SEO, Schema.org, CSS/JS inline, todas as seções)
├── vercel.json           # Headers segurança, cache, cleanUrls
├── .gitignore            # ignora .vercel/ e .env*
├── .env.local            # SOMENTE LOCAL — nunca commitar (Vercel OIDC / DATABASE_URL)
├── frontend_review.md    # Auditoria frontend (nota 8.3/10) + backlog a11y/perf
├── assets/
│   ├── logo.png / logo-768.png / logo-white.png
│   ├── foto-xaxim-opt.jpg   # usada no hero + og:image (otimizada)
│   ├── foto-xaxim.jpg / foto-centro.jpg / foto-portao.jpg
│   ├── 2.copel_.png / 3.cassi_.png / 13.saudecaixa.png / 14.sanepar.png
│   ├── 17.unimed.png / 18.amil_.png / 23.medprev.png / 1.aspp_.png
└── README.md             # este arquivo
```

**Seções do `index.html` (na ordem):**
`head SEO` → `navbar` → `hero` → `stats (35+ anos / 14+ especialidades / 3 unidades)` → `sobre` → `especialidades (grid 14 cards)` → `cartão VIP` → `convênios` → `localização + mapa` → `CTA agendamento` → `footer` → `WhatsApp float` → `scripts`

---

## 5. Como rodar local

Pré-requisitos: qualquer navegador moderno. Opcional: VS Code + Live Server ou Python.

```powershell
# 1 — entrar na pasta
Set-Location -LiteralPath "C:\Users\Usuario\Documents\workspace Hermes\landing-page-policlinica"

# 2a — servir com Python (sem instalação extra)
python -m http.server 5500
# abrir http://localhost:5500/

# 2b — ou com Vercel CLI (reproduz headers/edge local)
npx vercel dev
```

Não há `npm install` nem build. Edite `index.html`, salve e recarregue.

---

## 6. Integração com Neon PostgreSQL

O site atual é **100% estático e não consulta banco no carregamento**. O Neon entra como camada opcional de **captura de leads / pré-agendamento**, sem quebrar a arquitetura estática.

**Caso de uso recomendado:**
formulário “Solicitar retorno” → `POST /api/lead` (Vercel Function) → tabela `leads` no Neon → equipe chama no WhatsApp.

### 6.1 Criar banco

1. Crie conta em https://neon.tech → New Project → região `us-east-1` + Postgres 16
2. Copie a **pooled connection string** (`...-pooler...neon.tech`)
3. No Vercel: Project → Settings → Environment Variables → adicione:

```
DATABASE_URL=postgresql://user:pass@ep-xxx-pooler.us-east-1.aws.neon.tech/db?sslmode=require
```

Local: crie `.env.local` (já ignorado pelo `.gitignore`):

```
DATABASE_URL=postgresql://user:pass@localhost/db?sslmode=require
```

### 6.2 Schema mínimo

```sql
create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  whatsapp text not null,
  especialidade text,
  mensagem text,
  origem text default 'landing-xaxim',
  created_at timestamptz default now()
);
create index idx_leads_created on leads(created_at desc);
```

### 6.3 Exemplo de Function (`/api/lead.js` — criar quando precisar)

```js
import { neon } from '@neondatabase/serverless';
export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  const { nome, whatsapp, especialidade, mensagem } = req.body || {};
  if (!nome || !whatsapp) return res.status(400).json({ error: 'nome e whatsapp obrigatórios' });
  const sql = neon(process.env.DATABASE_URL);
  await sql`insert into leads (nome, whatsapp, especialidade, mensagem)
            values (${nome}, ${whatsapp}, ${especialidade || null}, ${mensagem || null})`;
  return res.status(201).json({ ok: true });
}
```

> Sem a variável `DATABASE_URL` o site continua funcionando normalmente — o formulário deve fazer fallback para `wa.me/5541999430296?text=...`.

**Boas práticas:** use pooled connection, nunca exponha `DATABASE_URL` no frontend, valide LGPD (checkbox de consentimento) antes de gravar.

---

## 7. Deploy na Vercel + `vercel.json`

`vercel.json` atual (na pasta do projeto):

```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" }
      ]
    }
  ]
}
```

Recomendação de produção (cache agressivo de assets):

```json
{
  "cleanUrls": true,
  "headers": [
    { "source": "/(.*)", "headers": [
      { "key": "X-Content-Type-Options", "value": "nosniff" },
      { "key": "X-Frame-Options", "value": "SAMEORIGIN" },
      { "key": "Referrer-Policy", "value": "origin-when-cross-origin" }
    ]},
    { "source": "/assets/(.*)", "headers": [
      { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
    ]}
  ]
}
```

**Deploy:**

```powershell
# preview
npx vercel
# produção
npx vercel --prod
# ou via Git: push → Preview automático; merge em main → Production
```

Domínio: Vercel → Settings → Domains → adicionar `policlinicadrluizmansur.com.br` + `www` (ajustar `canonical` e `og:url` no `<head>` após apontar DNS).

---

## 8. Branches e workflow

| Branch | Ambiente | Regra |
|---|---|---|
| `main` | **Production** (domínio oficial) | só via PR aprovado; tag `v1.x` a cada entrega |
| `staging` / `develop` | Preview estável para validação da clínica | merge de features aqui primeiro |
| `feat/*`, `fix/*`, `content/*` | Preview por commit (URL única por PR) | ex: `feat/cartao-vip`, `fix/contraste-hero`, `content/convenios` |

```powershell
git checkout -b feat/nova-secao
git add index.html assets/
git commit -m "feat: adiciona seção X"
git push -u origin feat/nova-secao
# abrir PR → feat/* → staging → main
```

Nunca commite `.env.local` ou `.vercel/`. Antes de merge em `main`: Lighthouse ≥90 (Performance/A11y), teste 375/768/1024px, validação Schema.org (Rich Results Test) e conferência de telefone/WhatsApp/endereço.

---

## 9. SEO, acessibilidade e performance

- **SEO:** title + description únicos, `canonical`, OG/Twitter, `MedicalClinic` (endereço, geo, horário, especialidades) + `FAQPage` (rich snippets)
- **A11y backlog** (ver `frontend_review.md`): checar contraste hero/CTA (WebAIM), `aria-label` nos ícones Lucide, navegação por teclado, skip-link
- **Perf:** manter `index.html` < 120KB, imagens ≤200KB (`foto-xaxim-opt.jpg`), adiar JS não-crítico, `font-display: swap`

---

## 10. Manutenção e roadmap

- [ ] Preencher **Diretor Técnico + CRM-PR** no rodapé
- [ ] Confirmar lista final de convênios (trocar placeholders em `assets/`)
- [ ] Mover JS inline para `script.js` + CSS crítico inline
- [ ] Formulário de pré-agendamento → `/api/lead` → Neon ( §6 )
- [ ] Analytics com consentimento + `@media print`

**Suporte:** WhatsApp (41) 99943-0296 · Tel (41) 2170-1060 · Rua Francisco Derosso, 820 — Xaxim, Curitiba/PR

-- =====================================================================
-- Policlínica Dr. Luiz Mansur — schema inicial
-- Banco : Neon PostgreSQL (aws-sa-east-1)
--       endpoint ep-restless-hill-b6pzeuo3 / branch br-wandering-term-b6kbqvxg
--       database neondb
-- Arquivo: migrations/0001_init.sql
--
-- Aplicação:
--   psql "$DATABASE_URL_UNPOOLED" -f migrations/0001_init.sql
-- (usar a connection string *direta*, não a -pooler: migrations não
--  rodam dentro de PgBouncer em modo transação)
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. agendamentos — pedidos de consulta vindos do formulário da landing
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agendamentos (
    id                BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_paciente     TEXT         NOT NULL,
    telefone          TEXT         NOT NULL,
    email             TEXT,
    especialidade     TEXT         NOT NULL,
    unidade           TEXT         NOT NULL DEFAULT 'Xaxim',
    data_preferencial DATE,
    mensagem          TEXT,
    status            TEXT         NOT NULL DEFAULT 'novo',
    criado_em         TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT agendamentos_nome_paciente_check
        CHECK (length(trim(nome_paciente)) > 0),

    CONSTRAINT agendamentos_telefone_check
        CHECK (length(regexp_replace(telefone, '\D', '', 'g')) >= 8),

    CONSTRAINT agendamentos_email_check
        CHECK (email IS NULL OR email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),

    CONSTRAINT agendamentos_especialidade_check
        CHECK (length(trim(especialidade)) > 0),

    CONSTRAINT agendamentos_unidade_check
        CHECK (length(trim(unidade)) > 0),

    CONSTRAINT agendamentos_status_check
        CHECK (status IN ('novo', 'contatado', 'confirmado', 'cancelado', 'concluido'))
);

-- Fila de trabalho: pendentes primeiro, sempre do mais recente
CREATE INDEX IF NOT EXISTS idx_agendamentos_pendentes
    ON agendamentos (criado_em DESC)
    WHERE status IN ('novo', 'contatado');

-- Visões administrativas: filtro por status e por período
CREATE INDEX IF NOT EXISTS idx_agendamentos_status
    ON agendamentos (status, criado_em DESC);

CREATE INDEX IF NOT EXISTS idx_agendamentos_criado_em
    ON agendamentos (criado_em DESC);

CREATE INDEX IF NOT EXISTS idx_agendamentos_data_preferencial
    ON agendamentos (data_preferencial)
    WHERE data_preferencial IS NOT NULL;

-- Cruzamento agenda x especialidade x unidade
CREATE INDEX IF NOT EXISTS idx_agendamentos_unidade_especialidade
    ON agendamentos (unidade, especialidade);

-- Telefone sem máscara: busca/pareamento de duplicados e follow-up por WhatsApp
CREATE INDEX IF NOT EXISTS idx_agendamentos_telefone_norm
    ON agendamentos (regexp_replace(telefone, '\D', '', 'g'));

COMMENT ON TABLE  agendamentos IS 'Solicitações de agendamento recebidas pelo site da Policlínica Dr. Luiz Mansur';
COMMENT ON COLUMN agendamentos.nome_paciente IS 'Nome completo informado no formulário';
COMMENT ON COLUMN agendamentos.telefone IS 'Telefone/WhatsApp com máscara livre ((41) 99999-9999); a versão só com dígitos é regexp_replace(telefone, ''\D'', '''', ''g'')';
COMMENT ON COLUMN agendamentos.email IS 'E-mail do paciente (opcional)';
COMMENT ON COLUMN agendamentos.especialidade IS 'Especialidade desejada (Cardiologia, Ortopedia, Pediatria, ...)';
COMMENT ON COLUMN agendamentos.unidade IS 'Unidade da Policlínica (Xaxim, ...)';
COMMENT ON COLUMN agendamentos.data_preferencial IS 'Data preferencial para o atendimento (sem horário definido)';
COMMENT ON COLUMN agendamentos.mensagem IS 'Observações livres enviadas pelo paciente';
COMMENT ON COLUMN agendamentos.status IS 'novo | contatado | confirmado | cancelado | concluido';
COMMENT ON COLUMN agendamentos.criado_em IS 'Timestamp de criação (UTC, com fuso)';

-- ---------------------------------------------------------------------
-- 2. contatos — captação de leads / contatos gerais (não são consultas)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS contatos (
    id         BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome       TEXT        NOT NULL,
    telefone   TEXT        NOT NULL,
    canal      TEXT        NOT NULL DEFAULT 'telefone',
    criado_em  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT contatos_nome_check
        CHECK (length(trim(nome)) > 0),

    CONSTRAINT contatos_telefone_check
        CHECK (length(regexp_replace(telefone, '\D', '', 'g')) >= 8),

    CONSTRAINT contatos_canal_check
        CHECK (canal IN ('whatsapp', 'telefone', 'email', 'formulario', 'instagram', 'outro'))
);

CREATE INDEX IF NOT EXISTS idx_contatos_criado_em
    ON contatos (criado_em DESC);

CREATE INDEX IF NOT EXISTS idx_contatos_canal
    ON contatos (canal, criado_em DESC);

CREATE INDEX IF NOT EXISTS idx_contatos_telefone_norm
    ON contatos (regexp_replace(telefone, '\D', '', 'g'));

COMMENT ON TABLE  contatos IS 'Contatos e leads gerais da Policlínica (fora do fluxo de agendamento)';
COMMENT ON COLUMN contatos.nome IS 'Nome de quem entrou em contato';
COMMENT ON COLUMN contatos.telefone IS 'Telefone/WhatsApp com máscara livre';
COMMENT ON COLUMN contatos.canal IS 'whatsapp | telefone | email | formulario | instagram | outro';
COMMENT ON COLUMN contatos.criado_em IS 'Timestamp de criação (UTC, com fuso)';

COMMIT;

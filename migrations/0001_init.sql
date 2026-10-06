-- =====================================================================
-- Policlínica Dr. Luiz Mansur — schema inicial
-- Arquivo : migrations/0001_init.sql
-- Alvo    : Neon PostgreSQL (aws-sa-east-1)
--           endpoint ep-restless-hill-b6pzeuo3
--           branch  br-wandering-term-b6kbqvxg / database neondb
--
-- Script idempotente, executado em uma única transação:
--   * banco novo  -> cria as duas tabelas no formato definitivo
--   * banco já populado com o formato legado -> alinha tipos, defaults,
--     NOT NULL, CHECKs e converte id serial -> bigint identity,
--     preservando e normalizando os dados existentes
--
-- Aplicação na connection string DIRETA (migrations não rodam dentro do
-- PgBouncer em modo transação):
--   psql "$DATABASE_URL_UNPOOLED" -f migrations/0001_init.sql
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Criação das tabelas
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

CREATE TABLE IF NOT EXISTS contatos (
    id         BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome       TEXT        NOT NULL,
    telefone   TEXT        NOT NULL,
    canal      TEXT        NOT NULL DEFAULT 'whatsapp',
    criado_em  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT contatos_nome_check
        CHECK (length(trim(nome)) > 0),
    CONSTRAINT contatos_telefone_check
        CHECK (length(regexp_replace(telefone, '\D', '', 'g')) >= 8),
    CONSTRAINT contatos_canal_check
        CHECK (canal IN ('whatsapp', 'telefone', 'email', 'formulario', 'instagram', 'outro'))
);

-- ---------------------------------------------------------------------
-- 2. Normalização de dados legados (no-op em banco recém-criado)
--    Roda ANTES dos NOT NULL/CHECK para que a validação sempre passe.
-- ---------------------------------------------------------------------
UPDATE agendamentos SET criado_em  = now()       WHERE criado_em  IS NULL;
UPDATE agendamentos SET status     = 'novo'      WHERE status IS NULL OR btrim(status) = '' OR status = 'pendente';
UPDATE agendamentos SET unidade    = 'Xaxim'     WHERE unidade IS NULL OR btrim(unidade) = '';
UPDATE agendamentos SET email      = NULL        WHERE email IS NOT NULL AND email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$';

UPDATE contatos SET criado_em = now()       WHERE criado_em IS NULL;
UPDATE contatos SET canal     = 'whatsapp'  WHERE canal IS NULL OR btrim(canal) = '';

-- ---------------------------------------------------------------------
-- 3. Defaults e obrigatoriedade (idempotente)
-- ---------------------------------------------------------------------
ALTER TABLE agendamentos
    ALTER COLUMN unidade   SET DEFAULT 'Xaxim',
    ALTER COLUMN unidade   SET NOT NULL,
    ALTER COLUMN status    SET DEFAULT 'novo',
    ALTER COLUMN status    SET NOT NULL,
    ALTER COLUMN criado_em SET DEFAULT now(),
    ALTER COLUMN criado_em SET NOT NULL;

ALTER TABLE contatos
    ALTER COLUMN canal     SET DEFAULT 'whatsapp',
    ALTER COLUMN canal     SET NOT NULL,
    ALTER COLUMN criado_em SET DEFAULT now(),
    ALTER COLUMN criado_em SET NOT NULL;

-- ---------------------------------------------------------------------
-- 4. Alinhamento de tabelas no formato legado (guardado; no-op se o
--    banco já está no formato definitivo)
-- ---------------------------------------------------------------------
DO $$
DECLARE
    col     text;
    tbl     text;
    seq_old text;
    seq_id  text;
BEGIN
    -- 4.1 texto ilimitado (legado vinha como varchar(n))
    FOREACH col IN ARRAY ARRAY['nome_paciente','telefone','email','especialidade',
                               'unidade','mensagem','status'] LOOP
        IF EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public'
                      AND table_name   = 'agendamentos'
                      AND column_name  = col
                      AND data_type   <> 'text') THEN
            EXECUTE format('ALTER TABLE agendamentos ALTER COLUMN %I TYPE text USING %I::text', col, col);
        END IF;
    END LOOP;

    FOREACH col IN ARRAY ARRAY['nome','telefone','canal'] LOOP
        IF EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public'
                      AND table_name   = 'contatos'
                      AND column_name  = col
                      AND data_type   <> 'text') THEN
            EXECUTE format('ALTER TABLE contatos ALTER COLUMN %I TYPE text USING %I::text', col, col);
        END IF;
    END LOOP;

    -- 4.2 id serial -> bigint GENERATED ALWAYS AS IDENTITY
    --     A conversão cria uma NOVA sequência (a antiga fica órfã apontando
    --     para a coluna), então: captura a velha, converte, descarta a velha,
    --     renomeia a identity para o nome canônico e sincroniza com max(id).
    FOREACH tbl IN ARRAY ARRAY['agendamentos','contatos'] LOOP
        SELECT format('%I.%I', n.nspname, c.relname)
          INTO seq_old
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          JOIN pg_depend    d ON d.classid = 'pg_class'::regclass AND d.objid = c.oid
          JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
         WHERE c.relkind = 'S'
           AND d.deptype = 'a'
           AND d.refclassid = 'pg_class'::regclass
           AND d.refobjid   = to_regclass('public.' || tbl)
           AND a.attname    = 'id';

        IF EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public'
                      AND table_name   = tbl
                      AND column_name  = 'id'
                      AND is_identity  = 'NO') THEN
            EXECUTE format('ALTER TABLE %I
                              ALTER COLUMN id DROP DEFAULT,
                              ALTER COLUMN id TYPE bigint,
                              ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY', tbl);
        END IF;

        IF seq_old IS NOT NULL THEN
            -- a coluna já é identity (ou teve o default removido na conversão),
            -- logo nada mais referencia a sequência serial antiga
            EXECUTE format('DROP SEQUENCE IF EXISTS %s', seq_old);
        END IF;

        SELECT format('%I.%I', n.nspname, c.relname)
          INTO seq_id
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          JOIN pg_depend    d ON d.classid = 'pg_class'::regclass AND d.objid = c.oid
          JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
         WHERE c.relkind = 'S'
           AND d.deptype = 'i'
           AND d.refclassid = 'pg_class'::regclass
           AND d.refobjid   = to_regclass('public.' || tbl)
           AND a.attname    = 'id';

        IF seq_id IS NOT NULL THEN
            IF to_regclass('public.' || tbl || '_id_seq') IS NULL THEN
                EXECUTE format('ALTER SEQUENCE %s RENAME TO %I', seq_id, tbl || '_id_seq');
                seq_id := format('%I.%I', 'public', tbl || '_id_seq');
            END IF;

            -- vazia: próximo id = 1 (is_called = false)
            -- populada: próximo id = max(id) + 1 (is_called = true)
            EXECUTE format('SELECT setval(%L, COALESCE((SELECT max(id) FROM %I), 1),
                                          (SELECT count(*) > 0 FROM %I))',
                           seq_id, tbl, tbl);
        END IF;
    END LOOP;

    -- 4.3 CHECKs (adiciona apenas os que faltam)
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'agendamentos_nome_paciente_check') THEN
        EXECUTE format('ALTER TABLE agendamentos ADD CONSTRAINT agendamentos_nome_paciente_check
                        CHECK (length(trim(nome_paciente)) > 0)');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'agendamentos_telefone_check') THEN
        EXECUTE format('ALTER TABLE agendamentos ADD CONSTRAINT agendamentos_telefone_check
                        CHECK (length(regexp_replace(telefone, %L, %L, %L)) >= 8)', '\D', '', 'g');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'agendamentos_email_check') THEN
        EXECUTE format('ALTER TABLE agendamentos ADD CONSTRAINT agendamentos_email_check
                        CHECK (email IS NULL OR email ~* %L)', '^[^@\s]+@[^@\s]+\.[^@\s]+$');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'agendamentos_especialidade_check') THEN
        EXECUTE format('ALTER TABLE agendamentos ADD CONSTRAINT agendamentos_especialidade_check
                        CHECK (length(trim(especialidade)) > 0)');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'agendamentos_unidade_check') THEN
        EXECUTE format('ALTER TABLE agendamentos ADD CONSTRAINT agendamentos_unidade_check
                        CHECK (length(trim(unidade)) > 0)');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'agendamentos_status_check') THEN
        EXECUTE format('ALTER TABLE agendamentos ADD CONSTRAINT agendamentos_status_check
                        CHECK (status IN (%L, %L, %L, %L, %L))',
                       'novo', 'contatado', 'confirmado', 'cancelado', 'concluido');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'contatos_nome_check') THEN
        EXECUTE format('ALTER TABLE contatos ADD CONSTRAINT contatos_nome_check
                        CHECK (length(trim(nome)) > 0)');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'contatos_telefone_check') THEN
        EXECUTE format('ALTER TABLE contatos ADD CONSTRAINT contatos_telefone_check
                        CHECK (length(regexp_replace(telefone, %L, %L, %L)) >= 8)', '\D', '', 'g');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'contatos_canal_check') THEN
        EXECUTE format('ALTER TABLE contatos ADD CONSTRAINT contatos_canal_check
                        CHECK (canal IN (%L, %L, %L, %L, %L, %L))',
                       'whatsapp', 'telefone', 'email', 'formulario', 'instagram', 'outro');
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 5. Índices
-- ---------------------------------------------------------------------

-- Fila de trabalho: pendentes primeiro, do mais recente para o mais antigo
CREATE INDEX IF NOT EXISTS idx_agendamentos_pendentes
    ON agendamentos (criado_em DESC)
    WHERE status IN ('novo', 'contatado');

-- Painel administrativo: filtro por status e por período
CREATE INDEX IF NOT EXISTS idx_agendamentos_status
    ON agendamentos (status, criado_em DESC);

CREATE INDEX IF NOT EXISTS idx_agendamentos_criado_em
    ON agendamentos (criado_em DESC);

CREATE INDEX IF NOT EXISTS idx_agendamentos_data_preferencial
    ON agendamentos (data_preferencial)
    WHERE data_preferencial IS NOT NULL;

-- Agenda cruzando unidade x especialidade
CREATE INDEX IF NOT EXISTS idx_agendamentos_unidade_especialidade
    ON agendamentos (unidade, especialidade);

-- Telefone sem máscara: busca, dedupe e follow-up por WhatsApp
CREATE INDEX IF NOT EXISTS idx_agendamentos_telefone_norm
    ON agendamentos (regexp_replace(telefone, '\D', '', 'g'));

CREATE INDEX IF NOT EXISTS idx_contatos_criado_em
    ON contatos (criado_em DESC);

CREATE INDEX IF NOT EXISTS idx_contatos_canal
    ON contatos (canal, criado_em DESC);

CREATE INDEX IF NOT EXISTS idx_contatos_telefone_norm
    ON contatos (regexp_replace(telefone, '\D', '', 'g'));

-- ---------------------------------------------------------------------
-- 6. Comentários no dicionário
-- ---------------------------------------------------------------------
COMMENT ON TABLE  agendamentos IS 'Solicitações de agendamento recebidas pelo site da Policlínica Dr. Luiz Mansur';
COMMENT ON COLUMN agendamentos.nome_paciente     IS 'Nome completo informado no formulário';
COMMENT ON COLUMN agendamentos.telefone          IS 'Telefone/WhatsApp com máscara livre; a versão só com dígitos é regexp_replace(telefone, ''\D'', '''', ''g'')';
COMMENT ON COLUMN agendamentos.email             IS 'E-mail do paciente (opcional)';
COMMENT ON COLUMN agendamentos.especialidade     IS 'Especialidade desejada (Cardiologia, Ortopedia, Pediatria, ...)';
COMMENT ON COLUMN agendamentos.unidade           IS 'Unidade da Policlínica (Xaxim, ...)';
COMMENT ON COLUMN agendamentos.data_preferencial IS 'Data preferencial para o atendimento, sem horário definido';
COMMENT ON COLUMN agendamentos.mensagem          IS 'Observações livres enviadas pelo paciente';
COMMENT ON COLUMN agendamentos.status            IS 'novo | contatado | confirmado | cancelado | concluido';
COMMENT ON COLUMN agendamentos.criado_em         IS 'Timestamp de criação (UTC com fuso)';

COMMENT ON TABLE  contatos IS 'Contatos e leads gerais da Policlínica, fora do fluxo de agendamento';
COMMENT ON COLUMN contatos.nome     IS 'Nome de quem entrou em contato';
COMMENT ON COLUMN contatos.telefone IS 'Telefone/WhatsApp com máscara livre';
COMMENT ON COLUMN contatos.canal    IS 'whatsapp | telefone | email | formulario | instagram | outro';
COMMENT ON COLUMN contatos.criado_em IS 'Timestamp de criação (UTC com fuso)';

COMMIT;

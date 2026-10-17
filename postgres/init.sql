-- Schemas propios de cada dueño de datos (EP2 VidalStore).
-- biblioteca (licencias) es dueño del esquema "licencias".
-- vidalstore-eventos es dueño del esquema "eventos".

CREATE SCHEMA IF NOT EXISTS licencias;
CREATE SCHEMA IF NOT EXISTS eventos;

-- El usuario de la aplicación ya es dueño de la base; se le otorgan los esquemas.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = current_user
  ) THEN
    RETURN;
  END IF;
END
$$;

GRANT ALL ON SCHEMA licencias TO CURRENT_USER;
GRANT ALL ON SCHEMA eventos TO CURRENT_USER;

-- Carga inicial de licencias para que la biblioteca y el panel tengan datos
-- con los que trabajar en la demostración.
CREATE TABLE IF NOT EXISTS licencias.licencias (
  id uuid PRIMARY KEY,
  juego_id text NOT NULL,
  usuario_sub text NOT NULL,
  estado text NOT NULL DEFAULT 'activa',
  adquirida_en timestamptz NOT NULL DEFAULT now(),
  revocada_en timestamptz,
  revocada_por text,
  CONSTRAINT licencias_estado_check CHECK (estado IN ('activa', 'revocada'))
);

CREATE TABLE IF NOT EXISTS eventos.eventos_auditoria (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  routing_key text NOT NULL,
  evento_id text NOT NULL UNIQUE,
  usuario_sub text,
  payload jsonb NOT NULL,
  emitido_en timestamptz NOT NULL,
  recibido_en timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS eventos.notificaciones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  para text NOT NULL,
  asunto text NOT NULL,
  estado text NOT NULL DEFAULT 'enviada',
  evento_id text,
  creada_en timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notificaciones_estado_check CHECK (estado IN ('enviada', 'fallida'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_notificaciones_aviso
  ON eventos.notificaciones (evento_id, asunto);

CREATE TABLE IF NOT EXISTS eventos.mensajes_muertos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cola_origen text NOT NULL,
  exchange_origen text,
  routing_key text,
  evento_id text,
  motivo text,
  intentos integer,
  payload text,
  recibido_en timestamptz NOT NULL DEFAULT now(),
  reprocesado_en timestamptz,
  reprocesado_por text
);

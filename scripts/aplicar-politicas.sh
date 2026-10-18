#!/usr/bin/env bash
#
# Aplica las políticas de retención y limpieza a las colas de mensajes muertos.
#
# Las colas de trabajo (avisos, auditoria, correos, reprocesos) declaran su
# política como argumentos de cola en el topologia.ts de vidalstore-eventos.
# Las DLQ la reciben aquí, como política del broker, porque una política se
# puede aplicar a una cola ya existente sin redeclararla (y la defensa arranca
# con `docker compose down`, sin -v: las colas persisten).
#
# Uso: ./scripts/aplicar-politicas.sh
#
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Techo alto (50000) y sin message-ttl: la evidencia de los errores se conserva.
MAX_LENGTH="${DLQ_MAX_LENGTH:-50000}"

# Patrón que cubre las cuatro DLQ (las tres del punto 4.1 más la del 4.9).
PATRON='^.*\.dlq$'
POLITICA="{\"max-length\":${MAX_LENGTH},\"overflow\":\"reject-publish\"}"

echo "==> Aplicando políticas de retención a las DLQ"

docker exec vidalstore-rabbit1 rabbitmqctl set_policy \
  "DLQ_RETENCION" "${PATRON}" "${POLITICA}" \
  --apply-to queues --priority 0

echo "==> Políticas aplicadas:"
docker exec vidalstore-rabbit1 rabbitmqctl list_policies

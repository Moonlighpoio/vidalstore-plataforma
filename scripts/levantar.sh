#!/usr/bin/env bash
#
# Levanta la plataforma VidalStore EP2.
#
# Uso:
#   ./scripts/levantar.sh              # solo infraestructura (RabbitMQ + Postgres)
#   ./scripts/levantar.sh --apps       # infraestructura + servicios Node en orden
#   ./scripts/levantar.sh --down       # detiene contenedores y servicios Node
#
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_PADRE="$(cd "${RAIZ}/.." && pwd)"
LOG_DIR="${RAIZ}/.logs"

# Orden de arranque de los servicios (primero los que no dependen de otros).
SERVICIOS=(
  "vidalstore-eventos"
  "vidalstore-biblioteca"
  "vidalstore-catalogo"
  "vidalstore-bff"
  "vidalstore-admin"
  "vidalstore-gateway"
  "vidalstore-frontend"
)

detener_apps() {
  if [ -d "${LOG_DIR}" ]; then
    for pidfile in "${LOG_DIR}"/*.pid; do
      [ -e "${pidfile}" ] || continue
      pid="$(cat "${pidfile}")"
      if kill -0 "${pid}" 2>/dev/null; then
        echo "Deteniendo proceso ${pid} ($(basename "${pidfile}" .pid))"
        kill "${pid}" 2>/dev/null || true
      fi
      rm -f "${pidfile}"
    done
  fi
}

if [ "${1:-}" = "--down" ]; then
  echo "Deteniendo servicios Node..."
  detener_apps
  echo "Deteniendo contenedores..."
  (cd "${RAIZ}" && docker compose down)
  exit 0
fi

cd "${RAIZ}"

if [ ! -f .env ]; then
  echo "No hay .env; copiando .env.example a .env (revisa los secretos)."
  cp .env.example .env
fi

echo "==> Levantando contenedores (Postgres + clúster RabbitMQ)"
docker compose up -d --wait

echo "==> Estado de los contenedores"
docker compose ps

echo "==> Estado del clúster"
docker exec vidalstore-rabbit1 rabbitmqctl cluster_status || true

echo "==> Aplicando políticas de retención a las colas"
"${RAIZ}/scripts/aplicar-politicas.sh" || true

if [ "${1:-}" != "--apps" ]; then
  echo
  echo "Infraestructura lista. La API de administración corre en http://localhost:15672"
  echo "Para levantar también los servicios Node: ./scripts/levantar.sh --apps"
  exit 0
fi

mkdir -p "${LOG_DIR}"

for servicio in "${SERVICIOS[@]}"; do
  repo="${REPO_PADRE}/${servicio}"
  if [ ! -d "${repo}" ]; then
    echo "Aviso: no existe ${repo}; se omite ${servicio}"
    continue
  fi

  echo "==> Preparando ${servicio}"
  (cd "${repo}" && [ -d node_modules ] || npm install)

  echo "    iniciando ${servicio} (log: .logs/${servicio}.log)"
  (cd "${repo}" && nohup npm run start:dev >"${LOG_DIR}/${servicio}.log" 2>&1 & echo $! >"${LOG_DIR}/${servicio}.pid")

  sleep 3
done

echo
echo "Servicios iniciados. Logs en ${LOG_DIR}"
echo "Panel de administración en http://localhost:3020/v1/admin/colas"

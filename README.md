# vidalstore-plataforma

Infraestructura y documentación del caso EP2 **VidalStore** (DSY1107). Reúne lo
que no es código de aplicación: la orquestación de contenedores, las políticas
del broker y la documentación de arquitectura.

## Repositorios

El mapa completo está en [`docs/repositorios.md`](docs/repositorios.md). En
resumen: cinco forks (`vidalstore-frontend`, `vidalstore-gateway`,
`vidalstore-bff`, `vidalstore-catalogo`, `vidalstore-biblioteca`) y tres
repositorios nuevos (`vidalstore-eventos`, `vidalstore-admin`,
`vidalstore-plataforma`).

## Arquitectura implementada

```
Angular 22 (4200) · guard de ruta + interceptor Amplify
        │  Authorization: Bearer <access_token>
        ▼
Gateway NestJS (8080) · AUTENTICA · 401
        ▼
BFF NestJS (3000) · AUTORIZA por grupo · 403 · reenvía Authorization · no publica
        ├───────────────────────────┐
        ▼                           ▼
Catálogo (3001) PRODUCTOR     Licencias (3002) PRODUCTOR
publica juego.publicado       publica compra.realizada y licencia.revocada
data/ con su seed             y escribe licencias en Postgres
        └──────────┬────────────────┘
                   ▼
   Clúster RabbitMQ 4.3 · rabbit1 5672 · rabbit2 5673
   vidalstore.eventos (topic) · vidalstore.comandos (direct) · vidalstore.dlx (direct)
   [ avisos ] [ auditoria ] [ correos ] [ reprocesos ]
   → [ avisos.dlq ] [ auditoria.dlq ] [ correos.dlq ] [ reprocesos.dlq ]
                   │  consume (noAck: false)      ▲ API HTTP del broker
                   ▼                              │
   vidalstore-eventos (3010) CONSUMIDOR     vidalstore-admin (3020) REST
   un consumidor por dominio + DLQ          RabbitAdminService
                   │  TypeORM
                   ▼
   PostgreSQL 18 (5432)
   licencias ······ de vidalstore-biblioteca
   eventos_auditoria · notificaciones · mensajes_muertos ······ de vidalstore-eventos
```

Cuatro capas (Angular, gateway, BFF, microservicios), dos nodos de broker, tres
exchanges, las colas del diagrama (más la de reproceso del punto 4.9) y Postgres
con sus dos dueños.

## Procedimiento único de levantamiento

Probado desde un clon limpio, en una carpeta nueva:

```bash
# 1. Clonar los repositorios declarados en docs/repositorios.md, uno al lado del otro.
# 2. Crear los .env a partir de los .env.example de cada repo y ajustar secretos.
# 3. Levantar la infraestructura (Postgres + clúster) y esperar a que esté sana.
cd vidalstore-plataforma
cp .env.example .env
docker compose up -d --wait
# 4. Las políticas de las seis colas las declara el consumidor en la topología;
#    no hay definiciones que importar. Al arrancar vidalstore-eventos se aplican.
# 5. Instalar dependencias y arrancar los dueños de cada esquema primero:
#      vidalstore-eventos    (esquema eventos)
#      vidalstore-biblioteca (esquema licencias)
# 6. Catálogo: sale del JSON versionado que dejó el seed en
#    vidalstore-catalogo/data/. No hay que volver a correr el seed salvo que se
#    quiera regenerar; el script queda en data/ para eso.
# 7. Arrancar el resto en orden:
#      vidalstore-catalogo, vidalstore-bff, vidalstore-admin,
#      vidalstore-gateway, vidalstore-frontend
```

Atajo: `./scripts/levantar.sh` levanta los contenedores; `./scripts/levantar.sh
--apps` además instala y arranca los servicios Node en el orden correcto
(logs en `.logs/`).

**Cómo se comprueba que quedó arriba:**

```bash
docker compose ps                       # los tres servicios "healthy"
docker exec vidalstore-rabbit1 rabbitmqctl cluster_status   # dos nodos en el clúster
curl -s localhost:3010/salud            # {"status":"ok",...}
curl -s localhost:3020/v1/admin/colas   # 401 sin token: la API está viva
```

## Variables de entorno

En `vidalstore-plataforma/.env`, a partir de `.env.example`:

| Variable                 | Valor de ejemplo              | Para qué                          |
| ------------------------ | ----------------------------- | --------------------------------- |
| `POSTGRES_USER`          | `vidalstore`                  | Usuario de Postgres               |
| `POSTGRES_PASSWORD`      | `cambia_esta_password`        | Contraseña de Postgres            |
| `POSTGRES_DB`            | `vidalstore`                  | Base de datos                     |
| `POSTGRES_PORT`          | `5432`                        | Puerto publicado                  |
| `RABBITMQ_DEFAULT_USER`  | `vidalstore`                  | Usuario del broker                |
| `RABBITMQ_DEFAULT_PASS`  | `cambia_esta_password`        | Contraseña del broker             |
| `RABBITMQ_DEFAULT_VHOST` | `/`                           | Vhost                             |
| `RABBITMQ_ERLANG_COOKIE` | `cambia_esta_cookie_compartida`| Cookie compartida por los nodos  |

Puertos: frontend 4200; gateway 8080; BFF 3000; catálogo 3001; licencias
(`vidalstore-biblioteca`) 3002; `vidalstore-eventos` 3010; `vidalstore-admin`
3020; Postgres 5432; `rabbit1` 5672 y 15672; `rabbit2` 5673 y 15673. Si algún
puerto está ocupado, está declarado aquí, en `docs/repositorios.md` y en el
`.env.example` de cada repo, además del `compose.yml`.

## Mensaje envenenado

Demuestra el recorrido completo (entra, falla, cae a la DLQ, queda en el log y
en la tabla):

```bash
cd ../vidalstore-eventos
npm run publicar-mensaje-malo
```

## Reproceso de un mensaje muerto (grupos de 3, punto 4.9)

Con el token de un administrador, se toma el `id` de la fila en
`eventos.mensajes_muertos` y se pide el reproceso indicando —si hace falta— el
payload corregido:

```bash
curl -X POST localhost:3020/v1/admin/dlq/<id>/reproceso \
  -H "Authorization: Bearer <access_token_admin>" \
  -H "Content-Type: application/json" \
  -d '{"payloadCorregido":{"licenciaId":"l-1","juegoId":"g-1","usuarioSub":"u-1","revocadaPor":"admin-1"}}'
```

`vidalstore-admin` publica `dlq.reprocesar` en `vidalstore.comandos`;
`vidalstore-eventos` republica el evento original en su exchange y routing key,
conservando el `x-evento-id`, y marca la fila como reprocesada. Esta vez el
evento llega a Postgres (auditoría) sin duplicar el aviso.

## Pruebas de la EP1 (siguen vigentes)

| Prueba                                            | Código |
| ------------------------------------------------- | ------ |
| Al gateway / microservicio sin token              | `401`  |
| Al BFF llamado por detrás sin token               | `401`  |
| Con token válido pero sin el grupo requerido      | `403`  |
| Con token válido y el grupo correcto              | `200`  |

## Documentación

- [`docs/repositorios.md`](docs/repositorios.md): mapa de repositorios.
- [`docs/topologia.md`](docs/topologia.md): exchanges, colas, bindings y routing keys.
- [`docs/modelo-de-datos.md`](docs/modelo-de-datos.md): modelo entidad-relación.
- [`docs/politicas.md`](docs/politicas.md): políticas de retención y su justificación.
- [`docs/metricas.md`](docs/metricas.md): métricas de la defensa.

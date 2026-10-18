# Políticas de retención y limpieza

Las políticas se declaran **en el repositorio** y no se configuran a mano en
la interfaz. Las colas de trabajo las declaran como argumentos de cola en el
`topologia.ts` de `vidalstore-eventos`; las DLQ las recibe como política del
broker, aplicada por `scripts/aplicar-politicas.sh` (que `levantar.sh` corre
después de `docker compose up -d --wait`). Una política se aplica a una cola ya
existente sin redeclararla, y la defensa arranca con `docker compose down`, sin
`-v`, así que las colas persisten.

## Colas de trabajo (`avisos`, `auditoria`, `correos`, `reprocesos`)

| Política        | Valor           | Justificación                                                       |
| --------------- | --------------- | ------------------------------------------------------------------- |
| `x-max-length`  | `10000`         | Techo de la cola: acota el uso de memoria y disco del broker        |
| `x-message-ttl` | `86400000` (1d) | Un aviso de hace días ya no sirve; se descarta solo                  |
| `x-overflow`    | `reject-publish`| Al llegar al techo se rechaza lo nuevo; el productor se entera       |

Con `overflow: reject-publish`, cuando la cola alcanza su techo el broker
rechaza la publicación y el productor con `confirm` se entera de que no entró.
Es distinto de `drop-head`, que descarta el mensaje más viejo en silencio: ahí
nadie sabe qué se perdió.

## Colas de mensajes muertos (`avisos.dlq`, `auditoria.dlq`, `correos.dlq`, `reprocesos.dlq`)

| Política        | Valor      | Justificación                                                        |
| --------------- | ---------- | -------------------------------------------------------------------- |
| `max-length`    | `50000`    | Techo alto que acota el crecimiento sin borrar evidencia             |
| `message-ttl`   | sin TTL    | Un mensaje muerto se conserva para poder reprocesarlo más tarde       |
| `overflow`      | `reject-publish` | Al llegar al techo se descarta lo nuevo: el mensaje más viejo —la evidencia que se quiere conservar— permanece |

La política se aplica con:

```bash
docker exec vidalstore-rabbit1 rabbitmqctl set_policy \
  DLQ_RETENCION '^.*\.dlq$' '{"max-length":50000,"overflow":"reject-publish"}' \
  --apply-to queues
```

El techo de una DLQ **no** es el de una cola de trabajo, y por eso el valor es
distinto (`50000` contra `10000`): una cola de trabajo retiene durante la
ventana en que un consumidor puede procesar; una DLQ retiene evidencia y crece
hasta que alguien la atiende. Un `message-ttl` sobre una DLQ borraría justo lo
que se quiere conservar, así que la DLQ es la única cola sin expiración. Si esa
política estuviera mal calibrada (un techo bajo o un `message-ttl`), se perdería
la evidencia de los errores: la fila que el consumidor de mensajes muertos pudo
guardar en `mensajes_muertos`, que es lo que permite reprocesar.

## Cómo se demuestra una política en vivo (defensa)

Sin tocar código, con el microservicio administrador (puerto 3020), como en L8:

```bash
# 1. Crear una cola de prueba con un techo bajo (argumentos validados por el DTO)
curl -X POST localhost:3020/v1/admin/colas \
  -H "Authorization: Bearer <token_admin>" -H "Content-Type: application/json" \
  -d '{"nombre":"prueba.politica","durable":true,"maxLength":5,"overflow":"reject-publish"}'
# 2. Publicar por sobre el techo y mostrar el rechazo de las publicaciones sobrantes.
# 3. Mostrar el comportamiento del overflow elegido y borrar la cola de prueba.
curl -X DELETE localhost:3020/v1/admin/colas/prueba.politica \
  -H "Authorization: Bearer <token_admin>"
```

## Otras decisiones

- `durable: true` en exchanges y colas; publicaciones con `persistent: true`.
- Mensajes con `content-type: application/json` y cabeceras `x-evento-id` y
  `x-emitido-en`.
- Reintento acotado dentro del consumidor para errores transitorios
  (`RABBITMQ_TRANSIENT_RETRIES` y `RABBITMQ_TRANSIENT_RETRY_MS`); agotado, el
  mensaje va a la DLQ.

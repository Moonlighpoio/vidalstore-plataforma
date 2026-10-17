# Políticas de retención y limpieza

Las políticas se declaran **en el repositorio**, como argumentos de cada cola en
el `topologia.ts` de `vidalstore-eventos`, y no se configuran a mano en la
interfaz. No hay `import_definitions` que correr: al arrancar el consumidor,
las colas se declaran con sus argumentos y el broker las aplica.

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
| `x-max-length`  | sin techo  | La evidencia de los errores no se descarta: es lo que Arturo pidió no perder |
| `x-message-ttl` | sin TTL    | Un mensaje muerto se conserva para poder reprocesarlo más tarde       |
| `x-overflow`    | no aplica  | Sin techo no hay desborde que decidir                                 |

El techo de una DLQ **no** es el de una cola de trabajo: una cola de trabajo
retiene durante la ventana en que un consumidor puede procesar; una DLQ retiene
evidencia y por eso crece hasta que alguien la atiende. Un `message-ttl` sobre
una DLQ borraría justo lo que se quiere conservar.

## Otras decisiones

- `durable: true` en exchanges y colas; publicaciones con `persistent: true`.
- Mensajes con `content-type: application/json` y cabeceras `x-evento-id` y
  `x-emitido-en`.
- Reintento acotado dentro del consumidor para errores transitorios
  (`RABBITMQ_TRANSIENT_RETRIES` y `RABBITMQ_TRANSIENT_RETRY_MS`); agotado, el
  mensaje va a la DLQ.

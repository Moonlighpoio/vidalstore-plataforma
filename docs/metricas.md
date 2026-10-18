# Métricas del clúster

Qué se mira en la Management UI (`http://localhost:15672` y `:15673`) o con
`docker exec vidalstore-rabbit1 rabbitmqctl list_queues name messages messages_ready messages_unacknowledged consumers`,
sobre el sistema en marcha con tráfico real de la demostración.

Comando base para todas las métricas de cola:

```bash
docker exec vidalstore-rabbit1 rabbitmqctl list_queues \
  name messages messages_ready messages_unacknowledged consumers
```

## 1. Colas activas

- **Qué significa**: cuántas colas están declaradas y con consumidor conectado.
- **Normal en este sistema**: 8 colas —`avisos`, `auditoria`, `correos`,
  `reprocesos` y sus cuatro `.dlq`—, es decir, las seis del punto 4.1 más las dos
  del punto 4.9.
- **Problema**: una cola de trabajo sin consumidor (columna `consumers` en 0)
  deja de drenar aunque haya `noAck: false`.
- **Qué se hace**: revisar `GET /salud` de `vidalstore-eventos` y su log; si el
  canal al broker se cayó, el consumidor se reconecta solo.

## 2. Mensajes `ready` (pendientes)

- **Qué significa**: mensajes en la cola que todavía no fueron entregados a un
  consumidor.
- **Normal**: 0 en reposo. Sube durante la ráfaga de la demostración y vuelve a
  0 en pocos segundos.
- **Problema**: una cola con **mil `ready` y cero consumidores** es una falla
  distinta de tener pocos consumidores lentos: nadie está consumiendo. Si hay
  consumidores pero `ready` no baja, el consumidor está lento o en bucle.
- **Qué se hace**: si `consumers = 0`, reiniciar `vidalstore-eventos`; si hay
  consumidor y sigue subiendo, revisar el `prefetch` y el tiempo del trabajo.

## 3. Mensajes `unacked`

- **Qué significa**: mensajes entregados a un consumidor que todavía no hizo
  `ack` (están en vuelo). Con `noAck: false` y `prefetch = 10`, cada consumidor
  puede tener hasta `prefetch` mensajes sin confirmar.
- **Normal**: menor o igual al `prefetch` configurado y baja rápido.
- **Problema**: `unacked` que **no baja** = un consumidor colgado (por ejemplo,
  Postgres no responde y el reintento escapa del `prefetch`). Un `unacked` alto
  y estable es una fuga, no carga.
- **Qué se hace**: revisar el log del consumidor; si es un fallo transitorio de
  Postgres, el reintento acotado lo resuelve y, agotado, el mensaje va a la DLQ.
  `prefetch(0)` sería sin límite y taparía esta señal; por eso se usa `10`.

## 4. Tasas de publicación y entrega

- **Qué significa**: `publish` (mensajes publicados por segundo en el exchange)
  y `deliver` (mensajes entregados a consumidores por segundo), en la pestaña
  *Message rates* del overview.
- **Normal**: `publish` y `deliver` se siguen de cerca; la diferencia se drena
  rápido.
- **Problema**: `publish` sostenido por encima de `deliver` hace crecer `ready`
  (el sistema se atrasa).
- **Qué se hace**: subir el número de consumidores o el `prefetch`, y confirmar
  que el cuello es Postgres y no el broker.

## 5. Consumidores por cola

- **Qué significa**: cuántos consumidores tiene cada cola (`consumers`).
- **Normal**: 1 en cada cola de trabajo y 4 en el consumidor de mensajes muertos
  (escucha las cuatro DLQ).
- **Problema**: `0` donde debería haber `1`.
- **Qué se hace**: reiniciar el consumidor y mirar `GET /salud`.

## 6. Mensajes acumulados en las DLQ

- **Qué significa**: mensajes muertos que nadie procesó, por cola `.dlq`.
- **Normal**: 0, salvo cuando se publica a propósito el mensaje envenenado.
- **Problema**: una DLQ que **solo sube** sin que nadie la mire significa que
  hay mensajes que no se pudieron procesar y que hay que reparar o reprocesar.
- **Qué se hace**: revisar la línea del consumidor de mensajes muertos
  (`colaOrigen`, `routingKey`, `motivo`, `intentos`), mirar la fila en
  `eventos.mensajes_muertos` y, si corresponde, reprocesarla por
  `POST /v1/admin/dlq/:id/reproceso` (punto 4.9).

## 7. Latencia extremo a extremo (compra → auditoría)

- **Qué significa**: `recibido_en − emitido_en` entre publicar `compra.realizada`
  y ver la fila en `eventos.eventos_auditoria`; el publicador adjunta
  `x-emitido-en` y el registro guarda `recibido_en`.
- **Normal**: p95 bajo 2 s con carga normal.
- **Problema**: latencia creciente es cola de trabajo acumulándose (ver punto 2).
- **Qué se hace**: comparar con `ready`/`unacked`; si `unacked` es alto, el
  problema está en el consumidor, no en el broker.

## 8. Idempotencia (auditoría y avisos)

- **Qué significa**: cuántos eventos duplicados se descartan.
- **Normal**: cero filas duplicadas. Se prueba publicando dos veces el mismo
  `x-evento-id`: la segunda inserción choca con `UNIQUE (evento_id)` (`23505`),
  el consumidor lo loguea y hace `ack` sin duplicar.
- **Problema**: filas repetidas en `eventos_auditoria` o avisos repetidos en
  `notificaciones`.
- **Qué se hace**: confirmar los índices únicos (punto 4.4); si el reproceso
  repite un aviso, revisar que el `x-evento-id` se preserve al republicar.

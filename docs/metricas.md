# Plan de métricas

Métricas para demostrar que el sistema se comporta bien bajo carga y que los
caminos de error funcionan de verdad.

## 1. Latencia extremo a extremo (compra -> auditoría)

- **Qué**: tiempo entre publicar `compra.realizada` y ver la fila en
  `eventos.eventos_auditoria`.
- **Cómo**: el publicador adjunta `x-emitido-en`; el registro guarda
  `recibido_en`. La diferencia `recibido_en - emitido_en` es la latencia.
- **Objetivo**: p95 menor a 2 s bajo carga normal.

## 2. Tasa de idempotencia

- **Qué**: cuántos eventos duplicados se descartan.
- **Cómo**: publicar el mismo `x-evento-id` dos veces y comprobar que solo hay
  una fila en `eventos_auditoria` (la segunda dispara `23505` y se registra en
  el log del consumidor).
- **Objetivo**: cero filas duplicadas.

## 3. Profundidad de colas y DLQ

- **Qué**: mensajes listos por cola y mensajes acumulados en las DLQ.
- **Cómo**: `GET /v1/admin/colas` y/o el panel en `http://localhost:15672`.
- **Objetivo**: las tres colas de trabajo vuelven a 0 tras la carga; las DLQ solo
  suben con mensajes realmente malos.

## 4. Efectividad del DLQ (mensaje envenenado)

- **Qué**: un mensaje mal formado no bloquea la cola y termina en su DLQ.
- **Cómo**: ejecutar `scripts/publicar-mensaje-malo.ts` de `vidalstore-eventos`,
  ver el aviso en el log y comprobar la fila en `eventos.mensajes_muertos`.
- **Objetivo**: la cola de trabajo sigue vaciándose; el mensaje malo queda en
  `avisos.dlq`.

## 5. Consumo continuo (sin pérdida de archivo)

- **Qué**: el consumidor sobrevive a la desconexión del broker.
- **Cómo**: reiniciar el contenedor de RabbitMQ mientras hay mensajes y
  verificar que `vidalstore-eventos` se reconecta (log de reintento) y procesa
  lo pendiente.
- **Objetivo**: cero mensajes perdidos.

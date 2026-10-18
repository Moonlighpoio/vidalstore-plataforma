# Topología de mensajería

Contraparte legible de los archivos `src/mensajeria/topologia.ts` de cada
proyecto. Los nombres de exchanges y routing keys son fijos (EP2 4.1); los de
colas y bindings los define el grupo.

## Exchanges

| Exchange             | Tipo   | Para qué                                   |
| -------------------- | ------ | ------------------------------------------ |
| `vidalstore.eventos` | topic  | Hechos que ya ocurrieron                   |
| `vidalstore.comandos`| direct | Órdenes a un destinatario concreto         |
| `vidalstore.dlx`     | direct | Lo que las colas rechazan                  |

## Routing keys

| Routing key        | Exchange             | Publica                  | Cuándo                         |
| ------------------ | -------------------- | ------------------------ | ------------------------------ |
| `compra.realizada` | `vidalstore.eventos` | vidalstore-biblioteca    | Tras crear la licencia         |
| `licencia.revocada`| `vidalstore.eventos` | vidalstore-biblioteca    | Tras revocar la licencia       |
| `juego.publicado`  | `vidalstore.eventos` | vidalstore-catalogo      | Al crear un juego              |
| `correo.enviar`    | `vidalstore.comandos`| vidalstore-eventos(avisos)| Al decidir avisar al jugador  |
| `dlq.reprocesar`   | `vidalstore.comandos`| vidalstore-admin         | Al reprocesar un mensaje muerto (4.9) |

## Colas y bindings

| Cola         | Exchange              | Binding                          | Caso de uso                          |
| ------------ | --------------------- | -------------------------------- | ------------------------------------ |
| `avisos`     | `vidalstore.eventos`  | `licencia.revocada`              | Avisar de la revocación              |
| `avisos`     | `vidalstore.eventos`  | `compra.realizada`               | Avisar de la compra                  |
| `auditoria`  | `vidalstore.eventos`  | `#`                              | Guardar todo hecho en la auditoría   |
| `correos`    | `vidalstore.comandos` | `correo.enviar`                  | Registrar el envío del correo        |
| `reprocesos` | `vidalstore.comandos` | `dlq.reprocesar`                 | Reprocesar un mensaje muerto (4.9)   |
| `avisos.dlq` | `vidalstore.dlx`      | `avisos`                         | Apartar avisos irrecuperables        |
| `auditoria.dlq`| `vidalstore.dlx`    | `auditoria`                      | Apartar auditorías irrecuperables    |
| `correos.dlq`| `vidalstore.dlx`      | `correos`                        | Apartar correos irrecuperables       |
| `reprocesos.dlq`| `vidalstore.dlx`   | `reprocesos`                     | Apartar reprocesos irrecuperables    |

Cada cola de trabajo se declara con `x-dead-letter-exchange: vidalstore.dlx` y
`x-dead-letter-routing-key: <nombre de la propia cola>`, que es exactamente el
binding con el que su DLQ está enlazada al `vidalstore.dlx`. Las DLQ se declaran
antes que las colas de trabajo.

La cola `reprocesos` y su DLQ son el aporte del punto 4.9 (grupos de 3): la
routing key `dlq.reprocesar` se agrega a las cuatro del punto 4.1.

## Consumidores

| Consumidor              | Proyecto           | Cola(s)                          |
| ----------------------- | ------------------ | -------------------------------- |
| `avisos`                | vidalstore-eventos | `avisos`                         |
| `auditoria`             | vidalstore-eventos | `auditoria`                      |
| `correos`               | vidalstore-eventos | `correos`                        |
| `reprocesos`            | vidalstore-eventos | `reprocesos`                     |
| `mensajes-muertos`      | vidalstore-eventos | las cuatro DLQ                   |

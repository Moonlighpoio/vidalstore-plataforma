# Repositorios de VidalStore

El sistema se reparte en ocho piezas. Cinco repositorios vienen de la EP1 y
tres son nuevos, creados para EP2. El mapa se escribió en la semana 8 y queda
fijo: la EP2, la EP3 y la EFT se corrigen contra este mapa.

## Piezas y repositorios

| Pieza        | Repositorio              | Enlace                                              | Puerto |
| ------------ | ------------------------ | --------------------------------------------------- | ------ |
| frontend     | `vidalstore-frontend`   | https://github.com/wsk4/vidalstore-frontend         | 4200   |
| gateway      | `vidalstore-gateway`    | https://github.com/wsk4/vidalstore-gateway          | 8080   |
| BFF          | `vidalstore-bff`        | https://github.com/wsk4/vidalstore-bff              | 3000   |
| catálogo     | `vidalstore-catalogo`   | https://github.com/wsk4/vidalstore-catalogo         | 3001   |
| licencias    | `vidalstore-biblioteca` | https://github.com/wsk4/vidalstore-biblioteca       | 3002   |
| eventos      | `vidalstore-eventos`    | https://github.com/wsk4/vidalstore-eventos          | 3010   |
| admin        | `vidalstore-admin`      | https://github.com/wsk4/vidalstore-admin            | 3020   |
| plataforma   | `vidalstore-plataforma` | https://github.com/wsk4/vidalstore-plataforma       | —      |

La pieza **licencias** vive en `vidalstore-biblioteca`: el microservicio que en
la EP1 se llamó «biblioteca» es el de licencias y no se renombra (punto 3.2).
Ese repositorio tiene varias piezas en `src/`: `library/` (GET /v1/biblioteca),
`licenses/` (crear/revocar licencias), `purchase/` (compras) y `audit/`
(auditoría del microservicio).

> Nota: existe además `vidalstore-licencias`, un repositorio con el mismo
> servicio de licencias. No es una pieza distinta del mapa; la pieza licencias
> es la que sirve `vidalstore-biblioteca`.

## Reglas de interacción

- Solo `vidalstore-biblioteca` y `vidalstore-catalogo` publican eventos.
- `vidalstore-bff` y `vidalstore-gateway` nunca publican en el broker.
- `vidalstore-eventos` solo consume; su único endpoint es `GET /salud`.
- `vidalstore-admin` no pasa por el gateway: valida el token él mismo y expone
  las rutas de administración del broker.
- El token viaja en `Authorization` y el `sub` sale siempre del token, nunca del
  cuerpo de la petición.

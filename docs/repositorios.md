# Repositorios de VidalStore

El sistema se reparte en ocho repositorios. Cinco son forks de la base original
y tres son nuevos, creados para EP2.

## Forks existentes

| Repositorio               | Rol                                                        | Puerto |
| ------------------------- | ---------------------------------------------------------- | ------ |
| `vidalstore-frontend`     | SPA Angular (catálogo, biblioteca, panel de administración) | 4200   |
| `vidalstore-gateway`      | Punto de entrada, valida token Cognito y enruta            | 8080   |
| `vidalstore-bff`          | Backend for frontend; agrega llamadas internas             | 3000   |
| `vidalstore-catalogo`     | CRUD de juegos; publica `juego.publicado`                  | 3001   |
| `vidalstore-biblioteca`   | Licencias del usuario; publica `compra.realizada` y `licencia.revocada` | 3002 |

## Repositorios nuevos de EP2

| Repositorio            | Rol                                                          | Puerto |
| ---------------------- | ------------------------------------------------------------ | ------ |
| `vidalstore-eventos`   | Consumidor de eventos: auditoría, avisos y correos; tres DLQ | 3010   |
| `vidalstore-admin`     | API de administración del broker (8 rutas REST)             | 3020   |
| `vidalstore-plataforma`| Infraestructura (compose) y documentación                   | —      |

## Reglas de interacción

- Solo `vidalstore-biblioteca` y `vidalstore-catalogo` publican eventos.
- `vidalstore-bff` y `vidalstore-gateway` nunca publican en el broker.
- `vidalstore-eventos` solo consume; su único endpoint es `GET /salud`.
- `vidalstore-admin` no pasa por el gateway: valida el token él mismo y expone
  las rutas de administración del broker.
- El token viaja en `Authorization` y el `sub` sale siempre del token, nunca del
  cuerpo de la petición.

# Chu Sniper Trailing

## Proposito

Chu Sniper Trailing es una herramienta de gestion de posiciones para
MetaTrader 5. Cada instancia administra solo el simbolo del grafico donde se
encuentra conectada. Para otro simbolo, usa otra instancia de forma
intencional. No es un generador de senales y no inventa entradas ni reglas de
estrategia.

## Antes de comenzar

- Usa un solo gestor de posiciones principal por simbolo.
- Confirma las reglas del broker: distancia minima, freeze level, volumen y
  tipo de cuenta antes de operar con fondos reales.
- La herramienta adopta las posiciones abiertas del simbolo, incluso las
  manuales o creadas por otro EA. No conectes gestores que compitan sin
  verificar su interaccion.
- El producto requiere una licencia de suscripcion valida. No incluye prueba.

## Conexion y licencia

1. Abre el grafico del simbolo que quieres administrar.
2. Conecta `Chu_Sniper_Trailing`.
3. Introduce la licencia en `EA_License_Key`.
4. Espera el estado `ACTIVE`.
5. Configura el panel antes de abrir o adoptar una posicion.

El servicio de licencia verifica `chu_sniper_trailing` con el protocolo comun
del backend y mantiene el heartbeat. El backend entrega el magic number de
ejecucion. Los resultados diarios no forman parte de este producto.

## Controles del panel

- `SL / Trail (pts)`: distancia del stop inicial y una unidad de riesgo (`1R`).
- `Risk (%)`: asignacion independiente del balance para cada posicion origen.
- `TP Multiple (R)`: distancia del take-profit; `0` significa sin TP del broker.
- `Calculated Lot`: vista previa que respeta reglas del broker; se recalcula al
  enviar la orden.
- `Market SELL` y `Market BUY`: acciones de mercado luego de las validaciones.
- `Trailing ON/OFF`: permite avanzar la escalera; apagarlo no quita ni relaja
  un stop protector ya confirmado.

## Proteccion y trailing

En BUY, el stop inicial queda una `R` debajo de la entrada confirmada. En SELL,
queda una `R` encima. La escalera fija es:

- `1R -> break even`
- `2R -> +1R`
- `3R -> +2R`, y continua sin limite de niveles

Los stops solo avanzan hacia una mayor proteccion. La herramienta verifica la
posicion exacta antes de modificarla y respeta las restricciones de distancia
del broker. Los fallos temporales pueden reintentarse de forma limitada; los
fallos de licencia, margen, permisos o riesgo quedan bloqueados.

## Uso seguro

La herramienta puede modificar posiciones del simbolo creadas fuera del EA.
No cierra todas las posiciones, no crea ordenes pendientes, no invierte
operaciones y no administra otro simbolo. Prueba primero en una cuenta demo
para confirmar distancias, volumen, ejecucion y proteccion del broker.

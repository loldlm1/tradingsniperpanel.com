# Producto - Base EA

## Producto
- Nombre: `Fibonacci EA - Base EA`
- Tipo: `Producto base`
- SKU: `base_ea`

## Descripcion
Base EA es el paquete principal de Fibonacci EA. Incluye el flujo completo del sistema: protecciones de cuenta, filtros de contexto de mercado y configuracion de tamano de posicion. Con esto, el usuario puede operar una version solida sin comprar addons desde el primer dia.

Para usuarios no traders: piensa en Base EA como la aplicacion principal, y los addons como funciones extra. La base ya maneja limites de seguridad y comportamiento estandar de estrategia.

## Inputs Explicados (Lenguaje Simple)
### Licencia y cuenta
- `EA_License_Key`: clave de activacion. Si es invalida o expirada, el EA no inicia.
- `Custom_Magic`: identificador unico para separar ordenes de este EA.
- `Max_Spread`: bloquea operaciones cuando el costo de ejecucion es alto.
- `Min_Range_Points`: movimiento minimo de mercado para permitir la logica.

### Proteccion de riesgo
- `Protection_Risk_Mode`: activa o desactiva la proteccion de cuenta.
- `Protection_Risk_Drawdown_Type`: define como medir la perdida maxima.
- `Protection_Risk_Drawdown_Value`: valor maximo permitido de drawdown.
- `Account_Size`: referencia de tamano de cuenta para calculos de respaldo.
- `Market_Close_Guard_Timeframe`: marco temporal para detectar cierre de mercado.

### Contexto de estrategia
- `Strategy_Timeframe`: velocidad de grafico usada en decisiones.
- `Stoch_Structure_Period_Type`: sensibilidad de deteccion de estructura.
- `Structure_Fibonacci_Levels`: niveles usados para planificar entradas.
- `Structure_Trigger_Entry`: entradas por nivel exacto o por zona.
- `Structure_Touch_Policy`: primer toque o re-test permitido.
- `Strategy_Direction_Mode`: permite compras, ventas o ambos.
- `Signal_Concurrency_Mode`: una senal activa o varias en paralelo.

### Ajustes de riesgo
- `Base_Strategy_Type`: modelo base de distancia (ATR, puntos o fibonacci).
- `Points_Range_Setup`: distancia fija en puntos cuando se usa modo de puntos.
- `Lot_Type`: metodo de tamano de lote.
- `Lot_Strategy_Size`: lote base o presupuesto de riesgo.
- `Lot_Multiplier`: factor de crecimiento entre niveles.
- `Signal_Lot_Strategy`: ajusta lote segun win/loss.
- `TP_Percent`: escala del objetivo de beneficio.
- `Daily_Signal_Limit`: maximo de senales por dia.
- `Daily_Signal_Limit_Mode`: forma de aplicar el limite diario.

## Configuracion Recomendada Inicial
- `Strategy_Direction_Mode = BOTH_DIRECTION`
- `Signal_Concurrency_Mode = SINGLE_RUNNING_SIGNAL`
- `Base_Strategy_Type = FIB_LEVEL_RANGE`
- `Points_Range_Setup = 100`
- `Lot_Type = GRID_LOT_SIZE`
- `Lot_Strategy_Size = 0.01`
- `TP_Percent = 100`

## Regla de Acceso
- No requiere addon para funciones base.
- Siempre requiere clave valida + expiracion futura.

## Si la Licencia Falla
- El EA hace hard-stop en `OnInit` y muestra mensaje en el grafico.

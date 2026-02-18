# Addon - Time Filter Session Manager

## Producto
- Nombre: `Time Filter Session Manager`
- Tipo: `Addon`
- SKU: `addon_session_time_filter`

## Descripcion
Este addon te da control de horario. Puedes definir en que sesiones el EA puede operar y cuando debe dejar de abrir posiciones. Es util para evitar horas de baja liquidez o ruido de mercado.

Para usuarios no traders: es como poner horario laboral al bot. Fuera de ese horario, puede pausar o cerrar posiciones segun el modo elegido.

## Inputs Explicados (Lenguaje Simple)
- `Session_Asia_Filter_Mode`: comportamiento en sesion Asia (`OFF`, `ALLOW_RUN`, `FORCE_CLOSE`).
- `Session_Asia_Filter_Time_Range`: horario Asia en formato `HH:MM-HH:MM`.
- `Session_London_Filter_Mode`: comportamiento en sesion Londres.
- `Session_London_Filter_Time_Range`: horario Londres.
- `Session_NewYork_Filter_Mode`: comportamiento en sesion Nueva York.
- `Session_NewYork_Filter_Time_Range`: horario Nueva York.

## Configuracion Recomendada Inicial
- `Session_Asia_Filter_Mode = SESSION_FILTER_OFF`
- `Session_London_Filter_Mode = SESSION_FILTER_ALLOW_RUN`
- `Session_London_Filter_Time_Range = 07:00-12:00`
- `Session_NewYork_Filter_Mode = SESSION_FILTER_ALLOW_RUN`
- `Session_NewYork_Filter_Time_Range = 12:00-20:00`

## Regla de Acceso
- Requiere entitlement si cualquier modo de sesion es distinto de `SESSION_FILTER_OFF`.

## Si Falta el Addon
- El EA bloquea el inicio y muestra el addon faltante en el grafico.

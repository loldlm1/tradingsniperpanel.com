# **Pandora Box: Guía de Instalación y Manual de Usuario**

## 1. Introducción
Bienvenido a la guía oficial de instalación y uso de **Pandora Box**, un EA (Expert Advisor) para MetaTrader 5 enfocado en ejecuciones por ruptura con control de riesgo y validación de licencia en línea.

---

## 2. Video de Instalación

Antes de continuar, recomendamos ver el siguiente video de instalación, que explica paso a paso cómo configurar **Pandora Box** en tu plataforma:

[[youtube:https://youtu.be/UtQj0znIjoY]]

---

## 3. Guía de Instalación

Sigue estos pasos detallados para instalar y configurar **Pandora Box** en MetaTrader 5:

### 1. **Descarga Pandora Box EA**
   - Descarga el archivo de **Pandora Box EA** desde el sitio oficial o la fuente proporcionada.

### 2. **Copia Pandora Box EA**
   - Una vez descargado, cópialo al portapapeles.

### 3. **Abre MetaTrader 5 (MT5)**
   - Abre tu plataforma **MetaTrader 5**.

### 4. **Abre la Carpeta de Datos**
   - Haz clic en "Archivo" en la barra superior de MetaTrader 5 y selecciona "Abrir carpeta de datos".

### 5. **Accede a MQL5**
   - En la ventana emergente, abre la carpeta **MQL5**.

### 6. **Accede a Experts**
   - Dentro de la carpeta **MQL5**, abre la carpeta **Experts**.

### 7. **Pega Pandora Box EA**
   - Pega el archivo de **Pandora Box EA** que copiaste previamente en esa carpeta.

### 8. **Cierra la Carpeta de Datos**
   - Cierra la ventana de la carpeta de datos.

### 9. **Actualiza Expert Advisors**
   - Regresa al Navegador de MetaTrader 5, haz clic derecho y selecciona "Actualizar" en la sección **Expert Advisors**.

### 10. **Habilita WebRequest para la Validación de Licencia en Línea**
   - En MT5, ve a **Herramientas -> Opciones -> Asesores Expertos**.
   - Habilita **Permitir WebRequest para la URL indicada**.
   - Agrega esta URL exacta a la lista permitida: `https://tradingsniperpanel.com`.

### 11. **Arrastra Pandora Box EA al Gráfico**
   - Busca **Pandora Box EA** en la lista de Expert Advisors y arrástralo al gráfico de tu preferencia.

### 12. **Ingresa la Licencia**
   - Se solicitará la clave de licencia. Pégala exactamente como fue proporcionada.

### 13. **Listo para Operar**
   - **Pandora Box** ya está instalado y listo para operar.

---

## 4. Guía de Usuario: Parámetros Configurables

**Pandora Box** utiliza entradas configurables para controlar la construcción del box, las rupturas, la gestión de riesgo y la ejecución.

### **Cómo Funciona Pandora Box**
- El EA construye un box diario de precio usando `Pandora_Box_Time_Range`.
- Después de cerrar la ventana, calcula precios de ruptura con `Pandora_Box_Offset_Points`.
- Si el precio rompe por arriba/abajo y todas las validaciones se cumplen (dirección, sesión, límites diarios, concurrencia), se abre una señal Pandora.
- La reentrada por cada lado se rearma solo cuando `close_1` vuelve dentro del box.
- `Pandora_Box_Max_Entries` controla el presupuesto de entradas abiertas (`0` significa ilimitado).
- Si el presupuesto se alcanza con operaciones aún abiertas, el estado muestra `PANDORA WAIT_CLOSE`; al cerrarse, pasa a `PANDORA DONE`.
- `Pandora_Box_Entry_Count_Mode` solo controla el contador analítico `counted`; no reemplaza el presupuesto de entradas abiertas.

---

### **Parámetros de Entrada**

| **Parámetro** | **Valor por Defecto** | **Descripción** | **Uso Recomendado** |
|---|---:|---|---|
| `Pandora_Box_Time_Range` | `"12:00-13:30"` | Ventana de construcción del box. Formato: `HH:MM-HH:MM`, inicio `<` fin, mismo día. | Usa ventanas líquidas (60-180 minutos). |
| `Pandora_Box_Stop_On_First_Win` | `true` | Finaliza Pandora por el día tras el primer cierre con beneficio. | Mantén `true` para un ritmo conservador. |
| `Pandora_Box_Direction_Mode` | `BOTH_DIRECTION` | Lado(s) permitidos de ruptura: ambos, solo alcista o solo bajista. | Restringe a un lado solo con sesgo direccional claro. |
| `Pandora_Box_Use_Session_Filter` | `true` | Aplica filtros horarios de sesión a intentos Pandora. | Mantén `true` cuando la política de sesión sea parte del riesgo. |
| `Pandora_Box_Enable_Visualization` | `true` | Dibuja líneas del box y rupturas en el gráfico. | Mantén activo durante configuración/ajuste. |
| `Pandora_Box_Set_Broker_SLTP` | `true` | Envía SL/TP al bróker en la ejecución; en `false`, el EA valida localmente. | Mantén `true` para protección del lado del bróker. |
| `Enable_Chart_Levels` | `true` | Habilita overlays/niveles de resumen en gráfico. | Mantén activo para monitoreo manual. |
| `Pandora_Risk_Trailing_Mode` | `PANDORA_RISK_TRAILING_OFF` | Comportamiento de trailing: `OFF` o `PANDORA_RISK_TRAILING_STEP_TP`. | Comienza con `OFF`; usa `STEP_TP` tras validar en tester. |
| `Pandora_Lot_Type` | `PANDORA_LOT_SIZE` | Modo de lote: fijo, basado en porcentaje o basado en moneda. | Usa lote fijo al inicio; los modos por presupuesto requieren calibración. |
| `Pandora_Lot_Strategy_Size` | `0.01` | Tamaño usado por el modo de lote seleccionado. | Empieza pequeño y aumenta gradualmente. |
| `Pandora_Box_Max_Range_Points` | `0.0` | Rango máximo permitido del box en puntos (`0` desactiva filtro). | Define un tope para saltar días con rango excesivo. |
| `Pandora_Points_Value_Mode` | `PANDORA_VALUE_MODE_POINTS` | Interpreta offset/SL/TP como puntos o `%` del rango del box. | Prefiere puntos primero; usa `%` para escalado adaptativo. |
| `Pandora_Box_Offset_Points` | `1.0` | Distancia buffer de ruptura desde el high/low del box. | Mantén valor distinto de cero para reducir rupturas falsas. |
| `Pandora_Points_SL` | `100.0` | Distancia de stop para entradas Pandora. | Debe ser `> 0`; ajusta por símbolo. |
| `Pandora_Points_TP` | `100.0` | Distancia de take profit para entradas Pandora. | Mantén positivo salvo que quieras salida solo por trailing. |
| `Pandora_Box_Entry_Count_Mode` | `COUNT_BOX_ENTRY_OFF` | Controla la analítica `counted`: todo (`SL/TP/BE`), `SL+BE` o `TP+BE`. | Usa `OFF` para diagnóstico completo. |
| `Pandora_Box_Max_Entries` | `2` | Presupuesto de entradas abiertas por día/ventana (`0` = ilimitado). | Mantén bajo (`1-2`) salvo que tus protecciones globales sean estrictas. |

---

## 5. Perfiles de Configuración Rápida

### **Perfil A: Intradía Conservador**
- `Pandora_Box_Time_Range = "08:00-09:30"`
- `Pandora_Box_Max_Range_Points = 180`
- `Pandora_Points_Value_Mode = PANDORA_VALUE_MODE_POINTS`
- `Pandora_Box_Offset_Points = 20`
- `Pandora_Points_SL = 120`
- `Pandora_Points_TP = 120`
- `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_OFF`
- `Pandora_Box_Stop_On_First_Win = true`
- `Pandora_Box_Entry_Count_Mode = COUNT_BOX_ENTRY_OFF`
- `Pandora_Box_Max_Entries = 2`
- `Pandora_Box_Direction_Mode = BOTH_DIRECTION`

### **Perfil B: Sesión con Sesgo de Tendencia**
- `Pandora_Box_Time_Range = "12:00-13:30"`
- `Pandora_Box_Max_Range_Points = 0`
- `Pandora_Points_Value_Mode = PANDORA_VALUE_MODE_BOX_PERCENT`
- `Pandora_Box_Offset_Points = 10` (10% del rango del box)
- `Pandora_Points_SL = 40` (40% del rango del box)
- `Pandora_Points_TP = 70` (70% del rango del box)
- `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_STEP_TP`
- `Pandora_Box_Stop_On_First_Win = false`
- `Pandora_Box_Entry_Count_Mode = COUNT_BOX_ENTRY_ON_SL`
- `Pandora_Box_Max_Entries = 2`
- `Pandora_Box_Direction_Mode = BULLISH_DIRECTION` (o `BEARISH_DIRECTION`)

---

## 6. Checklist de Validación Antes de Operar en Vivo
Antes de ejecutar **Pandora Box** en una cuenta real, verifica:

- El formato de horario es válido (`HH:MM-HH:MM`) y el inicio `<` fin.
- `Pandora_Points_SL > 0`.
- Si usas modo `%`, que offset/SL/TP sean porcentajes realistas para el símbolo.
- Que el modo de dirección coincida con tu sesgo de mercado.
- Que `Pandora_Box_Max_Entries` coincida con tu presupuesto de entradas abiertas.
- Que los filtros de sesión estén configurados si `Pandora_Box_Use_Session_Filter = true`.
- Que `Permitir WebRequest para la URL indicada` esté activo con `https://tradingsniperpanel.com`.
- Que el estado del gráfico no muestre `PANDORA INVALID WINDOW` ni `PANDORA INVALID BOX`.

---

## 7. Solución de Problemas de Licencia y WebRequest
Si WebRequest no está configurado, la validación de licencia en línea puede fallar y el EA puede retirarse después de los chequeos de inicialización/refresh.

### Síntomas comunes
- La validación de licencia falla inmediatamente al adjuntar el EA.
- El EA deja de ejecutarse y muestra error de conexión/validación de licencia en logs.

### Ruta de corrección (MT5)
1. Abre **Herramientas -> Opciones -> Asesores Expertos**.
2. Activa **Permitir WebRequest para la URL indicada**.
3. Agrega exactamente: `https://tradingsniperpanel.com`.
4. Vuelve a adjuntar el EA e ingresa de nuevo la clave de licencia.

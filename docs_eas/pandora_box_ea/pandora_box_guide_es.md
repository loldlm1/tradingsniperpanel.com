
# **Pandora Box: Guía de Instalación y Manual de Usuario**

## 1. Introducción
Bienvenido a la guía oficial de instalación y uso de **Pandora Box**, un EA (Asesor Experto) para MetaTrader 5 que le permitirá realizar operaciones basadas en el breakout de precios. A continuación, te proporcionamos todos los pasos para instalar el producto y configurarlo correctamente.

---

## 2. Video de Instalación y funcionamiento

Antes de proceder, te recomendamos ver el siguiente video de instalación donde se explica paso a paso cómo configurar **Pandora Box** en tu plataforma:

[[youtube:https://youtu.be/JoN3D3ydKZM?si=L0lKr7e72u05YmVu]]

---

## 3. Guía de Instalación

Sigue estos pasos detallados para instalar y configurar **Pandora Box** en tu MetaTrader 5:

### 1. **Descargar Pandora Box EA**
   - Descarga el archivo **Pandora Box EA** desde nuestro sitio web oficial o desde la fuente proporcionada.

### 2. **Copiar Pandora Box EA**
   - Una vez descargado el archivo, copíalo a tu portapapeles.

### 3. **Abrir MetaTrader 5 (MT5)**
   - Abre tu plataforma **MetaTrader 5**.

### 4. **Abrir Carpetas de Datos**
   - Haz clic en "Archivo" en la barra superior de MetaTrader 5 y selecciona "Abrir carpetas de datos".

### 5. **Acceder a MQL5**
   - En la ventana emergente, abre la carpeta **MQL5**.

### 6. **Acceder a Experts**
   - Dentro de la carpeta **MQL5**, abre la carpeta **Experts**.

### 7. **Pegar Pandora Box EA**
   - Pega el archivo **Pandora Box EA** que copiaste previamente en esta carpeta.

### 8. **Cerrar Carpetas de Datos**
   - Cierra la ventana de las carpetas de datos.

### 9. **Actualizar Asesores Expertos**
   - Regresa al navegador de MetaTrader 5, haz clic derecho y selecciona "Actualizar" en la sección **Asesores Expertos**.

### 10. **Arrastrar Pandora Box EA a la Gráfica**
   - Encuentra **Pandora Box EA** en la lista de Asesores Expertos y arrástralo a la gráfica de tu preferencia.

### 11. **Pegar Licencia**
   - Se te pedirá ingresar una licencia. Asegúrate de pegarla correctamente.

### 12. **Listo para Operar**
   - ¡Tu **Pandora Box** está instalado y listo para comenzar a operar!

---

## 4. Guía del Usuario: Parámetros Configurables

**Pandora Box** se basa en varias configuraciones de entrada para personalizar su comportamiento. Aquí te proporcionamos un desglose de cada parámetro y su función:

### **Cómo Funciona Pandora Box:**
El EA construye un "box" de precios diarios basado en un rango de tiempo especificado (por ejemplo, de 12:00 a 13:30). Una vez que el "box" se ha cerrado, se monitorean los breakout por encima o debajo del box. Si ocurre un breakout, se abre una cuadrícula en una sola dirección. La operación se detendrá una vez que se haya obtenido una ganancia.

---

### **Parámetros de Entrada:**

| **Parámetro** | **Valor Predeterminado** | **Descripción** | **Uso Recomendado** |
|---|---:|---|---|
| `Pandora_Box_Time_Range` | `"12:00-13:30"` | Ventana de construcción del box | Utiliza ventanas de mercado líquido. Mantén entre 60-180 minutos. |
| `Pandora_Box_Max_Range_Points` | `0.0` | Máximo rango permitido en puntos | Limita el rango de acuerdo con la volatilidad del símbolo. |
| `Pandora_Box_Offset_Points` | `50.0` | Buffer para el breakout | Mantén un valor mayor que 0 para evitar falsas rupturas. |
| `Pandora_Points_SL` | `100.0` | Distancia del stop en puntos | Asegúrate de ajustarlo según la volatilidad del símbolo. |
| `Pandora_Points_TP` | `100.0` | Distancia del take-profit en puntos | Usa valores positivos para control explícito del TP. |
| `Pandora_Box_Stop_On_First_Win` | `true` | Detiene la operación después de la primera ganancia | Mantén `true` para un ritmo conservador. |
| `Pandora_Box_Direction_Mode` | `BOTH_DIRECTION` | Dirección del breakout | Configura según tu sesgo (unidireccional o bidireccional). |
| `Pandora_Box_Stop_After_Sides` | `true` | Detiene después de consumir ambos lados | Mantén `true` a menos que quieras un comportamiento repetido. |
| `Pandora_Box_Use_Session_Filter` | `true` | Aplica un filtro de sesión para las operaciones | Mantén `true` si deseas controlar las operaciones por ventana de sesión. |
| `Pandora_Box_Enable_Visualization` | `true` | Habilita la visualización del box y líneas de breakout | Úsalo durante el ajuste o depuración. |
| `Pandora_Box_Set_Broker_SLTP` | `true` | Configura SL/TP directamente en el broker | Mantén `true` para protección del broker. |
| `Enable_Chart_Levels` | `true` | Habilita los niveles de gráficos para la visualización | Mantén habilitado para un monitoreo manual más sencillo. |

---

## 5. Perfiles Rápidos de Configuración

### **Perfil A: Conservador Intradía**
- `Pandora_Box_Time_Range = "08:00-09:30"`
- `Pandora_Box_Max_Range_Points = 180`
- `Pandora_Box_Offset_Points = 40`
- `Pandora_Points_SL = 120`
- `Pandora_Points_TP = 120`
- `Pandora_Box_Stop_On_First_Win = true`
- `Pandora_Box_Direction_Mode = BOTH_DIRECTION`

### **Perfil B: Sesión con Tendencia**
- `Pandora_Box_Time_Range = "12:00-13:30"`
- `Pandora_Box_Max_Range_Points = 0`
- `Pandora_Box_Offset_Points = 60`
- `Pandora_Points_SL = 140`
- `Pandora_Points_TP = 180`
- `Pandora_Box_Stop_On_First_Win = false`
- `Pandora_Box_Direction_Mode = BULLISH_DIRECTION` (o `BEARISH_DIRECTION`)

---

## 6. Checklist de Validación Antes de la Ejecución en Vivo
Antes de ejecutar **Pandora Box** en una cuenta real, asegúrate de verificar lo siguiente:

- El formato del rango de tiempo es válido (`HH:MM-HH:MM`).
- El parámetro `Pandora_Points_SL > 0`.
- Si se usa el filtro de rango máximo, asegúrate de que el valor sea adecuado para la volatilidad del símbolo.
- La dirección del breakout está alineada con tu sesgo.
- El filtro de sesión está configurado correctamente si `Pandora_Box_Use_Session_Filter = true`.
- Verifica el estado en el gráfico para asegurarte de que no haya errores de configuración.

---

## 7. Notas Finales
- La visualización de Pandora Box y colores/estilos actualmente son parámetros de nivel de código (no variables de entrada en MT5). Si se desea editarlos desde el panel de entrada, se debe actualizar el código.


# Sniper Advanced Panel: Guía de Instalación y Manual de Usuario

## Introducción
El **Sniper Advanced Panel** es una herramienta para MetaTrader 5 diseñada para gestionar y automatizar operaciones de manera eficiente. A continuación, se detallan los pasos de instalación, funciones del panel y atajos de teclado para facilitar su uso.

## 2. Video de instalacion
Para ver el video explicativo sobre la instalacion del **Sniper Advanced Panel**, haz clic en el siguiente enlace:

[[youtube:https://youtu.be/t51c0j84Xn8]]

## 1. Guía de Instalación
Sigue estos pasos detallados para instalar el **Sniper Advanced Panel** en tu plataforma MetaTrader 5 (MT5):

### 1. **Descargar el Sniper Panel**
   - Descarga el archivo **SniperAdvancedPanel.ex5** desde nuestro sitio web oficial o desde la fuente proporcionada.

### 2. **Copiar el archivo**
   - Copia el archivo **SniperAdvancedPanel.ex5** que descargaste.

### 3. **Abrir MetaTrader 5 (MT5)**
   - Abre tu plataforma MetaTrader 5 para comenzar la instalación.

### 4. **Ir a "Archivo" y seleccionar "Abrir carpetas de datos"**
   - Haz clic en "Archivo" en la parte superior de la ventana de MT5 y selecciona "Abrir carpetas de datos".

### 5. **Abrir la carpeta "MQL5"**
   - En la ventana que se abre, navega a la carpeta **MQL5**.

### 6. **Abrir la carpeta "Experts"**
   - Dentro de **MQL5**, abre la carpeta **Experts**.

### 7. **Pegar el archivo en la carpeta "Experts"**
   - Pega el archivo **SniperAdvancedPanel.ex5** en la carpeta **Experts**.

### 8. **Copiar los archivos adicionales**
   - Copia los archivos **Stochastic_Structure.ex5** y **BB_Percent_Standard.ex5**.

### 9. **Abrir la carpeta "Indicators"**
   - Regresa a la ventana de carpetas y abre la carpeta **Indicators**.

### 10. **Pegar los archivos en "Example"**
   - Dentro de **Indicators**, abre la carpeta **Example** y pega los archivos **Stochastic_Structure.ex5** y **BB_Percent_Standard.ex5**.

### 11. **Cerrar la carpeta de datos**
   - Cierra la ventana de carpetas de datos después de pegar los archivos.

### 12. **Actualizar Asesores Expertos**
   - En MetaTrader 5, haz clic derecho en el navegador de **Asesores Expertos** y selecciona "Actualizar".

### 13. **Habilita WebRequest para la Validación de Licencia en Línea**
   - En MT5, ve a **Herramientas -> Opciones -> Asesores Expertos**.
   - Habilita **Permitir WebRequest para la URL indicada**.
   - Agrega esta URL exacta a la lista permitida: `https://tradingsniperpanel.com`.

### 14. **Arrastrar el archivo a la gráfica**
   - Arrastra el archivo **SniperAdvancedPanel.ex5** desde la lista de **Asesores Expertos** a la gráfica de tu preferencia.

### 15. **Introducir la licencia**
   - Ingresa la **licencia** proporcionada para activar el panel.

### 16. **Listo para operar**
   - ¡Tu **Sniper Advanced Panel** está instalado y listo para usar!

## 2. Video del Funcionamiento
Para ver el video explicativo sobre cómo funciona el **Sniper Advanced Panel**, haz clic en el siguiente enlace:

[[youtube:https://youtu.be/Om0lARIewHE]]

## 3. Modo de Uso y Funciones del Panel
El **Sniper Advanced Panel** permite gestionar operaciones abiertas de forma efectiva, asegurando ganancias y controlando el riesgo. Las principales funcionalidades incluyen:

- **Cierre Parcial de Compra**: Cierra el % de una posición de compra.
- **Cierre Parcial de Venta** : Cierra el % de una posición de venta.

### Cierres Totales y de Emergencia
- **CC Total** (Cierre Total Compras): Cierra todas las posiciones largas.
- **CV Total** (Cierre Total Ventas): Cierra todas las posiciones cortas.

### Escalado de Entradas
Permite dividir entradas y gestionar la exposición de manera más flexible.

- **Dividir Escala**: Divide una entrada en varias fracciones.

### Automatización de Riesgo y Beneficios
El panel también permite automatizar la toma de ganancias en múltiples niveles y ajustar el riesgo:

- **TPx1 (Primario)**: Primer objetivo, generalmente el más conservador.
- **TPx2 (Secundario)**: Segundo nivel de toma de ganancias.

### Protección de Capital
- **Fijar BE Proteger**: Ajusta el Stop Loss al punto de entrada automáticamente para proteger las ganancias.

A continuación se muestra un cuadro comparativo de los atajos de teclado:

| **Atajo**                     | **Descripción**                                                               | **Acción**                                         |
|--------------------------------|-------------------------------------------------------------------------------|---------------------------------------------------|
| **⬆️ Flecha arriba**           | Realiza una compra.                                                           | Ejecuta una operación de compra.                  |
| **⬇️ Flecha abajo**            | Realiza una venta.                                                            | Ejecuta una operación de venta.                   |
| **F**                          | Cambia el tipo de orden (Normal → Limit → Stop).                               | Cambia el tipo de la orden activa.                |
| **O**                          | Muestra/oculta indicadores.                                                   | Activa o desactiva la visualización de los indicadores. |
| **U**                          | Cambia el tema de la interfaz.                                                | Cambia entre el tema claro y oscuro.              |
| **ESC**                        | Cancela una proyección.                                                       | Cancela la proyección activa en la gráfica.       |
| **E**                          | Cierra las posiciones de compra.                                              | Cierra todas las posiciones largas.               |
| **R**                          | Cierra las posiciones de venta.                                               | Cierra todas las posiciones cortas.               |
| **Barra espaciadora**          | Coloca break-even automáticamente.                                            | Coloca el Stop Loss en el precio de entrada para proteger la operación. |
| **Z o X**                      | Activa el Sniper Panel.                                                       | Muestra u oculta el panel de Sniper.              |


## 1. Guía de Instalación

**Video explicativo de la instalación**:  

[[youtube:https://youtu.be/usny5FfxSTc?si=Q6q0qNQlJAHngjxV]]

---

Sigue estos pasos para instalar el *Sniper Advanced Panel* en tu plataforma MetaTrader 5 (MT5):

- **Descargar el Sniper Panel**
- **Copiar el archivo** `SniperAdvancedPanel.ex5`.
- **Abrir MetaTrader 5 (MT5)**.
- **Ir a "Archivo"** y selecciona "Abrir carpetas de datos".
- **Abrir "MQL5"**.
- **Abrir "Experts"**.
- **Pegar `SniperAdvancedPanel.ex5`** dentro de la carpeta "Experts".
- **Copiar** los archivos `Stochastic_Structure.ex5` y `BB_Percent_Standard.ex5`.
- Regresa de la carpeta **"Experts"**.
- **Abrir "Indicators"**.
- **Abrir "Example"**.
- **Pegar** los archivos `Stochastic_Structure.ex5` y `BB_Percent_Standard.ex5` en "Indicators".
- Cierra la **carpeta de datos**.
- En el navegador de MT5, haz **clic derecho** y selecciona "Actualizar" en "Asesores Expertos".
- Haz lo mismo para **"Indicadores"**.
- **Arrastra el archivo `SniperAdvancedPanel.ex5`** a la gráfica.
- Introduce tu **licencia**.
- **Listo para operar**.

---

## 2. Modo de Uso: Funciones del Sniper Panel

**Video explicativo del funcionamiento del Sniper Panel**:  

[[youtube:https://youtu.be/Om0lARIewHE?si=DkQ0zKjl3yoSIuib]]

---

### Gestión y Securación de Posiciones  
Permite gestionar tus operaciones abiertas de forma efectiva, asegurando ganancias y controlando el riesgo.

- **Compra % Parcial** (C %): Cierra el % de una posición de compra.
- **Venta % Parcial** (V %): Cierra el % de una posición de venta.

### Cierres Totales y de Emergencia  
Útil para situaciones de cambio de mercado o emergencias.

- **CC Total** (Cierre Total Compras): Cierra todas las posiciones largas.
- **CV Total** (Cierre Total Ventas): Cierra todas las posiciones cortas.

### Escalado de Entradas  
Permite dividir entradas y gestionar la exposición de manera más flexible.

- **Dividir Escala**: Divide una entrada en varias fracciones.

---

## 3. Automatización de Riesgo y Beneficios

### Toma de Ganancias (Multi-Target)

Automatiza la toma de ganancias en múltiples niveles.

- **TPx1 (Primario)**: Primer objetivo, generalmente el más conservador.
- **TPx2 (Secundario)**: Segundo nivel de toma de ganancias.
- **TPx3 (Extendido)**: Captura movimientos extensos del mercado.

### Control Automático del Riesgo

El sistema ajusta el riesgo y el lotaje automáticamente.

- **Rej Base**: Establece el riesgo base por operación.
- **Rej x2 y Rej x3**: Duplica o triplica el riesgo respecto al base.

### Protección de Capital

- **Fijar BE Proteger**: Ajusta el Stop Loss al punto de entrada automáticamente para proteger las ganancias.

---

## 4. Atajos de Teclado Importantes

- **⬆️ Flecha arriba**: Realiza una compra.
- **⬇️ Flecha abajo**: Realiza una venta.
- **F**: Cambia el tipo de orden (Normal → Limit → Stop).
- **O**: Muestra/oculta indicadores.
- **U**: Cambia el tema de la interfaz.
- **ESC**: Cancela una proyección.
- **E**: Cierra las posiciones de compra.
- **R**: Cierra las posiciones de venta.
- **Barra espaciadora**: Coloca break-even automáticamente.
- **Z o X**: Activa el Sniper Panel.

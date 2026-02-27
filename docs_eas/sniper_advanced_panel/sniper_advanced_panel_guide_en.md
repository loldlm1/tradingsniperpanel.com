# Sniper Advanced Panel: Installation Guide and User Manual

## Introduction
The **Sniper Advanced Panel** is a MetaTrader 5 tool designed to manage and automate trade execution efficiently. This guide covers installation steps, panel functions, and keyboard shortcuts.

## 1. Installation Video
To watch the installation walkthrough for **Sniper Advanced Panel**, use the link below:

[[youtube:https://youtu.be/t51c0j84Xn8]]

## 2. Installation Guide
Follow these steps to install **Sniper Advanced Panel** in MetaTrader 5 (MT5):

### 1. Download the Sniper Panel
- Download **SniperAdvancedPanel.ex5** from our official source.

### 2. Copy the file
- Copy **SniperAdvancedPanel.ex5**.

### 3. Open MetaTrader 5 (MT5)
- Launch your MetaTrader 5 platform.

### 4. Open Data Folder
- In MT5, click `File` and select `Open Data Folder`.

### 5. Open `MQL5`
- In the folder window, open the **MQL5** directory.

### 6. Open `Experts`
- Inside **MQL5**, open the **Experts** folder.

### 7. Paste EA file in `Experts`
- Paste **SniperAdvancedPanel.ex5** into **Experts**.

### 8. Copy required indicator files
- Copy **Stochastic_Structure.ex5** and **BB_Percent_Standard.ex5**.

### 9. Open `Indicators`
- Go back and open the **Indicators** folder.

### 10. Open `Example` and paste indicators
- Inside **Indicators**, open **Example** and paste both indicator files.

### 11. Close Data Folder
- Close the folder window.

### 12. Refresh Expert Advisors
- In MT5, right-click inside the **Expert Advisors** navigator and choose `Refresh`.

### 13. **Enable WebRequest for Online License Validation**
   - In MT5, go to **Tools -> Options -> Expert Advisors**.
   - Enable **Allow WebRequest for listed URL**.
   - Add this exact URL to the allowed list: `https://tradingsniperpanel.com`.

### 14. Drag EA to chart
- Drag **SniperAdvancedPanel.ex5** from **Expert Advisors** onto your target chart.

### 15. Enter license
- Enter the provided **license key** to activate the panel.

### 16. Ready to trade
- The **Sniper Advanced Panel** is installed and ready.

## 3. Operation Video
To watch the panel operation walkthrough:

[[youtube:https://youtu.be/Om0lARIewHE]]

## 4. Usage Mode and Panel Functions
The **Sniper Advanced Panel** helps manage open positions while controlling risk.

- **Partial Close Buy**: Closes a percentage of a buy position.
- **Partial Close Sell**: Closes a percentage of a sell position.

### Full and Emergency Closures
- **CC Total** (Close Total Buys): Closes all long positions.
- **CV Total** (Close Total Sells): Closes all short positions.

### Entry Scaling
Split entries and manage exposure with more flexibility.

- **Split Scale**: Splits one entry into multiple fractions.

### Risk and Profit Automation
The panel supports multi-level take profits and risk controls.

- **TPx1 (Primary)**: First target, usually conservative.
- **TPx2 (Secondary)**: Second take-profit level.

### Capital Protection
- **Set BE Protect**: Moves stop loss to break-even to protect gains.

Keyboard shortcuts:

| Shortcut | Description | Action |
|---|---|---|
| Up Arrow | Executes a buy order. | Opens a buy position. |
| Down Arrow | Executes a sell order. | Opens a sell position. |
| F | Cycles order type (`Normal -> Limit -> Stop`). | Changes active order type. |
| O | Shows/hides indicators. | Toggles indicator visibility. |
| U | Changes panel theme. | Switches between light and dark themes. |
| ESC | Cancels projection. | Cancels the active chart projection. |
| E | Closes buy positions. | Closes all long positions. |
| R | Closes sell positions. | Closes all short positions. |
| Space | Sets break-even automatically. | Moves stop loss to entry price. |
| Z or X | Toggles Sniper Panel. | Shows or hides the panel. |

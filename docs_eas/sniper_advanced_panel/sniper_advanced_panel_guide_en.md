## 1. Installation Guide

**Installation walkthrough video**:

[[youtube:https://youtu.be/usny5FfxSTc?si=Q6q0qNQlJAHngjxV]]

---

Follow these steps to install *Sniper Advanced Panel* in MetaTrader 5 (MT5):

- Download the Sniper Panel bundle.
- Copy `SniperAdvancedPanel.ex5`.
- Open MetaTrader 5 (MT5).
- Go to **File** and select **Open Data Folder**.
- Open the **MQL5** folder.
- Open **Experts**.
- Paste `SniperAdvancedPanel.ex5` into **Experts**.
- Copy `Stochastic_Structure.ex5` and `BB_Percent_Standard.ex5`.
- Go back from **Experts**.
- Open **Indicators**.
- Open **Example**.
- Paste `Stochastic_Structure.ex5` and `BB_Percent_Standard.ex5` into **Indicators**.
- Close the data folder.
- In the MT5 navigator, right-click and select **Refresh** on **Expert Advisors**.
- Do the same for **Indicators**.
- Drag `SniperAdvancedPanel.ex5` onto a chart.
- Enter your license.
- Ready to trade.

---

## 2. How to Use: Sniper Panel Functions

**Sniper Panel usage walkthrough video**:

[[youtube:https://youtu.be/Om0lARIewHE?si=DkQ0zKjl3yoSIuib]]

---

### Position Management and Protection
Manage open positions effectively to secure gains and control risk.

- **Buy Partial % (C %)**: Close a percentage of a buy position.
- **Sell Partial % (V %)**: Close a percentage of a sell position.

### Full and Emergency Closes
Useful for rapid market changes or emergency exits.

- **CC Total (Close All Buys)**: Closes all long positions.
- **CV Total (Close All Sells)**: Closes all short positions.

### Entry Scaling
Split entries and manage exposure more flexibly.

- **Split Scale**: Divide one entry into multiple parts.

---

## 3. Risk and Profit Automation

### Multi-Target Take Profit

Automate take-profit execution across multiple levels.

- **TPx1 (Primary)**: First target, usually the most conservative.
- **TPx2 (Secondary)**: Second take-profit level.
- **TPx3 (Extended)**: Capture larger market moves.

### Automatic Risk Control

The system adjusts risk and lot size automatically.

- **Base Rej**: Sets base risk per trade.
- **Rej x2 and Rej x3**: Doubles or triples base risk.

### Capital Protection

- **Set BE Protect**: Moves Stop Loss to entry automatically to protect gains.

---

## 4. Important Keyboard Shortcuts

- **Arrow Up**: Place a buy order.
- **Arrow Down**: Place a sell order.
- **F**: Switch order type (Normal -> Limit -> Stop).
- **O**: Show/hide indicators.
- **U**: Toggle interface theme.
- **ESC**: Cancel a projection.
- **E**: Close buy positions.
- **R**: Close sell positions.
- **Spacebar**: Apply break-even automatically.
- **Z or X**: Activate the Sniper Panel.

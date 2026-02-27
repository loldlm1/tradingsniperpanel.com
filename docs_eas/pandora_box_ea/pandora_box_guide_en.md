# **Pandora Box: Installation Guide and User Manual**

## 1. Introduction
Welcome to the official installation and usage guide for **Pandora Box**, an EA (Expert Advisor) for MetaTrader 5 focused on breakout-based execution with controlled risk and licensing checks.

---

## 2. Installation Video

Before proceeding, we recommend watching the following installation video, which explains step-by-step how to set up **Pandora Box** on your platform:

[[youtube:https://youtu.be/UtQj0znIjoY]]

---

## 3. Installation Guide

Follow these detailed steps to install and configure **Pandora Box** in MetaTrader 5:

### 1. **Download Pandora Box EA**
   - Download the **Pandora Box EA** file from our official website or the provided source.

### 2. **Copy Pandora Box EA**
   - Once downloaded, copy the file to your clipboard.

### 3. **Open MetaTrader 5 (MT5)**
   - Open your **MetaTrader 5** platform.

### 4. **Open Data Folders**
   - Click on "File" in the top bar of MetaTrader 5 and select "Open Data Folder."

### 5. **Access MQL5**
   - In the pop-up window, open the **MQL5** folder.

### 6. **Access Experts**
   - Within the **MQL5** folder, open the **Experts** folder.

### 7. **Paste Pandora Box EA**
   - Paste the **Pandora Box EA** file that you previously copied into this folder.

### 8. **Close Data Folders**
   - Close the Data Folder window.

### 9. **Update Expert Advisors**
   - Go back to MetaTrader 5's Navigator, right-click, and select "Refresh" under the **Expert Advisors** section.

### 10. **Enable WebRequest for Online License Validation**
   - In MT5, go to **Tools -> Options -> Expert Advisors**.
   - Enable **Allow WebRequest for listed URL**.
   - Add this exact URL to the allowed list: `https://tradingsniperpanel.com`.

### 11. **Drag Pandora Box EA to the Chart**
   - Find **Pandora Box EA** in the list of Expert Advisors and drag it onto the preferred chart.

### 12. **Enter License**
   - You will be prompted to enter a license key. Paste it exactly as provided.

### 13. **Ready to Trade**
   - **Pandora Box** is installed and ready to start trading.

---

## 4. User Guide: Configurable Parameters

**Pandora Box** uses configurable inputs to control box construction, breakouts, risk behavior, and execution.

### **How Pandora Box Works**
- The EA builds a daily price box from `Pandora_Box_Time_Range`.
- After the window closes, it computes breakout prices using `Pandora_Box_Offset_Points`.
- If price breaks above/below and all guards pass (direction, session, daily limits, concurrency), a Pandora signal is opened.
- Re-entry on each side is re-armed only after `close_1` returns inside the box.
- `Pandora_Box_Max_Entries` controls the opened-entry budget (`0` means unlimited).
- If the budget is reached while trades remain open, status shows `PANDORA WAIT_CLOSE`; after closure, it transitions to `PANDORA DONE`.
- `Pandora_Box_Entry_Count_Mode` only controls the `counted` analytics counter; it does not replace the opened-entry budget.

---

### **Input Parameters**

| **Parameter** | **Default Value** | **Description** | **Recommended Usage** |
|---|---:|---|---|
| `Pandora_Box_Time_Range` | `"12:00-13:30"` | Box construction window. Format: `HH:MM-HH:MM`, start `<` end, same day. | Use liquid market windows (60-180 minutes). |
| `Pandora_Box_Stop_On_First_Win` | `true` | Ends Pandora for the day after first profitable closure. | Keep `true` for conservative pacing. |
| `Pandora_Box_Direction_Mode` | `BOTH_DIRECTION` | Allowed breakout side(s): both, bullish only, or bearish only. | Restrict to one side only with directional conviction. |
| `Pandora_Box_Use_Session_Filter` | `true` | Applies session-time filters to Pandora attempts. | Keep `true` when session policy is part of risk management. |
| `Pandora_Box_Enable_Visualization` | `true` | Draws Pandora box and breakout lines on chart. | Keep enabled during setup/tuning. |
| `Pandora_Box_Set_Broker_SLTP` | `true` | Sends SL/TP to broker at execution; when `false`, EA handles checks locally. | Keep `true` for broker-side risk protection. |
| `Enable_Chart_Levels` | `true` | Enables chart overlays/summary levels. | Keep enabled for manual monitoring. |
| `Pandora_Risk_Trailing_Mode` | `PANDORA_RISK_TRAILING_OFF` | Trailing behavior: `OFF` or `PANDORA_RISK_TRAILING_STEP_TP`. | Start with `OFF`; use `STEP_TP` after tester validation. |
| `Pandora_Lot_Type` | `PANDORA_LOT_SIZE` | Lot mode: fixed lot, percentage-based, or currency-based. | Use fixed lot initially; budget modes require calibration. |
| `Pandora_Lot_Strategy_Size` | `0.01` | Size input consumed by the selected lot mode. | Start small and increase gradually. |
| `Pandora_Box_Max_Range_Points` | `0.0` | Maximum allowed box range in points (`0` disables filter). | Set a cap to skip oversized days. |
| `Pandora_Points_Value_Mode` | `PANDORA_VALUE_MODE_POINTS` | Interprets offset/SL/TP as points or `%` of box range. | Prefer points first; use `%` for adaptive scaling. |
| `Pandora_Box_Offset_Points` | `1.0` | Breakout buffer distance from box high/low. | Keep non-zero to reduce false breaks. |
| `Pandora_Points_SL` | `100.0` | Stop distance for Pandora entries. | Must be `> 0`; tune by symbol. |
| `Pandora_Points_TP` | `100.0` | Take-profit distance for Pandora entries. | Keep positive unless trailing-only exit is intended. |
| `Pandora_Box_Entry_Count_Mode` | `COUNT_BOX_ENTRY_OFF` | Controls `counted` analytics: all (`SL/TP/BE`), `SL+BE`, or `TP+BE`. | Use `OFF` for full diagnostics. |
| `Pandora_Box_Max_Entries` | `2` | Opened-entry budget per day/window (`0` = unlimited). | Keep low (`1-2`) unless broader protections are strict. |

---

## 5. Quick Setup Profiles

### **Profile A: Conservative Intraday**
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

### **Profile B: Trend Session**
- `Pandora_Box_Time_Range = "12:00-13:30"`
- `Pandora_Box_Max_Range_Points = 0`
- `Pandora_Points_Value_Mode = PANDORA_VALUE_MODE_BOX_PERCENT`
- `Pandora_Box_Offset_Points = 10` (10% of box range)
- `Pandora_Points_SL = 40` (40% of box range)
- `Pandora_Points_TP = 70` (70% of box range)
- `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_STEP_TP`
- `Pandora_Box_Stop_On_First_Win = false`
- `Pandora_Box_Entry_Count_Mode = COUNT_BOX_ENTRY_ON_SL`
- `Pandora_Box_Max_Entries = 2`
- `Pandora_Box_Direction_Mode = BULLISH_DIRECTION` (or `BEARISH_DIRECTION`)

---

## 6. Validation Checklist Before Live Run
Before running **Pandora Box** on a live account, verify:

- The time range format is valid (`HH:MM-HH:MM`) and start `<` end.
- `Pandora_Points_SL > 0`.
- If using `%` mode, offset/SL/TP percentages are realistic for the symbol.
- Direction mode matches your market bias.
- `Pandora_Box_Max_Entries` matches intended opened-entry budget.
- Session filters are configured if `Pandora_Box_Use_Session_Filter = true`.
- `Allow WebRequest for listed URL` is enabled with `https://tradingsniperpanel.com`.
- Chart status does not show `PANDORA INVALID WINDOW` or `PANDORA INVALID BOX`.

---

## 7. License and WebRequest Troubleshooting
If WebRequest is not configured, online license verification can fail and the EA can remove itself after initialization/refresh checks.

### Common symptoms
- License validation fails immediately after attaching the EA.
- The EA stops running and logs a license connection/validation error.

### Fix path (MT5)
1. Open **Tools -> Options -> Expert Advisors**.
2. Enable **Allow WebRequest for listed URL**.
3. Add exactly: `https://tradingsniperpanel.com`.
4. Reattach the EA and enter the license key again.

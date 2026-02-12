
# **Pandora Box: Installation Guide and User Manual**

## 1. Introduction
Welcome to the official installation and usage guide for **Pandora Box**, an EA (Expert Advisor) for MetaTrader 5 that allows you to perform operations based on price breakouts. Below, we provide all the steps to install and set up the product correctly.

---

## 2. Installation Video

Before proceeding, we recommend watching the following installation video, which explains step-by-step how to set up **Pandora Box** on your platform:

[**Watch installation video**](https://youtu.be/JoN3D3ydKZM?si=L0lKr7e72u05YmVu)

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
   - Click on "File" in the top bar of MetaTrader 5 and select "Open Data Folders."

### 5. **Access MQL5**
   - In the pop-up window, open the **MQL5** folder.

### 6. **Access Experts**
   - Within the **MQL5** folder, open the **Experts** folder.

### 7. **Paste Pandora Box EA**
   - Paste the **Pandora Box EA** file that you previously copied into this folder.

### 8. **Close Data Folders**
   - Close the Data Folders window.

### 9. **Update Expert Advisors**
   - Go back to MetaTrader 5's navigator, right-click, and select "Update" under the **Expert Advisors** section.

### 10. **Drag Pandora Box EA to the Chart**
   - Find **Pandora Box EA** in the list of Expert Advisors and drag it onto the preferred chart.

### 11. **Enter License**
   - You will be prompted to enter a license. Make sure to paste it correctly.

### 12. **Ready to Trade**
   - **Pandora Box** is installed and ready to start trading!

---

## 4. User Guide: Configurable Parameters

**Pandora Box** relies on several input configurations to customize its behavior. Here is a breakdown of each parameter and its function:

### **How Pandora Box Works:**
The EA builds a daily price "box" based on a specified time range (e.g., from 12:00 to 13:30). Once the box is closed, it monitors breakouts above or below the box. If a breakout occurs, a grid is opened in a single direction. The operation will stop once a profit has been made.

---

### **Input Parameters:**

| **Parameter** | **Default Value** | **Description** | **Recommended Usage** |
|---|---:|---|---|
| `Pandora_Box_Time_Range` | `"12:00-13:30"` | Box construction window | Use liquid market windows. Keep between 60-180 minutes. |
| `Pandora_Box_Max_Range_Points` | `0.0` | Maximum allowed range in points | Limit the range according to symbol volatility. |
| `Pandora_Box_Offset_Points` | `50.0` | Breakout buffer | Keep non-zero to reduce false breakouts. |
| `Pandora_Points_SL` | `100.0` | Stop distance in points | Adjust according to symbol volatility. |
| `Pandora_Points_TP` | `100.0` | Take-profit distance in points | Use positive values for explicit TP control. |
| `Pandora_Box_Stop_On_First_Win` | `true` | Stops the operation after the first profitable side | Keep `true` for a conservative pace. |
| `Pandora_Box_Direction_Mode` | `BOTH_DIRECTION` | Breakout direction | Set according to your bias (unidirectional or bidirectional). |
| `Pandora_Box_Stop_After_Sides` | `true` | Stops after both sides are consumed | Keep `true` unless you want repeated behavior. |
| `Pandora_Box_Use_Session_Filter` | `true` | Applies session filter to operations | Keep `true` if you want to control operations by session window. |
| `Pandora_Box_Enable_Visualization` | `true` | Enables box and breakout line visualization | Use for tuning or debugging. |
| `Pandora_Box_Set_Broker_SLTP` | `true` | Sends SL/TP directly to broker | Keep `true` for broker-side protection. |
| `Enable_Chart_Levels` | `true` | Enables chart level overlays | Keep enabled for manual monitoring. |

---

## 5. Quick Setup Profiles

### **Profile A: Conservative Intraday**
- `Pandora_Box_Time_Range = "08:00-09:30"`
- `Pandora_Box_Max_Range_Points = 180`
- `Pandora_Box_Offset_Points = 40`
- `Pandora_Points_SL = 120`
- `Pandora_Points_TP = 120`
- `Pandora_Box_Stop_On_First_Win = true`
- `Pandora_Box_Direction_Mode = BOTH_DIRECTION`

### **Profile B: Trend Session**
- `Pandora_Box_Time_Range = "12:00-13:30"`
- `Pandora_Box_Max_Range_Points = 0`
- `Pandora_Box_Offset_Points = 60`
- `Pandora_Points_SL = 140`
- `Pandora_Points_TP = 180`
- `Pandora_Box_Stop_On_First_Win = false`
- `Pandora_Box_Direction_Mode = BULLISH_DIRECTION` (or `BEARISH_DIRECTION`)

---

## 6. Validation Checklist Before Live Run
Before running **Pandora Box** on a live account, make sure to check the following:

- The time range format is valid (`HH:MM-HH:MM`).
- The parameter `Pandora_Points_SL > 0`.
- If using max range filter, ensure the value fits symbol volatility.
- The breakout direction is aligned with your bias.
- The session filter is configured properly if `Pandora_Box_Use_Session_Filter = true`.
- Check the chart for any error messages.

---

## 7. Final Notes
- Pandora Box visualization and colors/styles are currently code-level parameters (not MT5 input fields). If you want them editable from the input panel, the code should be updated.

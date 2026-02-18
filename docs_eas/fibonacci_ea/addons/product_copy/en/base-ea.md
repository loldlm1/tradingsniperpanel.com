# Base EA

## Product
- Name: `Fibonacci EA - Base EA`
- Type: `Core product`
- SKU: `base_ea`

## Description
The Base EA is the foundation package for Fibonacci EA. It includes the complete core workflow: account-level protections, market context controls, and position sizing settings. This means users can run a solid version of the system without buying addons on day one.

For non-traders: think of the Base EA as the "main app" and addons as optional feature packs. The base version already manages safety limits and standard strategy behavior.

## Inputs Explained (Plain Language)
### License and account
- `EA_License_Key`: your activation key. If invalid or expired, the EA does not start.
- `Custom_Magic`: unique ID to separate this EA orders from others.
- `Max_Spread`: blocks trades when trading cost is too high.
- `Min_Range_Points`: minimum market movement required before trading logic can continue.

### Risk protection
- `Protection_Risk_Mode`: turns account protection logic on/off.
- `Protection_Risk_Drawdown_Type`: how loss limits are measured (percent or fixed money).
- `Protection_Risk_Drawdown_Value`: max allowed drawdown before protection acts.
- `Account_Size`: reference account size for risk math fallback.
- `Market_Close_Guard_Timeframe`: timeframe used to detect market-close conditions.

### Strategy context
- `Strategy_Timeframe`: chart speed used for decision logic.
- `Stoch_Structure_Period_Type`: sensitivity for structure detection.
- `Structure_Fibonacci_Levels`: retracement levels used by entry planning.
- `Structure_Trigger_Entry`: how entries are triggered (exact levels or zones).
- `Structure_Touch_Policy`: first touch only vs retest allowed.
- `Strategy_Direction_Mode`: allow buys, sells, or both.
- `Signal_Concurrency_Mode`: one active signal vs multiple in parallel.

### Risk management settings
- `Base_Strategy_Type`: base distance model (ATR, points, or fibonacci level range).
- `Points_Range_Setup`: fixed point distance used when points mode is selected.
- `Lot_Type`: lot sizing method.
- `Lot_Strategy_Size`: base lot size or risk budget (depends on lot mode).
- `Lot_Multiplier`: growth factor between levels for fixed lot mode.
- `Signal_Lot_Strategy`: adjusts lot behavior after win/loss outcomes.
- `TP_Percent`: target-profit scale.
- `Daily_Signal_Limit`: max signals per day.
- `Daily_Signal_Limit_Mode`: how the daily limit is enforced.

## Recommended Starter Setup
- `Strategy_Direction_Mode = BOTH_DIRECTION`
- `Signal_Concurrency_Mode = SINGLE_RUNNING_SIGNAL`
- `Base_Strategy_Type = FIB_LEVEL_RANGE`
- `Points_Range_Setup = 100`
- `Lot_Type = GRID_LOT_SIZE`
- `Lot_Strategy_Size = 0.01`
- `TP_Percent = 100`

## Access Rule
- No addon entitlement required for base features.
- Valid key + future expiry timestamp is always required.

## If License Validation Fails
- EA hard-stops on `OnInit` and shows a chart message.

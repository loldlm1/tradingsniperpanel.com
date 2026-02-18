# Addon - Grid Strategy Settings

## Product
- Name: `Grid Strategy Settings`
- Type: `Addon`
- SKU: `addon_grid_strategy_config`

## description
This addon unlocks the advanced grid configuration layer. It is designed for users who want to define how aggressively the EA adds levels and how far grid sequences can extend.

For non-traders: this addon controls how "deep" and "wide" the strategy can scale entries. More depth can improve flexibility but also increases exposure.

## Inputs Explained (Plain Language)
- `Grid_Exponential_Multiplier`: how quickly spacing grows between next grid levels.
- `Grid_Level_Position_Start`: the first level index used for execution logic.
- `Grid_Level_Stop_Limit`: maximum grid level depth allowed.

## Recommended Starter Setup
- `Grid_Exponential_Multiplier = 1.20`
- `Grid_Level_Position_Start = 0`
- `Grid_Level_Stop_Limit = 3`

## Access Rule
- Entitlement is required when any of these differ from defaults:
- `Grid_Exponential_Multiplier = 1.0`
- `Grid_Level_Position_Start = 0`
- `Grid_Level_Stop_Limit = 1`

## If Addon Is Missing
- Startup is blocked when advanced values are requested.
- Runtime lock forces `Grid_Level_Stop_Limit = 1` as safety fallback.

## Note
- `Base_Strategy_Type` and `Points_Range_Setup` remain base-allowed and do not need this addon.

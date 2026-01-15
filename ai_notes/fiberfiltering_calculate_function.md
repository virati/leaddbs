# Fiberfiltering Explorer - Calculate Button Function Call

## Summary

When the user clicks "Calculate" in the fiberfiltering explorer, it calls the **`calculate` method** of the `ea_disctract` class at **explorers/fiberfiltering_explorer/ea_disctract.m:235**.

## Calculate Method Flow

This method then branches to call one of three different calculation functions based on the connectivity type and calculation method:

1. **`calculate_on_pam`** (line 303) - for PAM (Pathway Activation Modeling) method
2. **`calculate_on_efield`** (line 309) - for E-field/Voxel based method
3. **`calculate_on_fibers`** (line 314+) - for Fiber based method

## Main Calculate Function Responsibilities

The main `calculate` function also:
- Checks if results were already calculated and prompts for confirmation to recalculate
- Handles multi-pathway connectome setup if enabled (assembles cfile from multiple pathway.dat files)
- Sets up adjacency matrices if needed (loads `_ADJ.mat` files)
- Validates that required stimulation volume files exist

## Code Location

File: `explorers/fiberfiltering_explorer/ea_disctract.m`
Line: 235

## Related Functions

- `calculate_on_pam` (line 399)
- `calculate_on_efield` (line 414)
- `calculate_on_fibers` (line 442)
- `calc_biophysical` (line 502)
- `calculate_cleartune` (line 573)

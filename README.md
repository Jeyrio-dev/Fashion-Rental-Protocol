# Fashion Rental Protocol

A decentralized protocol for renting fashion items with built-in escrow, damage assessment, and reputation systems.

## Features

- **Secure Rental Agreements**: Automated escrow system for rental transactions
- **Damage Assessment**: Built-in condition scoring and penalty calculations
- **Reputation System**: Track user reliability and rental history
- **Flexible Duration**: Support for various rental periods
- **Security Deposits**: Automated deposit handling with partial refunds

## Contract Functions

### Public Functions
- `list-rental-item`: List fashion items for rent with pricing
- `create-rental-agreement`: Start a rental with escrow deposit
- `return-item`: Complete rental with condition assessment
- `report-damage`: Report damage incidents for dispute resolution

### Read-Only Functions
- `get-rental-item`: View rental item details
- `get-rental-agreement`: Check rental agreement status
- `get-user-reputation`: View user's rental reputation
- `calculate-rental-cost`: Calculate total rental cost including deposits

## Usage

Fashion item owners can list their items for rent, while renters can securely rent items with automated escrow protection and damage assessment.

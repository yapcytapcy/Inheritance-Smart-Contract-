# 🏦 Inheritance Smart Contract

A trustless, automated inheritance system for STX assets built on Stacks blockchain.

## 🎯 Purpose

This smart contract solves the critical problem of digital asset inheritance by automatically transferring assets to designated heirs if the wallet owner becomes inactive for an extended period.

## ✨ Features

- 🔐 Designate up to 5 heirs with customizable inheritance shares
- ⏰ Configurable inactivity period (default: ~1 year in blocks)
- 🔄 Manual activity reset by owner
- 📊 Percentage-based inheritance distribution
- 👑 Transferable ownership

## 📝 Contract Functions

### Owner Functions

- `update-activity`: Reset the inactivity timer
- `set-inactivity-period`: Change the required inactive blocks
- `add-heir`: Add a new heir with their share percentage
- `remove-heir`: Remove an existing heir
- `update-heir-share`: Modify an heir's inheritance percentage
- `transfer-ownership`: Transfer contract ownership

### Heir Functions

- `claim-inheritance`: Claim inheritance share after inactivity period

### Read-Only Functions

- `get-owner`: Get current contract owner
- `get-last-activity`: Get last activity block height
- `get-inactivity-period`: Get current inactivity period
- `get-heir-info`: Get heir's share and index
- `check-inactive`: Check if contract is inactive
- `is-heir`: Check if address is an heir

## 🚀 Usage

1. Deploy the contract
2. Add heirs using `add-heir` with their addresses and shares
3. Configure inactivity period if needed
4. Regularly use `update-activity` to show wallet activity
5. Heirs can claim their share using `claim-inheritance` after inactivity period

## ⚠️ Important Notes

- Shares are in basis points (100% = 10000)
- Maximum 5 heirs allowed
- Owner must maintain activity to prevent premature inheritance
- Contract balance must be maintained for inheritance distribution

## 🔧 Testing

Use Clarinet's test environment to verify contract functionality:

```clarity
(contract-call? .inheritance-smart-contract add-heir 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u5000)
```

# 🏆 BettingApp

A decentralized betting application built with Solidity and Foundry, where users can propose and participate in bets using an ERC-20 token (`TestToken`). The platform allows for bet requests, approval by the owner, staking tokens, closing bets, and distributing rewards to winners.

---

## 🚀 Features

- 📝 Users can request new bets with custom options.
- ✅ Only the contract owner can approve and create bets.
- ⏱️ Bets have deadlines and fixed token amounts.
- 💸 A small fee (2%) is deducted from every bet and sent to the contract owner.
- 🧠 Winners are declared by the owner after the deadline.
- 🎁 Winners share the total pool equally (minus fee).
- 🔒 Reentrancy protection with `ReentrancyGuard`.

---

## 🧱 Tech Stack

- **Solidity** `^0.8.13`
- **Foundry** for development and deployment
- **OpenZeppelin Contracts** for standard security
- **ERC-20 Token** used for betting (`TestToken`)

---

## 🔐 Security Features

- ✅ `nonReentrant` modifier to prevent reentrancy exploits
- ✅ Custom errors to save gas and improve clarity
- ✅ `onlyOwner` modifier to protect admin-only functions
- ✅ Controlled bet creation and approval workflow

---

## 🛠️ Installation & Setup

1. **Clone the repository:**

````bash
git clone https://github.com/yourusername/BettingApp.git
cd BettingApp

curl -L https://foundry.paradigm.xyz | bash
foundryup


forge install

anvil

create you .env file and add
PRIVATE_KEY=your_private_key


### Prerequisites:

- [Foundry installed](https://book.getfoundry.sh/getting-started/installation)
- Node.js and a local blockchain (like Hardhat node or Anvil for testing)

### Clone & Install

```bash
git clone https://github.com/your-username/BettingApp.git
cd BettingApp
forge install OpenZeppelin/openzeppelin-contracts
````

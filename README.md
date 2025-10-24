<!-- Don't delete it -->
<div name="readme-top"></div>


<!-- Organization Logo -->
<div align="center" style="display: flex; align-items: center; justify-content: center; gap: 16px;">
  <img width="175" height="175" alt="image" src="https://github.com/user-attachments/assets/1f77b71c-f96a-4f2b-bed2-7a7170f839f0" />
  <img width="175" height="175" alt="image" src="https://github.com/user-attachments/assets/8c5008a3-6c2e-4050-9206-031bbd44cf06" />

</div>

&nbsp;

<!-- Organization Name -->
<div align="center">

[![Static Badge](https://img.shields.io/badge/Stability_Nexus-/Treee-228B22?style=for-the-badge&labelColor=FFC517)](https://treee.stability.nexus/)

</div>

<!-- Organization/Project Social Handles -->
<p align="center">
<a href="https://t.me/StabilityNexus">
<img src="https://img.shields.io/badge/Telegram-black?style=flat&logo=telegram&logoColor=white&color=24A1DE" alt="Telegram Badge"/></a>
&nbsp;&nbsp;
<a href="https://x.com/StabilityNexus">
<img src="https://img.shields.io/twitter/follow/StabilityNexus" alt="X (formerly Twitter) Badge"/></a>
&nbsp;&nbsp;
<a href="https://discord.gg/YzDKeEfWtS">
<img src="https://img.shields.io/discord/995968619034984528?style=flat&logo=discord&logoColor=white&label=Discord&labelColor=5865F2&color=57F287" alt="Discord Badge"/></a>
&nbsp;&nbsp;
<a href="https://news.stability.nexus/">
  <img src="https://img.shields.io/badge/Medium-black?style=flat&logo=medium&logoColor=black&color=white" alt="Medium Badge"></a>
&nbsp;&nbsp;
<a href="https://linkedin.com/company/stability-nexus">
  <img src="https://img.shields.io/badge/LinkedIn-black?style=flat&logo=LinkedIn&logoColor=white&color=0A66C2" alt="LinkedIn Badge"></a>
&nbsp;&nbsp;
<a href="https://www.youtube.com/@StabilityNexus">
  <img src="https://img.shields.io/youtube/channel/subscribers/UCZOG4YhFQdlGaLugr_e5BKw?style=flat&logo=youtube&logoColor=white&labelColor=FF0000&color=FF0000" alt="Youtube Badge"></a>
</p>

---

<div align="center">
<h1>Treee — Solidity Contracts (Foundry)</h1>
</div>

**Treee** is the smart contract layer of the *Treee tree-planting protocol*, enabling on-chain verification, organization management, and NFT issuance for planted trees.  
It powers transparent and auditable sustainability tracking within the **Stability Nexus** ecosystem.

---

## Tech Stack

### Core

- **Solidity (v0.8.28)** — Smart contract development  
- **Foundry (forge, anvil, cast)** — Testing, simulation & deployment  
- **OpenZeppelin Contracts** — Token standards and access control  

### Contracts

- `TreeNft.sol` — NFT for planted trees  
- `Organisation.sol` — Handles organization logic  
- `OrganisationFactory.sol` — Deploys and tracks organizations  
- `CareToken.sol`, `PlanterToken.sol`, `LegacyToken.sol` — Incentive ERC-20 tokens  

---

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Rust toolchain (`rustup`)  
- Node.js (optional, for deployment scripting)

---

### Quickstart

#### 1. Clone the repository
```bash
git clone https://github.com/StabilityNexus/Treee-Solidity.git
cd Treee-Solidity
```

#### 2. Build contracts

```bash
forge build
```

#### 3. Run tests

```bash
forge test
```

#### 4. Start a local node

```bash
anvil
```

#### 5. Deploy (example)

```bash
forge script script/Deploy.s.sol:DeployAllContractsAtOnce \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

---

## Developer Workflow

Run a local node:

```bash
anvil
```

Test in watch mode:

```bash
forge test --watch
```

Interact manually:

```bash
cast call <contract-address> "getOrganisationCount()()" --rpc-url http://127.0.0.1:8545
```

---

## Common Commands

| Command          | Description                 |
| ---------------- | --------------------------- |
| `forge build`    | Compile contracts           |
| `forge test`     | Run tests                   |
| `forge fmt`      | Format Solidity code        |
| `forge snapshot` | Create gas usage reports    |
| `anvil`          | Start local blockchain node |

---

## Contributing

We welcome contributions of all kinds!

1. Fork the repo & create a feature branch:

   ```bash
   git checkout -b feature/AmazingFeature
   ```
2. Commit your changes:

   ```bash
   git commit -m "Add some AmazingFeature"
   ```
3. Run checks:

   ```bash
   forge build && forge test && forge fmt
   ```
4. Push & open a PR 

For bugs, suggestions, or questions — open an issue or reach us on [Discord](https://discord.gg/YzDKeEfWtS).

---

© 2025 **Treee Project** · [Stability Nexus](https://stability.nexus/) ecosystem.


# Asset Backed Security Dapp

This began as a 2017 proof of concept for an asset-backed security on Ethereum.
See the PDF in this repository for the original write-up.

As of 2026, I am rewriting and modernizing this project for web3 prototyping.
The old Truffle app, generated JSON artifacts, and legacy build output have
been removed. The project is now a lean Foundry contract workspace.

## Project Layout

```text
src/       Solidity contracts
script/    Deployment and operational scripts
test/      Foundry tests
```

## Requirements

- Foundry
- A funded test wallet
- An RPC URL for Sepolia, Holesky, or another EVM chain

## Setup

Create a local environment file:

```sh
cp .env.example .env
```

Fill in `.env` with `PRIVATE_KEY` and the RPC URL for the network you want to
use. Use a funded test wallet only.

## Build And Test

Compile the upgraded Solidity 0.8.24 contracts:

```sh
make build
```

Run tests:

```sh
make test
```

There are no Foundry tests yet, but the target is ready.

## Deploy

Deploy `Bank` and `Pool` to Sepolia:

```sh
make deploy-sepolia
```

Deploy to Holesky:

```sh
make deploy-holesky
```

Deploy to another EVM chain configured with `CUSTOM_RPC_URL`:

```sh
make deploy-custom
```

Deployment writes the deployed addresses to `deployments/<network>.json`.

## Notes

The contracts have been upgraded from Solidity 0.4-era syntax to Solidity
0.8.24 and now include struct-based state views for the loan, ledger, bond, and
pool data.

Some legacy PascalCase names remain intentionally for now, so Foundry may print
lint notes during compilation. Compilation succeeds.

# DKG EVM Module

![License](https://img.shields.io/github/license/OriginTrail/dkg-evm-module)
![GitHub Actions Status](https://img.shields.io/github/actions/workflow/status/OriginTrail/dkg-evm-module/checks.yml)
![solidity - v0.8.16](https://img.shields.io/badge/solidity-v0.8.16-07a7930e?logo=solidity)
[![NPM Package](https://img.shields.io/npm/v/dkg-evm-module)](https://www.npmjs.com/package/dkg-evm-module)

This repository contains the smart contracts for OriginTrail V6, which serves as the core module for the Decentralized Knowledge Graph (DKG). The module handles various aspects, such as DKG Node profile management, Knowledge Asset ownership, consensus mechanisms, and others, in order to ensure the secure and efficient operation of the network. The contracts are written in Solidity and can be deployed on Ethereum and compatible networks.

## Repository Structure

This repository contains the following main components:

- `abi`: Stores the generated ABI files for the smart contracts.
- `contracts`: Contains the Solidity source files for the smart contracts.
- `deploy`: Contains deployment scripts for all contracts with additional helpers for automatic deployment on OriginTrail Parachain.
- `deployments`: Contains JSON files with addresses of the latest deployed contracts on OTP (Alphanet / Devnet / Testnet / Mainnet)
- `scripts`: Includes Hardhat scripts that can be run using the Hardhat CLI for specific purposes, such as deploying contracts, generating accounts, or interacting with the blockchain.
- `tasks`: Contains Hardhat tasks that can be executed through the Hardhat CLI to automate various actions and processes related to the project. These tasks can be helpful for interacting with smart contracts, managing deployments, or running custom scripts as needed.
- `test`: Includes the test files for the smart contracts.
- `utils`: Includes utility functions and files used throughout the repository.

## Prerequisites and Setup

Before running the commands, make sure you have the following prerequisites installed:

- [Node.js](https://nodejs.org/) (version 14.x or higher)
- [npm](https://www.npmjs.com/)
- [slither](https://github.com/crytic/slither) (Optional, needed for static Solidity code analysis)

Clone the repository and install the dependencies:

```sh
git clone https://github.com/OriginTrail/dkg-evm-module.git

cd dkg-evm-module

npm install
```

## NPM Scripts
This project utilizes a variety of NPM scripts to run various tasks and processes. The scripts are defined in the package.json file and are designed to be used with the Hardhat CLI, leveraging Hardhat plugins for additional functionality. Here's a brief description of the scripts:

- `clean`: Removes the cache and artifacts folders generated by Hardhat.
- `compile:size`: Compiles the smart contracts and analyzes the size of the compiled contracts using the hardhat-contract-sizer plugin.
- `compile`: Compiles the smart contracts with specific configuration using `hardhat.node.config.ts`.
- `coverage`: Generates a code coverage report for the smart contracts with specific network and coverage settings.
- `deploy:v1:gnosis_chiado_test`, `deploy:v1:gnosis_mainnet`, `deploy:v1:localhost`,  `deploy:v1:otp_mainnet`, `deploy:v1:otp_testnet`, and `deploy:v1`: Deploy version 1 of the smart contracts to various networks including Gnosis Chiado, Hardhat, OriginTrail Parachain Alphanet, OriginTrail Parachain Devnet, OriginTrail Parachain Testnet, and OriginTrail Parachain Mainnet.
- `deploy:v2:gnosis_chiado_test`, `deploy:v2:gnosis_mainnet`, `deploy:v2:localhost`, `deploy:v2:otp_mainnet`, `deploy:v2:otp_testnet`, and `deploy:v2`: Similar to the v1 deploy scripts, these deploy version 2 of the smart contracts to the respective networks.
- `dev:v1`, `dev:v2`, and `dev`: Run local development nodes with Hardhat for different versions of contracts.
- `export-abi`: Updates ABI files according to the current state of the smart contracts.
- `format:fix`: Automatically fixes code formatting issues for JSON, JavaScript, TypeScript, and Solidity files using Prettier.
- `format`: Checks code formatting for the same file types.
- `generate-evm-account` and `generate-otp-account`: Generate new Ethereum and OriginTrail accounts, respectively.
- `lint:fix`, `lint:sol:fix`, `lint:ts:fix`, `lint:sol`, `lint:ts`, and `lint`: Provide various linting functionalities for Solidity and TypeScript files, including fixing issues.
- `mint-test-tokens`: Mints test tokens on the local development network.
- `prepare`: Sets up Husky Git hooks and generates TypeChain typings for the smart contracts.
- `slither:reentrancy` and `slither`: Run Slither static analysis with a focus on reentrancy vulnerabilities, and a general analysis, respectively.
- `test:fulltrace`, `test:gas:fulltrace`, `test:gas:trace`, `test:gas`, `test:integration`, `test:trace`, `test:unit`, `test:v1:integration`, `test:v1:unit`, `test:v1`, `test:v2:integration`, `test:v2:unit`, `test:v2`, and `test`: A comprehensive suite of test scripts for different scenarios, including full trace, gas usage, integration, and unit tests for different versions.
- `typechain`: Generates TypeChain typings for the smart contracts.

These scripts can be run using the `npm run <script-name>` command. For example, to compile the smart contracts, you can run:

```sh
npm run compile
```

## Additional Hardhat tasks
Hardhat has plenty of other useful commands, extended by the installed plugins. Here's a brief description of the most useful tasks:

- `decode`: Decodes encoded ABI data (e.g. input data of transaction).
- `encode_selector`: Calculates EVM function/event/error selector (sighash).
- `encode_data`: Encodes data needed for low-level contract calls.
- `clear_sharding_table`: Removes nodes from sharding table based on Node IDs from the given CSV file (example usage: `npx hardhat clear_sharding_table --file-path ./peers.csv --network otp_testnet`).

These tasks can be run using the `npx hardhat <task-name>` command. For example, to decode input data, you can run:

```sh
npx hardhat decode --data <bytes-data>
```

Usage example of `encode_data` task. Here we want to call ProofManagerV1 function called setReq, and this function can be called only through `forwardCall` in HubController and encoding arguments for this function can be done by using this task:
```sh
npx hardhat encode_data --contract-name ProofManagerV1 --function-name setReq 1 true
```
Alternatively, encoded data can be produced from Remix by copying prepared calldata from ProofManagerV1 setReq call.

## Contracts deployment on parachains

Update environment use OTP_DEVNET/OTP_TESTNET/OTP_MAINNET
```dotenv
RPC_OTP_DEVNET='<https_endpoint>'
EVM_PRIVATE_KEY_OTP_DEVNET='<0x_ethereum_private_key>'
ACCOUNT_WITH_OTP_URI_OTP_DEVNET='<substrate_account_uri>'
```

<br/>

OriginTrail Parachain Devnet (v1 contracts)
```sh
npm run deploy:v1:otp_devnet
```
or (v2 contracts)
```sh
npm run deploy:v2:otp_devnet
```

<br/>

OriginTrail Parachain Testnet (v1 contracts)
```sh
npm run deploy:v1:otp_testnet
```
or (v2 contracts)
```sh
npm run deploy:v2:otp_testnet
```

<br/>

OriginTrail Parachain Mainnet (v1 contracts)
```sh
npm run deploy:v1:otp_mainnet
```
or (v2 contracts)
```sh
npm run deploy:v2:otp_mainnet
```

<br/>

Gnosis Chiado Dev (v1 contracts)
```sh
npm run deploy:v1:gnosis_chiado_dev
```
or (v2 contracts)
```sh
npm run deploy:v2:gnosis_chiado_dev
```

<br/>

Gnosis Chiado Test (v1 contracts)
```sh
npm run deploy:v1:gnosis_chiado_test
```
or (v2 contracts)
```sh
npm run deploy:v2:gnosis_chiado_test
```

<br/>

Gnosis Mainnet (v1 contracts)
```sh
npm run deploy:v1:gnosis_mainnet
```
or (v2 contracts)
```sh
npm run deploy:v2:gnosis_mainnet
```

<br/>

### Redeploy contract

In order to redeploy desired contract, set `deployed` to `false` in `deployments/<network>_contracts.json`.

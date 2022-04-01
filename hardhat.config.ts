import '@typechain/hardhat';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-ethers';
import 'hardhat-deploy';

import * as dotenv from 'dotenv';
import { HardhatUserConfig, NetworkUserConfig, SolcUserConfig } from 'hardhat/types';

dotenv.config();

const DEFAULT_MNEMONIC = 'title spike pink garlic hamster sorry few damage silver mushroom clever window';

const { TESTNET_PK, TESTNET_URL, MAINNET_PK, MAINNET_URL } = process.env;

if (!TESTNET_PK) {
  console.warn('TESTNET_PK is unset. Using DEFAULT_MNEMONIC');
}

if (!MAINNET_PK) {
  console.warn('MAINNET_PK is unset. Using DEFAULT_MNEMONIC');
}

const testnet: NetworkUserConfig = {
  chainId: 2021,
  url: TESTNET_URL || 'https://testnet.skymavis.one/rpc',
  accounts: TESTNET_PK ? [TESTNET_PK] : { mnemonic: DEFAULT_MNEMONIC },
  blockGasLimit: 100000000,
};

const mainnet: NetworkUserConfig = {
  chainId: 2020,
  url: MAINNET_URL || 'https://api.roninchain.com/rpc',
  accounts: MAINNET_PK ? [MAINNET_PK] : { mnemonic: DEFAULT_MNEMONIC },
  blockGasLimit: 100000000,
};

const compilerConfig: SolcUserConfig = {
  version: '0.5.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
};

const config: HardhatUserConfig = {
  solidity: {
    compilers: [compilerConfig, { ...compilerConfig, version: '0.8.9' }],
  },
  typechain: {
    outDir: 'src/types',
  },
  paths: {
    deploy: 'src/deploy',
  },
  namedAccounts: {
    deployer: 0,
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic: DEFAULT_MNEMONIC,
      },
    },
    'ronin-testnet': testnet,
    'ronin-mainnet': mainnet,
  },
};

export default config;

import * as dotenv from "dotenv";
import { HardhatUserConfig, task } from "hardhat/config";
dotenv.config({ path: __dirname + '/.env' });

import '@openzeppelin/hardhat-upgrades';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-gas-reporter';
import 'hardhat-deploy-ethers';
import 'hardhat-deploy';

const {
  PUBLIC_KEY,
  PRIVATE_KEY,
  BSCSCAN_API_KEY,
  POLYSCAN_API_KEY,
  ALCHEMY_API_KEY,
} = process.env;

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  networks: {
    testnet: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [`${PRIVATE_KEY}`],
    },
    mainnet: {
      url: `https://bsc-dataseed1.ninicoin.io`,
      chainId: 56,
      gasPrice: 20000000000,
      accounts: [`${PRIVATE_KEY}`],
    },
    hardhat: {
    }
  },
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  gasReporter: {
    enabled: false,
    currency: 'USD',
    gasPrice: 120,
    showTimeSpent: true
  },
  etherscan: {
    apiKey: BSCSCAN_API_KEY,
  },
  namedAccounts: {
    deployer: {
      default: 0,
      1: `${PUBLIC_KEY}`,
      42: `${PUBLIC_KEY}`,
    },
  }
}
export default config;

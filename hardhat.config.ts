import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.7.6",
  networks: {
    hardhat: {
      forking: {
        url: process.env.ETHEREUM_RPC_URL!,
        blockNumber: 20715424,
      },
      chainId: 1
    },
  },
};

export default config;

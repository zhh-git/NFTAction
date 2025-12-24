import { defineConfig } from "hardhat/config";
import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import dotenv from "dotenv"

dotenv.config();

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin],
  solidity: {
    version: "0.8.28",
  },
  networks: {
    sepolia: {
      type: "http",
      url: `https://sepolia.infura.io/v3/${process.env.SEPOLIA_RPC_URL}`,
      accounts: [
        `${process.env.SEPOLIA_PRIVATE_KEY}`,
        `${process.env.SEPOLIA_PRIVATE_KEY_2}`,
      ]
    }
  }
});

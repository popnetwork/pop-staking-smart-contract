require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
require("dotenv/config")
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("solidity-coverage");
require('@openzeppelin/hardhat-upgrades');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.6.12",
  networks: {
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    bsc: {
      url: `https://bsc-dataseed.binance.org`,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    bsctest: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};


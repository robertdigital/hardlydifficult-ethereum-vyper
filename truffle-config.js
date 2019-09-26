const HDWalletProvider = require('truffle-hdwallet-provider');

module.exports = {
  mocha: {
    enableTimeouts: false
  },
  compilers: {
    solc: {
      version: '0.5.11',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
};

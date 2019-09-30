module.exports = {
  mocha: {
    bail: true,
    enableTimeouts: false,
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

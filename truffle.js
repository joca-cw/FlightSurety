var HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "bring tomato sunset ensure dismiss liar volume remain fabric steak domain dove";

module.exports = {
  networks: {
    develop: {
      port: 9545,
    },
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
      },
      network_id: '*',
      //gas: 9999999
    }
  },
  // compilers: {
  //   solc: {
  //     version: "0.8.13"
  //   }
  // }
};
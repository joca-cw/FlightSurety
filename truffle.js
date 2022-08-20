var HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "bring tomato sunset ensure dismiss liar volume remain fabric steak domain dove";

module.exports = {
  networks: {   
    develop: {          // ganache-cli
      host: "127.0.0.1",
      port: 8545,
      network_id: 1661007178472 // network id of ganache-cli
    },
    // development: {
    //   provider: function() {
    //     return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
    //   },
    //   network_id: '*',
    //   //gas: 9999999
    // }
  },
  // compilers: {
  //   solc: {
  //     version: "0.8.13"
  //   }
  // }
};
var Migrations = artifacts.require("./Migrations.sol");
var Monitor = artifacts.require("./ColdChainMonitorComplex.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
};

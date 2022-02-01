const { ethers, upgrades } = require("hardhat");
const util = require('util');

void async function main() {

    const [owner] = await ethers.getSigners();
    const Ubi = await ethers.getContractFactory("Ubi");
    txFeeWallet = await upgrades.deployProxy(Ubi, 
        [owner.address, "0x64d7b379067e46050E147F2b1DD2F07C74CAC472"], 
        { initializer: 'initialize' });
    console.log(txFeeWallet.address);
}();
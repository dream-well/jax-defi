const { ethers, upgrades } = require("hardhat");
const util = require('util');

void async function main() {

    const [owner] = await ethers.getSigners();
    const Ubi = await ethers.getContractFactory("Ubi");
    const wjax_address = '0x783f4A2EfAB4f34D6a0D88b71cf1FAc6d9B46FF0';
    txFeeWallet = await upgrades.deployProxy(Ubi, 
        [owner.address, wjax_address, 300], 
        { initializer: 'initialize' });
    console.log(txFeeWallet.address);
}();
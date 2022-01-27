const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const ether = require('ethers');
const util = require('util');

const timer = util.promisify(setTimeout);

const pancakeRouterAddr = "0x9ac64cc6e4415144c455bd8e4837fea55603e5c3";

const max_uint = "1" + "0".repeat(70);

void async function main() {

    const [owner] = await ethers.getSigners();
    const Ubi = await ethers.getContractFactory("Ubi");
    txFeeWallet = await upgrades.deployProxy(Ubi, 
        [owner.address, "0x64d7b379067e46050E147F2b1DD2F07C74CAC472"], 
        { initializer: 'initialize' });
    console.log(txFeeWallet.address);
}();
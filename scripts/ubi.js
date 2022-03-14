const { ethers, upgrades } = require("hardhat");
const util = require('util');

void async function main() {

    const [owner] = await ethers.getSigners();
    const Haber = await ethers.getContractFactory("HaberStornetta");
    const wjxn = '0xca1262e77fb25c0a4112cfc9bad3ff54f617f2e6';
    haber = await Haber.deploy('0xca1262e77fb25c0a4112cfc9bad3ff54f617f2e6');
    console.log(haber.address);
}();
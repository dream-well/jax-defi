const chai = require("chai");
const { expect } = chai;
var chaiAsPromised = require("chai-as-promised");
const ether = require('ethers');
const { providers } = require("ethers");
const util = require('util');
const { ethers, upgrades } = require("hardhat");

chai.use(chaiAsPromised);

const timer = util.promisify(setTimeout);

describe("PancakeRouter", async function () {  

  let pancakeRouter;
  let factory;
  let weth;

  beforeEach(async () => {
    const [owner] = await ethers.getSigners();
    const PancakeFactory = await ethers.getContractFactory("PancakeFactory");
    factory = await PancakeFactory.deploy(owner.address);
    const WETH = await ethers.getContractFactory("WETH");
    weth = await WETH.deploy();
    const PancakeRouter = await ethers.getContractFactory("PancakeRouter"); 
    pancakeRouter = await PancakeRouter.deploy(factory.address, weth.address);
  })



  it("factory", async function () {
    expect(await pancakeRouter.factory()).to.equal(factory.address);
  });

  it("createPair", async () => {
    const [owner, token1, token2] = await ethers.getSigners();
    await factory.createPair(token1.address, token2.address);
    
    const pair = await factory.getPair(token1.address, token2.address);
  })


});
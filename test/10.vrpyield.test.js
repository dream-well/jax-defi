const chai = require("chai");
const { expect } = chai;
var chaiAsPromised = require("chai-as-promised");
const util = require('util');
const { ethers, upgrades } = require("hardhat");
const {solidity} = require("ethereum-waffle");

chai.use(chaiAsPromised);
chai.use(solidity);

const timer = util.promisify(setTimeout);

describe("VRP yield test", function () {
  let vrp;
  let jaxAdmin;
  let wjxn;
  let wjax;
  let busd;
  let pancakeRouter;
  let factory;
  let weth;
  let lpYield;
  let owner, user1;

  async function deployPancakeRouter() {
    [owner, user1] = await ethers.getSigners();
    const PancakeFactory = await ethers.getContractFactory("PancakeFactory");
    factory = await PancakeFactory.deploy(owner.address);
    const WETH = await ethers.getContractFactory("WETH");
    weth = await WETH.deploy();
    const PancakeRouter = await ethers.getContractFactory("PancakeRouter"); 
    pancakeRouter = await PancakeRouter.deploy(factory.address, weth.address);
  }

  it("VRP yield test", async function () {
    const [owner, user1, user2, user3] = await ethers.getSigners();

    await deployPancakeRouter();
    const JaxAdmin = await ethers.getContractFactory("JaxAdmin"); 
    let jaxAdmin = await upgrades.deployProxy(JaxAdmin, [pancakeRouter.address], { initializer: 'initialize' });
    await jaxAdmin.setJaxSwap(user1.address);
    const ERC20 = await ethers.getContractFactory("CommonBEP20");
    let wjax = await ERC20.deploy("WJAX", "WJAX", 0);
    wjax.mint(owner.address, "10000000000000");
    wjax.mint(user1.address, "1000");


    const VRP = await ethers.getContractFactory("VRP");
    const vrp = await VRP.deploy();

    jaxAdmin.setTokenAddresses(wjax.address,wjax.address,wjax.address,wjax.address,wjax.address);

    await vrp.initialize(jaxAdmin.address);
    await jaxAdmin.setJaxSwap(owner.address);
    await vrp.set_reward_token(wjax.address);
    await wjax.approve(vrp.address, "1000000000000");
    
    await printCurrentBlock();
    await vrp.mint(owner.address, ethers.utils.parseUnits("1000"));
    console.log("owner mints 100 vrp");

    await printCurrentBlock();
    await vrp.deposit_reward("1000");
    // console.log(await vrp.epochInfo(1));
    await vrp.harvest();

    await waitBlocks(9);
    await vrp.deposit_reward("1000");
    console.log("apy", await vrp.get_latest_apy());
  });
});

async function waitBlocks(count) {
  let blockNumber = await ethers.provider.getBlockNumber();
    let currentNumber = 0;
    while(blockNumber + count > currentNumber ) {  
      const ERC20 = await ethers.getContractFactory("CommonBEP20");
      await ERC20.deploy("WJAX", "WJAX", 4);
      currentNumber = await ethers.provider.getBlockNumber();
    }
}

async function printCurrentBlock() {
  let currentNumber = await ethers.provider.getBlockNumber();
  console.log("Blocknumber:",currentNumber);
}
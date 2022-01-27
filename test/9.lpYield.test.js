const chai = require("chai");
const { expect } = chai;
var chaiAsPromised = require("chai-as-promised");
const util = require('util');
const { ethers, upgrades } = require("hardhat");
const {solidity} = require("ethereum-waffle");

chai.use(chaiAsPromised);
chai.use(solidity);

const timer = util.promisify(setTimeout);

describe("LpYield", function () {

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

  beforeEach(async () => {
    await deployPancakeRouter();
    const [owner] = await ethers.getSigners();

    const JaxAdmin = await ethers.getContractFactory("JaxAdmin"); 
    jaxAdmin = await upgrades.deployProxy(JaxAdmin, [pancakeRouter.address], { initializer: 'initialize' });
    // const VRP = await ethers.getContractFactory("VRP");
    // vrp = await upgrades.deployProxy(VRP, [jaxAdmin.address], { initializer: 'initialize' });;
    // await vrp.setJaxAdmin(jaxAdmin.address);
    // await vrp.setJaxSwap(jaxSwap.address);
    const JaxPlanet = await ethers.getContractFactory("JaxPlanet");
    jaxPlanet = await upgrades.deployProxy(JaxPlanet, [jaxAdmin.address], { initializer: 'initialize' });

    // Tokens
    const ERC20 = await ethers.getContractFactory("CommonBEP20");
    busd = await ERC20.deploy("Pegged USD Binance", "BUSD", 18);
    busd = await ERC20.deploy("Pegged USD Jax", "JUSD", 18);

    wjxn = await ERC20.deploy("Wrapped Jaxnet", "WJXN", 0);

    const JaxToken = await ethers.getContractFactory("JaxToken");
    wjax = await JaxToken.deploy("Wrapped Jax", "WJAX", 4);
    await wjax.setJaxAdmin(jaxAdmin.address);
    await jaxAdmin.setJaxSwap(owner.address);
    await jaxAdmin.setJaxPlanet(jaxPlanet.address);

    await wjxn.mint(owner.address, "1000000000000");
    await wjax.mint(owner.address, ethers.utils.parseUnits("10000000000", 4));
    await busd.mint(owner.address, ethers.utils.parseUnits("10000000000", 18));

    await wjxn.approve(pancakeRouter.address, "1" + "0".repeat(70));
    await wjax.approve(pancakeRouter.address, "1" + "0".repeat(70));
    await busd.approve(pancakeRouter.address, "1" + "0".repeat(70));

    // // wjax-busd pair
    await factory.createPair(wjxn.address, wjax.address);
    const pair_address = await factory.getPair(wjxn.address, wjax.address);
    
    const PancakePair = await ethers.getContractFactory("PancakePair");
    const pair = await PancakePair.attach(pair_address);
    
    // console.log(pair_address, await pancakeRouter.pairFor(factory.address, wjxn.address, wjax.address));
    await pancakeRouter.addLiquidity(wjxn.address, wjax.address,  ethers.utils.parseUnits("100000000", 0), ethers.utils.parseUnits("100000000", 4), 
      0, 0, owner.address, parseInt((new Date).getTime() / 1000 + 1000) + "");
    await pancakeRouter.addLiquidity(wjax.address, busd.address, ethers.utils.parseUnits("100000000", 4), ethers.utils.parseUnits("100000000", 18), 0, 0, owner.address, parseInt((new Date).getTime() / 1000 + 1000) + "");
    await pancakeRouter.addLiquidity(wjxn.address, busd.address, ethers.utils.parseUnits("100000000", 0), ethers.utils.parseUnits("100000000", 18), 0, 0, owner.address, parseInt((new Date).getTime() / 1000 + 1000) + "");
    
    const JaxLibrary = await ethers.getContractFactory("JaxLibrary");
    const jaxLibrary = await JaxLibrary.deploy();
    // JaxSwap
    

    const LpYield = await ethers.getContractFactory("LpYield"); 
    lpYield = await upgrades.deployProxy(LpYield, 
        [jaxAdmin.address, pancakeRouter.address, busd.address, wjax.address], { initializer: 'initialize', unsafeAllowLinkedLibraries: true });
    await lpYield.set_reward_token(wjxn.address);
  })

  it("Swap Tokens", async function () {

    // await busd.transfer(lpYield.address, "500");
    await busd.approve(lpYield.address, "1"+"0".repeat(70));
    await busd.connect(user1).approve(lpYield.address, "1"+"0".repeat(70));
    await busd.transfer(user1.address, "100000" + "0".repeat("18"));
    await jaxAdmin.setPriceImpactLimit("3000000");
    // await lpYield.setFairPrice("300000000");
    
    // await expect(lpYield.depositBUSD("100" + "0".repeat(18))).to.eventually.be.rejectedWith(Error, "VM Exception while processing transaction: reverted with reason string 'Price Impact too high'");
    await lpYield.set_busd_deposit_range(0, ethers.utils.parseUnits("100000"));

    await jaxAdmin.setPriceImpactLimit("3000000");
    await lpYield.depositBUSD("10000" + "0".repeat(18));
    // await lpYield.connect(user1).depositBUSD("1000" + "0".repeat(18));
    // await lpYield.depositBUSD("10000" + "0".repeat(18));
    await wjxn.approve(lpYield.address, "1" + "0".repeat(70));
    await lpYield.deposit_reward("10000");

    
    await waitBlocks(10);
    await lpYield.deposit_reward("10000");


    let epochInfo = await lpYield.epochInfo(1);
    console.log(epochInfo);
    // await lpYield.updateReward(owner.address);
    console.log("current epoch", await lpYield.currentEpoch());
    await waitBlocks(1);
    console.log("userInfo", await lpYield.userInfo(owner.address));
    console.log("apy", await lpYield.get_latest_apy());
    console.log("owner", await lpYield.pendingReward(owner.address));
    console.log("price", await lpYield.getPrice(wjxn.address, busd.address));
    let tx = await lpYield.harvest();
    // console.log(tx);
    // await lpYield.withdraw();
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
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const ether = require('ethers');
const util = require('util');

const timer = util.promisify(setTimeout);

describe("UbiTaxWallet", function () {

  let vrp;
  let jaxAdmin;
  let wjxn;
  let wjax;
  let jusd;
  let busd;
  let pancakeRouter;
  let factory;
  let weth;
  let ubiTaxWallet;

  async function deployPancakeRouter() {
    const [owner] = await ethers.getSigners();
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
    jaxAdmin = await upgrades.deployProxy(JaxAdmin, [], { initializer: 'initialize' });
    // const VRP = await ethers.getContractFactory("VRP");
    // vrp = await upgrades.deployProxy(VRP, [jaxAdmin.address], { initializer: 'initialize' });;
    // await vrp.setJaxAdmin(jaxAdmin.address);
    // await vrp.setJaxSwap(jaxSwap.address);
    const JaxPlanet = await ethers.getContractFactory("JaxPlanet");
    jaxPlanet = await upgrades.deployProxy(JaxPlanet, [jaxAdmin.address], { initializer: 'initialize' });

    // Tokens
    const ERC20 = await ethers.getContractFactory("CommonBEP20");
    busd = await ERC20.deploy("Pegged USD Binance", "BUSD", 18);
    jusd = await ERC20.deploy("Pegged USD Jax", "JUSD", 18);

    wjxn = await ERC20.deploy("Wrapped Jaxnet", "WJXN", 0);

    const JaxToken = await ethers.getContractFactory("JaxToken");
    wjax = await JaxToken.deploy("Wrapped Jax", "WJAX", 4);
    await wjax.setJaxAdmin(jaxAdmin.address);
    await wjax.setJaxSwap(owner.address);
    await wjax.setJaxPlanet(jaxPlanet.address);

    await wjxn.mint(owner.address, "1000000000000");
    await wjax.mint(owner.address, ethers.utils.parseUnits("10000000000", 4));
    await jusd.mint(owner.address, ethers.utils.parseUnits("10000000000", 18));

    await wjxn.approve(pancakeRouter.address, "1" + "0".repeat(70));
    await wjax.approve(pancakeRouter.address, "1" + "0".repeat(70));
    await jusd.approve(pancakeRouter.address, "1" + "0".repeat(70));

    // // wjax-busd pair
    await factory.createPair(wjxn.address, wjax.address);
    const pair_address = await factory.getPair(wjxn.address, wjax.address);
    
    const PancakePair = await ethers.getContractFactory("PancakePair");
    const pair = await PancakePair.attach(pair_address);
    
    // console.log(pair_address, await pancakeRouter.pairFor(factory.address, wjxn.address, wjax.address));
    await pancakeRouter.addLiquidity(wjxn.address, wjax.address,  ethers.utils.parseUnits("10000", 0), ethers.utils.parseUnits("10000", 4), 
      ethers.utils.parseUnits("100", 0), ethers.utils.parseUnits("100", 4), owner.address, parseInt((new Date).getTime() / 1000 + 1000) + "");
    await pancakeRouter.addLiquidity(wjax.address, jusd.address, "1000000", ethers.utils.parseUnits("1000000", 18), 0, 0, owner.address, parseInt((new Date).getTime() / 1000 + 1000) + "");


    const UbiTaxWallet = await ethers.getContractFactory("UbiTaxWallet"); 
    ubiTaxWallet = await upgrades.deployProxy(UbiTaxWallet, 
        [jaxAdmin.address, pancakeRouter.address, wjax.address], { initializer: 'initialize' });
    
  })

  it("Swap Tokens", async function () {

    await ubiTaxWallet.set_yield_tokens([wjxn.address, jusd.address]);
    await wjxn.transfer(ubiTaxWallet.address, "1000");
    // await jusd.transfer(ubiTaxWallet.address, "500");
    await ubiTaxWallet.swap_tokens();

    expect(await wjxn.balanceOf(ubiTaxWallet.address)).to.equal(ethers.BigNumber.from(0));
    expect(await jusd.balanceOf(ubiTaxWallet.address)).to.equal(ethers.BigNumber.from(0));
  });
});
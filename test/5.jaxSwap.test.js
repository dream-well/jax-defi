const chai = require("chai");
const { expect } = chai;
var chaiAsPromised = require("chai-as-promised");
const util = require('util');
const { ethers, upgrades } = require("hardhat");
const {solidity} = require("ethereum-waffle");

chai.use(chaiAsPromised);
chai.use(solidity);

const timer = util.promisify(setTimeout);

let jaxSwap;
let jaxAdmin;
let jaxPlanet;
let weth;
let wjxn;
let wjax;
let jusd;
let vrp;
let busd;
let owner;

describe("jaxSwap", async function () {  


  beforeEach(async () => {
    [owner] = await ethers.getSigners();
    await deployPancakeRouter();
    await deployJaxAdmin();

    // Tokens
    const ERC20 = await ethers.getContractFactory("CommonBEP20");
    busd = await ERC20.deploy("Pegged USD Binance", "BUSD", 18);
    
    wjxn = await ERC20.deploy("Wrapped Jaxnet", "WJXN", 0);

    const JaxToken = await ethers.getContractFactory("JaxToken");
    const WJAX = await ethers.getContractFactory("WJAX");
    wjax = await WJAX.deploy("Wrapped Jax", "WJAX", 4);
    jusd = await JaxToken.deploy("Jax USD", "JUSD", 18);

    const VRP = await ethers.getContractFactory("VRP");
    vrp = await upgrades.deployProxy(VRP, [jaxAdmin.address], { initializer: 'initialize' });;
    
    // // wjax-busd pair
    await factory.createPair(wjax.address, busd.address);
    const wjax_busd_pair = await factory.getPair(wjax.address, busd.address);

    // JaxSwap
    const JaxSwap = await ethers.getContractFactory("JaxSwap");
    jaxSwap = await upgrades.deployProxy(JaxSwap, [jaxAdmin.address, pancakeRouter.address], { initializer: 'initialize', unsafeAllowLinkedLibraries: true });

    const JaxPlanet = await ethers.getContractFactory("JaxPlanet");
    jaxPlanet = await upgrades.deployProxy(JaxPlanet, [jaxAdmin.address], { initializer: 'initialize' });


    await jaxAdmin.setJaxSwap(jaxSwap.address);
    await jaxAdmin.setJaxPlanet(jaxPlanet.address);

    await wjax.setJaxAdmin(jaxAdmin.address);
    await wjax.setGateKeepers([owner.address]);
    await wjax.setMintBurnLimit(owner.address, 1e12, 1e12);
    await wjax.mint(owner.address, 1e12);

    await jusd.setJaxAdmin(jaxAdmin.address);

    await vrp.setJaxAdmin(jaxAdmin.address);

    await jaxAdmin.setTokenAddresses(busd.address, wjxn.address, wjax.address, vrp.address, jusd.address);

    await wjxn.approve(jaxSwap.address, 1e12);
    await wjax.approve(jaxSwap.address, 1e12);
    await vrp.approve(jaxSwap.address, 1e12 + "0".repeat(18));
    await jusd.approve(jaxSwap.address, 1e12 + "0".repeat(18));
  })

  it("setJaxAdmin", async () => {
    await expect(await jaxSwap.setJaxAdmin(jaxAdmin.address)).to
      .emit(jaxSwap, "Set_Jax_Admin")
      .withArgs(jaxAdmin.address);
  });


  async function swap_wjxn_vrp() {
    const [user] = await ethers.getSigners();
    await wjxn.mint(user.address, ethers.utils.parseUnits("10000", 0));
    await wjxn.approve(jaxSwap.address, ethers.utils.parseUnits("10000", 0));

    const amountIn = 1000;
    const amountOut = amountIn * 1;
    await expect(jaxSwap.swap_wjxn_vrp(ethers.utils.parseUnits(amountIn + "", 0))).to
      .emit(jaxSwap, "Swap_WJXN_VRP")
      .withArgs(user.address, ethers.utils.parseUnits(amountIn + "", 0),  ethers.utils.parseUnits(amountOut + "", 18))
  }


  it("swap_wjxn_vrp", async () => {
   await swap_wjxn_vrp();
   await swap_wjxn_vrp();
  })

  it("swap_vrp_wjxn", async () => {
    await swap_wjxn_vrp();
    const [user] = await ethers.getSigners();
    await vrp.approve(jaxSwap.address, ethers.utils.parseUnits("100000", 18));

    const amountIn = 500;
    const amountOut = amountIn * 1;
    
    await expect(jaxSwap.swap_vrp_wjxn(ethers.utils.parseUnits(amountIn + "", 18))).to
      .emit(jaxSwap, "Swap_VRP_WJXN")
      .withArgs(user.address, ethers.utils.parseUnits(amountIn + "", 18),  ethers.utils.parseUnits(amountOut + "", 0))

    await jaxAdmin.set_freeze_vrp_wjxn_swap(1);

    const swap_vrp_wjxn = jaxSwap.swap_vrp_wjxn(ethers.utils.parseUnits(amountIn + "", 18));

    await expect(swap_vrp_wjxn).to.eventually.be.rejectedWith(Error, "VM Exception while processing transaction: reverted with reason string 'Freeze VRP-WJXN Swap'");
    
  })

  async function swap_wjax_jusd() {

    const amountIn = 1000;
    const amountOut = amountIn * 1;
    await jaxAdmin.set_wjax_usd_ratio(1e8);
    await expect(jaxSwap.swap_wjax_jusd(ethers.utils.parseUnits(amountIn + "", 4))).to
      .emit(jaxSwap, "Swap_WJAX_JUSD")
      .withArgs(owner.address, ethers.utils.parseUnits(amountIn + "", 4),  ethers.utils.parseUnits(amountOut + "", 18))    
  }

  it("swap_wjax_jusd", async () => {
    await swap_wjax_jusd();
  })

  it("swap_jusd_wjax", async () => {
    await swap_wjax_jusd();

    const amountIn = 1000;
    const amountOut = amountIn * 0.5;
    expect(await wjax.balanceOf(jaxSwap.address)).to.equal(ethers.utils.parseUnits("1000", 4));
    await jaxAdmin.set_wjax_usd_ratio_emergency(2e8);
    await jaxAdmin.set_wjax_jusd_markup_fee(0, owner.address);
    await expect(jaxSwap.swap_jusd_wjax(ethers.utils.parseUnits(amountIn + "", 18))).to
      .emit(jaxSwap, "Swap_JUSD_WJAX")
      .withArgs(owner.address, ethers.utils.parseUnits(amountIn + "", 18),  ethers.utils.parseUnits(amountOut + "", 4))    
    
  })


});


async function deployPancakeRouter() {
  const [owner] = await ethers.getSigners();
  const PancakeFactory = await ethers.getContractFactory("PancakeFactory");
  factory = await PancakeFactory.deploy(owner.address);
  const WETH = await ethers.getContractFactory("WETH");
  weth = await WETH.deploy();
  const PancakeRouter = await ethers.getContractFactory("PancakeRouter"); 
  pancakeRouter = await PancakeRouter.deploy(factory.address, weth.address);
}

async function deployJaxAdmin() {
  const JaxAdmin = await ethers.getContractFactory("JaxAdmin"); 
  jaxAdmin = await upgrades.deployProxy(JaxAdmin, [pancakeRouter.address], { initializer: 'initialize' });
}
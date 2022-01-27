const chai = require("chai");
const { expect } = chai;
var chaiAsPromised = require("chai-as-promised");
const ether = require('ethers');
const { providers } = require("ethers");
const util = require('util');
const { ethers, upgrades } = require("hardhat");

chai.use(chaiAsPromised);

const timer = util.promisify(setTimeout);


let vrp, jaxAdmin, jaxSwap;
let owner;

describe("VRP", async function () {  

  beforeEach(async () => {
    [owner, jaxSwap ] = await ethers.getSigners();
    await deployPancakeRouter();
    await deployJaxAdmin();
    const VRP = await ethers.getContractFactory("VRP");
    vrp = await upgrades.deployProxy(VRP, [jaxAdmin.address], { initializer: 'initialize' });
    await vrp.setJaxAdmin(jaxAdmin.address);

  })

  it("decimal check", async function(){
    expect(await vrp.decimals()).to.equal(18); 
  })

  it("set Jax Admin", async function(){
    expect(await vrp.jaxAdmin()).to.equal(jaxAdmin.address);
  })

  it("mint", async function(){
    const [owner, user1] = await ethers.getSigners();

    await vrp.connect(jaxSwap).mint(user1.address, ethers.utils.parseUnits("10000.0", 18));
    expect((await vrp.balanceOf(user1.address)).toString()).to.equal(ethers.utils.parseUnits("10000.0", 18).toString());
  })

  it("burn", async function(){
    const [owner, user1] = await ethers.getSigners();
    await vrp.connect(jaxSwap).mint(user1.address, ethers.utils.parseUnits("10000.0", 18));
    
    await vrp.connect(user1).approve(jaxSwap.address, ethers.utils.parseUnits("10000000000", 18));
    // burn
    await vrp.connect(jaxSwap).burnFrom(user1.address, ethers.utils.parseUnits("600.0", 18));
    expect((await vrp.balanceOf(user1.address)).toString()).to.equal(ethers.utils.parseUnits("9400.0", 18).toString());

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
  jaxAdmin.setJaxSwap(jaxSwap.address);
}
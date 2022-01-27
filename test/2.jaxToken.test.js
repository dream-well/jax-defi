const chai = require("chai");
const { expect } = chai;
var chaiAsPromised = require("chai-as-promised");
const ether = require('ethers');
const { providers } = require("ethers");
const util = require('util');
const { ethers, upgrades } = require("hardhat");

chai.use(chaiAsPromised);

const timer = util.promisify(setTimeout);

let jaxToken, jaxAdmin, jaxSwap;
let jaxPlanet;
let pancakeRouter;
let factory;
let owner;

describe("JaxToken", async function () {  

  beforeEach(async () => {
    [owner] = await ethers.getSigners();
    jaxSwap = owner;
    await deployPancakeRouter();
    await deployJaxAdmin();

    const JaxPlanet = await ethers.getContractFactory("JaxPlanet");
    jaxPlanet = await upgrades.deployProxy(JaxPlanet, [jaxAdmin.address], {initializer: 'initialize'});

    jaxAdmin.setJaxPlanet(jaxPlanet.address);

    const JaxToken = await ethers.getContractFactory("JaxToken");
    jaxToken = await JaxToken.deploy("Wrapped Jax", "WJAX", 4);
    await jaxToken.setJaxAdmin(jaxAdmin.address);
  })

  it("decimal check", async function(){
    expect(await jaxToken.decimals()).to.equal(4); 
  })

  it("set Jax Admin", async function(){
    expect(await jaxToken.jaxAdmin()).to.equal(jaxAdmin.address);
  })


  it("mint", async function(){
    const [owner, user1] = await ethers.getSigners();

    await jaxToken.mint(user1.address, ethers.utils.parseUnits("10000.0", 4));
    expect((await jaxToken.balanceOf(user1.address)).toString()).to.equal(ethers.utils.parseUnits("10000.0", 4).toString());
  })

  it("burn", async function(){
    const [owner, user1] = await ethers.getSigners();
    await jaxToken.mint(user1.address, ethers.utils.parseUnits("10000.0", 4));
    
    await jaxToken.connect(user1).approve(owner.address, ethers.utils.parseUnits("10000000000", 4));
    // burn
    await jaxToken.connect(owner).burnFrom(user1.address, ethers.utils.parseUnits("600.0", 4));
    expect((await jaxToken.balanceOf(user1.address)).toString()).to.equal(ethers.utils.parseUnits("9400.0", 4).toString());

  })
  
  it("blacklist check", async function(){
    const [owner, user1, user2, user3] = await ethers.getSigners();
    const jaxSwap = owner;

    await jaxToken.connect(user1).approve(jaxSwap.address, ethers.utils.parseUnits("10000000000", 4));

    await jaxAdmin.set_blacklist([user1.address, user2.address], true);
    expect(await jaxAdmin.blacklist(user1.address)).to.equal(true);
    expect(await jaxAdmin.blacklist(user2.address)).to.equal(true);
    expect(await jaxAdmin.blacklist(user3.address)).to.equal(false);

    const mint = jaxToken.connect(jaxSwap).mint(user1.address, ethers.utils.parseUnits("1000.0", 4));
    await expect(mint).to.eventually.be.rejectedWith(Error, "VM Exception while processing transaction: reverted with reason string 'account is blacklisted'");
    
    const burnFrom = jaxToken.connect(jaxSwap).burnFrom(user1.address, ethers.utils.parseUnits("100.0", 4));
    await expect(burnFrom).to.eventually.be.rejectedWith(Error, "VM Exception while processing transaction: reverted with reason string 'account is blacklisted'");
    
    await jaxAdmin.set_blacklist([user1.address, user2.address], false);
    expect(await jaxAdmin.blacklist(user1.address)).to.equal(false);
    expect(await jaxAdmin.blacklist(user2.address)).to.equal(false);

  })

  it("transaction fee", async function(){
    const [owner, tx_fee_wallet, user1, user2] = await ethers.getSigners();
    const setTransactionFee = jaxAdmin.setTransactionFee(jaxToken.address, ethers.utils.parseUnits("0.04", 8), ethers.utils.parseUnits("100", 8), tx_fee_wallet.address);
    await expect(setTransactionFee).to.eventually.be.rejectedWith(Error, "VM Exception while processing transaction: reverted with reason string 'Tx Fee percent can't be more than 3.'");

    // tx fee set 2%
    const tx_fee_percent = 0.02;
    await jaxAdmin.setTransactionFee(jaxToken.address, ethers.utils.parseUnits(tx_fee_percent + "", 8), ethers.utils.parseUnits("100", 8), tx_fee_wallet.address);

    // send 100 jaxtoken to user2
    await jaxToken.connect(jaxSwap).mint(user1.address, ethers.utils.parseUnits("1000.0", 4));
    var send_amount = 100;
    var tx_fee = send_amount * tx_fee_percent;
    var receive_amount = send_amount - tx_fee;
    await jaxToken.connect(user1).transfer(user2.address, ethers.utils.parseUnits(send_amount+"", 4));
    expect((await jaxToken.balanceOf(user2.address)).toString()).to.equal(ethers.utils.parseUnits(receive_amount+"", 4).toString());
    expect((await jaxToken.balanceOf(tx_fee_wallet.address)).toString()).to.equal(ethers.utils.parseUnits(tx_fee+"", 4).toString());


  })

  it("ubi tax", async function(){
    const [owner, ubi_tax_wallet, user1, user2] = await ethers.getSigners();
    var ubi_tax_percent = 0.3;
    await jaxPlanet.setUbiTax(ethers.utils.parseUnits(ubi_tax_percent + "", 8), ubi_tax_wallet.address);


    await jaxToken.connect(jaxSwap).mint(user1.address, ethers.utils.parseUnits("1000.0", 4));
    // send 100 jaxtoken to user2
    var send_amount = 100;
    var ubi_tax = send_amount * ubi_tax_percent;
    var receive_amount = send_amount - ubi_tax;
    await jaxToken.connect(user1).transfer(user2.address, ethers.utils.parseUnits(send_amount+"", 4));
    expect((await jaxToken.balanceOf(user2.address)).toString()).to.equal(ethers.utils.parseUnits(receive_amount+"", 4).toString());
    expect((await jaxToken.balanceOf(ubi_tax_wallet.address)).toString()).to.equal(ethers.utils.parseUnits(ubi_tax+"", 4).toString());

  })

  it("jaxCorpDao", async function(){
    const [owner, jaxCorpDao_wallet, user1, user2] = await ethers.getSigners();
    
    var tx_tax_percent = 0.2;
    await jaxPlanet.setJaxCorpDAO(jaxCorpDao_wallet.address, ethers.utils.parseUnits(tx_tax_percent+"", 8), "policy link", "0x"+"aa".repeat(32));

    await jaxToken.connect(jaxSwap).mint(user1.address, ethers.utils.parseUnits("100.0", 4));
    // send 100 jaxtoken to user2
    var send_amount = 100;
    var tx_tax = send_amount * tx_tax_percent;
    var receive_amount = send_amount - tx_tax;
    await jaxToken.connect(user1).transfer(user2.address, ethers.utils.parseUnits(send_amount+"", 4));
    expect((await jaxToken.balanceOf(user2.address)).toString()).to.equal(ethers.utils.parseUnits(receive_amount+"", 4).toString());
    expect((await jaxToken.balanceOf(jaxCorpDao_wallet.address)).toString()).to.equal(ethers.utils.parseUnits(tx_tax+"", 4).toString());

  })
  
  // it("", async function(){
    
  // })


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
  jaxAdmin.setJaxSwap(owner.address);
}
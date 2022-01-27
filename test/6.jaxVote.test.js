const chai = require("chai");
const { expect } = chai;
var chaiAsPromised = require("chai-as-promised");
const ether = require('ethers');
const { providers } = require("ethers");
const util = require('util');
const { ethers, upgrades } = require("hardhat");

chai.use(chaiAsPromised);

const timer = util.promisify(setTimeout);

describe("vrp", async function () {  
  let vrp;
  let jaxAdmin;
  beforeEach(async () => {
    const [jaxSwap] = await ethers.getSigners();
    const JaxAdmin = await ethers.getContractFactory("JaxAdmin"); 
    jaxAdmin = await upgrades.deployProxy(JaxAdmin, [], { initializer: 'initialize' });
    const VRP = await ethers.getContractFactory("VRP");
    vrp = await upgrades.deployProxy(VRP, [jaxAdmin.address], { initializer: 'initialize' });;
    await vrp.setJaxAdmin(jaxAdmin.address);
    await vrp.setJaxSwap(jaxSwap.address);

    await jaxAdmin.setVRP(vrp.address);
  })

  it("validate_voter", async () => {
    const [owner, candidate] = await ethers.getSigners();
    expect(vrp.vote_governor(candidate.address)).to.eventually.be.rejectedWith(Error, "VM Exception while processing transaction: reverted with reason string 'Only VRP holders can participate voting.'")
  })  

  it("vote_governor", async () => {
    const [owner, candidate1, candidate2, candidate3, user1, user2, user3] = await ethers.getSigners();
    await vrp.mint(owner.address, "100000");
    await vrp.mint(user1.address, "100000");
    await vrp.mint(user2.address, "100000");
    await vrp.vote_governor(candidate1.address);
    await vrp.connect(user1).vote_governor(candidate2.address);
    await expect(vrp.connect(user2).vote_governor(candidate1.address)).to
      .emit(jaxAdmin, "Elect_Governor")
      .withArgs(candidate1.address);
  })

});
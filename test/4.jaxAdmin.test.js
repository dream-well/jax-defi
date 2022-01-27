const chai = require("chai");
const { expect } = chai;
var chaiAsPromised = require("chai-as-promised");
const ether = require('ethers');
const { providers } = require("ethers");
const util = require('util');
const { ethers, upgrades } = require("hardhat");

chai.use(chaiAsPromised);

const timer = util.promisify(setTimeout);

let jaxAdmin;
let owner, admin, governor, ajaxPrime, operator1, operator2, operator3;

describe("JaxAdmin", async function () {  
  beforeEach(async () => {

    [owner, admin, governor, ajaxPrime, operator1, operator2, operator3] = await ethers.getSigners();

    await deployPancakeRouter();
    await deployJaxAdmin();

  })

  it("setAdmin", async function() {
    // console.log("owner", owner.address);
    
    // console.log("jaxadmin address", jaxAdmin.address);

    await jaxAdmin.setAdmin(admin.address);
    const admin_addr = await jaxAdmin.admin();
    // console.log("admin addr", admin_addr);

    expect(admin_addr).to.equal(admin.address);
    expect(await jaxAdmin.userIsAdmin(admin.address)).to.equal(true);
    expect(await jaxAdmin.userIsAdmin(governor.address)).to.equal(false);
  })

  it("setGovernor", async function() {
     //governor, onlyAdmin test
    const [owner, admin, governor] = await ethers.getSigners();

    await jaxAdmin.setAdmin(admin.address);
     const setGovernor = jaxAdmin.connect(governor).setGovernor(governor.address);
     await expect(setGovernor).to.eventually.be.rejectedWith(Error, "VM Exception while processing transaction: reverted with reason string 'Only Admin can perform this operation'");
     await jaxAdmin.connect(admin).setGovernor(governor.address);
     const governor_addr = await jaxAdmin.governor();
     // console.log("governor addr", governor_addr);
 
     expect(governor_addr).to.equal(governor.address);
     expect(await jaxAdmin.userIsGovernor(governor.address)).to.equal(true);
     expect(await jaxAdmin.userIsGovernor(admin.address)).to.equal(false);
  })

  it("setAjaxPrime", async function () {

    const [owner, admin, governor, ajaxPrime] = await ethers.getSigners();
    
    // ajaxPrime, onlyAjaxPrime
    const setAjaxPrime = jaxAdmin.connect(admin).setAjaxPrime(governor.address);
    await expect(setAjaxPrime).to.eventually.be.rejectedWith(Error, "VM Exception while processing transaction: reverted with reason string 'Only AjaxPrime can perform this operation'");
    await jaxAdmin.setAjaxPrime(ajaxPrime.address);
    const ajaxPrime_addr = await jaxAdmin.ajaxPrime();
    // console.log("ajaxPrime addr", ajaxPrime_addr);

    expect(ajaxPrime_addr).to.equal(ajaxPrime.address);
    expect(await jaxAdmin.userIsAjaxPrime(ajaxPrime.address)).to.equal(true);
    expect(await jaxAdmin.userIsAjaxPrime(admin.address)).to.equal(false);
  });


  it("set_system_policy, set_readme, set_governor_policy", async function () {

    const policy_hash = "asdfasdfsdfdf";
    const policy_link = "http://testtest.test";
    await jaxAdmin.set_system_policy(policy_hash, policy_link);
    expect(await jaxAdmin.system_policy_hash()).to.equal(policy_hash);
    expect(await jaxAdmin.system_policy_link()).to.equal(policy_link);
    
    // set readme
    const readme_hash = "asdfasdfsdfdf";
    const readme_link = "http://testtest.test";
    await jaxAdmin.set_readme(readme_hash, readme_link);
    expect(await jaxAdmin.readme_hash()).to.equal(readme_hash);
    expect(await jaxAdmin.readme_link()).to.equal(readme_link);
    
    // set readme
    const governor_policy_hash = "asdfasdfsdfdf";
    const governor_policy_link = "http://testtest.test";
    await jaxAdmin.set_governor_policy(governor_policy_hash, governor_policy_link);
    expect(await jaxAdmin.governor_policy_hash()).to.equal(governor_policy_hash);
    expect(await jaxAdmin.governor_policy_link()).to.equal(governor_policy_link);
    
  });

  it("set operators", async () => {
    await jaxAdmin.setOperators([operator1.address, operator2.address, operator3.address]);
    expect(await jaxAdmin.operators(0)).to.equal(operator1.address);
    await expect(jaxAdmin.connect(ajaxPrime).set_wjxn_usd_ratio(100)).to.eventually
      .be.rejectedWith(Error, "VM Exception while processing transaction: reverted with reason string 'Only operators can perform this operation'");
    await jaxAdmin.connect(operator3).set_wjxn_usd_ratio(100)
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
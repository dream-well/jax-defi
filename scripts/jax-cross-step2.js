const util = require('util');
const { ethers, upgrades } = require("hardhat");
const timer = util.promisify(setTimeout)
const pancakeRouterAddr = "0x10ED43C718714eb63d5aA57B78B54704E256024E"; // binance smart chain mainnet
const BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
const WJXN = "0xcA1262e77Fb25c0a4112CFc9bad3ff54F617f2e6";

async function wait(start) {
  let elapsed = (new Date).getTime() - start;
  if(elapsed > 600000) return;
  await timer(600000 - elapsed);
}

void async function main() {

  const [owner] = await ethers.getSigners();
  console.log("deployer:", owner.address);
  let vrp;
  let jaxAdmin;
  let jaxSwap;
  let wjxn;
  let wjax;
  let jusd;
  let jinr;
  let busd;
  let pancakeRouter;
  let factory;
  let weth;
  let txFeeWallet;
  let ubiTaxWallet;
  let ubi;
  let lpYield;
  let jaxPlanet;
  let haber;

  async function attachPancakeRouter() {
    const PancakeRouter = await ethers.getContractFactory("PancakeRouter"); 
    pancakeRouter = await PancakeRouter.attach(pancakeRouterAddr);
    const PancakeFactory = await ethers.getContractFactory("PancakeFactory");
    factory = await PancakeFactory.attach(await pancakeRouter.factory());
    const WETH = await ethers.getContractFactory("WETH");
    weth = await WETH.attach(await pancakeRouter.WETH());
  }

  async function deployPancakeRouter() {
    const [owner] = await ethers.getSigners();
    const PancakeFactory = await ethers.getContractFactory("PancakeFactory");
    factory = await PancakeFactory.deploy(owner.address);
    const WETH = await ethers.getContractFactory("WETH");
    weth = await WETH.deploy();
    await weth.deployed();
    const PancakeRouter = await ethers.getContractFactory("PancakeRouter"); 
    pancakeRouter = await PancakeRouter.deploy(factory.address, weth.address);
  }

  async function deployJaxAdmin() {
    const JaxAdmin = await ethers.getContractFactory("JaxAdmin"); 
    jaxAdmin = await upgrades.deployProxy(JaxAdmin, [pancakeRouter.address], { initializer: 'initialize' });
    await jaxAdmin.deployed();
    await timer(10000);
  }

  async function deployTokens() {
// Tokens
    const JAXUD = await ethers.getContractFactory("JAXUD");
    const JAXRE = await ethers.getContractFactory("JAXRE");
    const WJAX = await ethers.getContractFactory("WJAX");
    const VRP = await ethers.getContractFactory("VRP");
    const Haber = await ethers.getContractFactory("HaberStornetta");

    busd = await ethers.getContractAt("CommonBEP20", BUSD);
    wjxn = await ethers.getContractAt("CommonBEP20", WJXN);
    wjax = await WJAX.deploy("Wrapped Jax", "WJAX", 4);
    await wjax.deployed();
    jusd = await JAXUD.deploy();
    await jusd.deployed();
    console.log("jusd");
    await timer(3000);
    // vrp = await upgrades.deployProxy(VRP, [jaxAdmin.address], { initializer: 'initialize' });
    // await vrp.deployed();
    jinr = await JAXRE.deploy();
    
    await jinr.deployed();
    await timer(3000);
    // haber = await Haber.deploy(wjxn.address);
    // await haber.deployed();

    console.log("setJaxAdmin");
    await timer(10000);

    // await wjax.setJaxAdmin(jaxAdmin.address);
    // await jusd.setJaxAdmin(jaxAdmin.address);
    // await vrp.setJaxAdmin(jaxAdmin.address);
    // await jinr.setJaxAdmin(jaxAdmin.address);
    // await wait();

    // await wjax.setJaxAdmin(jaxAdmin.address);
    // await jusd.setJaxAdmin(jaxAdmin.address);
    // await vrp.setJaxAdmin(jaxAdmin.address);
    // await jinr.setJaxAdmin(jaxAdmin.address);


    
  }

  async function deployJaxSwap() {
    
    await timer(10000);
    const JaxSwap = await ethers.getContractFactory("JaxSwap");
    jaxSwap = await upgrades.deployProxy(JaxSwap, [jaxAdmin.address, pancakeRouter.address], { initializer: 'initialize' });
    await jaxSwap.deployed();
    console.log("JaxSwap");
    await timer(10000);
    await jaxAdmin.setJaxSwap(jaxSwap.address);
    await timer(10000);

    console.log("setJaxSwap");
    // await wjax.setJaxSwap(owner.address);
    // await jaxAdmin.setJaxSwap(jaxSwap.address);
    
    await jaxAdmin.setTokenAddresses(busd.address, wjxn.address, wjax.address, "0x000000000000000000000000000000000000dEaD", jusd.address);

    console.log("setTokenAddresses");
    await timer(10000);



  }

  async function createLiquidity() {

    // https://pancake.kiemtienonline360.com/

    try{
      await factory.createPair(wjxn.address, wjax.address);
      await timer(10000);
      await factory.createPair(busd.address, wjax.address);
      await timer(10000);
      await factory.createPair(busd.address, wjxn.address);
      console.log("wjxn/wjax", await factory.getPair(wjxn.address, wjax.address));
      console.log("busd/wjax", await factory.getPair(busd.address, wjax.address));
      console.log("busd/wjxn", await factory.getPair(busd.address, wjxn.address));
    }catch(e) {
      console.log("liquidity error");
    }
    
    await timer(10000);
  }

  async function deployYields() {
    console.log("deploying yields ...")
    const TxFeeWallet = await ethers.getContractFactory("TxFeeWallet"); 
    const UbiTaxWallet = await ethers.getContractFactory("UbiTaxWallet"); 

    console.log("1...")
    const LpYield = await ethers.getContractFactory("LpYield");
    txFeeWallet = await upgrades.deployProxy(TxFeeWallet, 
        [jaxAdmin.address, pancakeRouter.address, wjxn.address], 
        { initializer: 'initialize' });
    await txFeeWallet.deployed();
    await timer(10000);
    console.log("2...")
    ubiTaxWallet = await upgrades.deployProxy(UbiTaxWallet, 
        [jaxAdmin.address, pancakeRouter.address, wjax.address], { initializer: 'initialize' });
    await ubiTaxWallet.deployed();
    await timer(10000);
    console.log("3...")
    // lpYield = await upgrades.deployProxy(LpYield, 
    //     [jaxAdmin.address, pancakeRouter.address, busd.address, wjax.address], { initializer: 'initialize' })
    // await lpYield.deployed(); 
    // await lpYield.set_reward_token(wjax.address);
  }

  async function deployJaxPlanet() {
    const JaxPlanet = await ethers.getContractFactory("JaxPlanet");
    jaxPlanet = await upgrades.deployProxy(JaxPlanet, [jaxAdmin.address], { initializer: 'initialize'});
    await jaxPlanet.deployed();
    await jaxAdmin.setJaxPlanet(jaxPlanet.address);
    await timer(10000);
    
  }

  async function deployUbi() {

    const Ubi = await ethers.getContractFactory("Ubi");
    ubi = await upgrades.deployProxy(Ubi, 
        [owner.address, wjax.address, 300], 
        { initializer: 'initialize' });
    // await ubi.deployed();
  }

  console.log("BNB Balance: ", await ethers.provider.getBalance(owner.address));
  console.log("Deploying Jax Contracts");

  if(ethers.provider.network.chainId == 31337) //if hardhat
    await deployPancakeRouter();
  else 
    await attachPancakeRouter();
  // await deployJaxAdmin();
  // console.log("deployJaxAdmin");
  // await deployJaxPlanet();
  // console.log("deployJaxPlanet");
  // await deployTokens();
  // console.log("deployTokens");
  // await deployJaxSwap();
  // console.log("deployJaxSwap");
  // await createLiquidity();
  // console.log("createLiquidity");
  jaxAdmin = { address: "" };
  wjxn = {address: ""};
  wjax = {address: ""};
  await deployYields();
  console.log("deployYields");
  // await deployUbi();
  // console.log("deployUBI");
  
  
  const addresses = {
    busd: busd?.address,
    wjxn: wjxn?.address,
    wjax: wjax?.address,
    vrp: vrp?.address,
    jusd: jusd?.address,
    jinr: jinr?.address,
    haber: haber?.address,
    jaxAdmin: jaxAdmin?.address,
    jaxSwap: jaxSwap?.address,
    jaxPlanet: jaxPlanet?.address,
    txFeeWallet: txFeeWallet?.address,
    ubiTaxWallet: ubiTaxWallet?.address,
    ubi: ubi?.address,
    lpYield: lpYield?.address
  }

  console.log(addresses);

  console.log("Current BNB Balance: ", await ethers.provider.getBalance(owner.address));

  console.log("wait for cooling");
  // await wait(start);
  async function set() {

    await jaxAdmin.setJaxSwap(jaxSwap.address);
    await jaxAdmin.setTokenAddresses(busd.address, wjxn.address, wjax.address, vrp.address, jusd.address); 
    await jaxAdmin.setJaxPlanet(jaxPlanet.address);

  }
  // await set();
  console.log("set");
}();
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
    const PancakeRouter = await ethers.getContractFactory("PancakeRouter"); 
    pancakeRouter = await PancakeRouter.deploy(factory.address, weth.address);
  }

  async function deployJaxAdmin() {
    const JaxAdmin = await ethers.getContractFactory("JaxAdmin"); 
    jaxAdmin = await upgrades.deployProxy(JaxAdmin, [pancakeRouter.address], { initializer: 'initialize' });
  }

  async function deployTokens() {
// Tokens
    const JaxToken = await ethers.getContractFactory("JaxToken");
    const WJAX = await ethers.getContractFactory("WJAX");
    const VRP = await ethers.getContractFactory("VRP");
    const Haber = await ethers.getContractFactory("HaberStornetta");

    busd = await ethers.getContractAt("CommonBEP20", BUSD);
    wjxn = await ethers.getContractAt("CommonBEP20", WJXN);
    wjax = await WJAX.deploy("Wrapped Jax", "WJAX", 4);
    jusd = await JaxToken.deploy("Jax Dollar", "JAX DOLLAR", 18);
    vrp = await upgrades.deployProxy(VRP, [jaxAdmin.address], { initializer: 'initialize' });
    jinr = await JaxToken.deploy("Jax Rupee", "JAX RUPEE", 18);
    haber = await Haber.deploy(wjxn.address);

    console.log("setJaxAdmin");

    // await wjax.setJaxAdmin(jaxAdmin.address);
    // await jusd.setJaxAdmin(jaxAdmin.address);
    await vrp.setJaxAdmin(jaxAdmin.address);
    // await jinr.setJaxAdmin(jaxAdmin.address);

    // await wait();

    // await wjax.setJaxAdmin(jaxAdmin.address);
    // await jusd.setJaxAdmin(jaxAdmin.address);
    // await vrp.setJaxAdmin(jaxAdmin.address);
    // await jinr.setJaxAdmin(jaxAdmin.address);


    
  }

  async function deployJaxSwap() {
    
    const JaxSwap = await ethers.getContractFactory("JaxSwap");
    jaxSwap = await upgrades.deployProxy(JaxSwap, [jaxAdmin.address, pancakeRouter.address], { initializer: 'initialize' });
    await jaxSwap.deployed();
    console.log("JaxSwap");
    await jaxAdmin.setJaxSwap(jaxSwap.address);

    console.log("setJaxSwap");
    // await wjax.setJaxSwap(owner.address);

    // await busd.mint(owner.address, ethers.utils.parseUnits("100000000000", 18));
    console.log("busd mint");
    // await wjax.setGateKeepers([owner.address]);
    // console.log("gatekeeper");
    // await wait();

    // console.log("setGateKeepers");
    // await wjax.setGateKeepers([owner.address]);

    // let amount = ethers.utils.parseUnits("10000000000000", 4);
    // await wjax.setMintBurnLimit(owner.address, amount, amount);
    // await wait();

    
    // await wjax.setMintBurnLimit(owner.address, amount, amount);
    
    // await wjxn.mint(owner.address, "36000000");
    console.log("wjxn mint")
    // await wjax.mint(owner.address, amount);
    // console.log("wjax mint");
    

    console.log("mint");
    // await jaxAdmin.setJaxSwap(jaxSwap.address);

    console.log("setJaxSwap ---- end");
    await jaxAdmin.setTokenAddresses(busd.address, wjxn.address, wjax.address, vrp.address, jusd.address);

    console.log("setTokenAddresses");



  }

  async function createLiquidity() {

    // https://pancake.kiemtienonline360.com/

    try{
      await factory.createPair(wjxn.address, wjax.address);
      await factory.createPair(busd.address, wjax.address);
      await factory.createPair(busd.address, wjxn.address);
      console.log("wjxn/wjax", await factory.getPair(wjxn.address, wjax.address));
      console.log("busd/wjax", await factory.getPair(busd.address, wjax.address));
      console.log("busd/wjxn", await factory.getPair(busd.address, wjxn.address));
    }catch(e) {
      console.log("liquidity error");
    }
    
  }

  async function deployYields() {
    console.log("deploying yields ...")
    const TxFeeWallet = await ethers.getContractFactory("TxFeeWallet"); 
    const UbiTaxWallet = await ethers.getContractFactory("UbiTaxWallet"); 

    const LpYield = await ethers.getContractFactory("LpYield");
    txFeeWallet = await upgrades.deployProxy(TxFeeWallet, 
        [jaxAdmin.address, pancakeRouter.address, wjxn.address], 
        { initializer: 'initialize' });
    ubiTaxWallet = await upgrades.deployProxy(UbiTaxWallet, 
        [jaxAdmin.address, pancakeRouter.address, wjax.address], { initializer: 'initialize' });
    lpYield = await upgrades.deployProxy(LpYield, 
        [jaxAdmin.address, pancakeRouter.address, busd.address, wjax.address], { initializer: 'initialize' })
    // await lpYield.set_reward_token(wjax.address);
  }

  async function deployJaxPlanet() {
    const JaxPlanet = await ethers.getContractFactory("JaxPlanet");
    jaxPlanet = await upgrades.deployProxy(JaxPlanet, [jaxAdmin.address], { initializer: 'initialize'});
    await jaxAdmin.setJaxPlanet(jaxPlanet.address);
    
  }

  async function deployUbi() {

    const Ubi = await ethers.getContractFactory("Ubi");
    ubi = await upgrades.deployProxy(Ubi, 
        [owner.address, wjax.address, 300], 
        { initializer: 'initialize' });
  }

  console.log("BNB Balance: ", await ethers.provider.getBalance(owner.address));
  console.log("Deploying Jax Contracts");

  if(ethers.provider.network.chainId == 31337) //if hardhat
    await deployPancakeRouter();
  else 
    await attachPancakeRouter();
  await deployJaxAdmin();
  console.log("deployJaxAdmin");
  await deployJaxPlanet();
  console.log("deployJaxPlanet");
  await deployTokens();
  console.log("deployTokens");
  await deployJaxSwap();
  let start= (new Date()).getTime();
  console.log("deployJaxSwap");
  await createLiquidity();
  console.log("createLiquidity");
  await deployYields();
  console.log("deployYields");
  await deployUbi();
  console.log("deployUBI");
  
  
  const addresses = {
    busd: busd.address,
    wjxn: wjxn.address,
    wjax: wjax.address,
    vrp: vrp.address,
    jusd: jusd.address,
    jinr: jinr.address,
    haber: haber.address,
    jaxAdmin: jaxAdmin.address,
    jaxSwap: jaxSwap.address,
    jaxPlanet: jaxPlanet.address,
    txFeeWallet: txFeeWallet.address,
    ubiTaxWallet: ubiTaxWallet.address,
    ubi: ubi.address,
    lpYield: lpYield.address
  }

  console.log(addresses);

  console.log("Current BNB Balance: ", await ethers.provider.getBalance(owner.address));

  console.log("wait for cooling");
  // await wait(start);
  async function set() {

    await wjax.setJaxAdmin(jaxAdmin.address);
    await jusd.setJaxAdmin(jaxAdmin.address);
    await vrp.setJaxAdmin(jaxAdmin.address);
    await jinr.setJaxAdmin(jaxAdmin.address);

    await jaxAdmin.setJaxSwap(jaxSwap.address);
    await jaxAdmin.setTokenAddresses(busd.address, wjxn.address, wjax.address, vrp.address, jusd.address); 
    await jaxAdmin.setJaxPlanet(jaxPlanet.address);

  }
  // await set();
  console.log("set");
}();
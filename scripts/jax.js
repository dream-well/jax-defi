const util = require('util');
const { ethers, upgrades } = require("hardhat");
const timer = util.promisify(setTimeout)
const pancakeRouterAddr = "0x9ac64cc6e4415144c455bd8e4837fea55603e5c3"; // binance smart chain mainnet

async function wait() {
  await timer(6100);
}

void async function main() {

  const [owner] = await ethers.getSigners();
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
    const ERC20 = await ethers.getContractFactory("CommonBEP20");
    const JaxToken = await ethers.getContractFactory("JaxToken");
    const WJAX = await ethers.getContractFactory("WJAX");
    const VRP = await ethers.getContractFactory("VRP");

    busd = await ERC20.deploy("Pegged USD Binance", "BUSD", 18);
    wjxn = await ERC20.deploy("Wrapped Jaxnet", "WJXN", 0);
    wjax = await WJAX.deploy("Wrapped Jax", "WJAX", 4);
    jusd = await JaxToken.deploy("Jax Dollar", "JAX DOLLAR", 18);
    vrp = await upgrades.deployProxy(VRP, [jaxAdmin.address], { initializer: 'initialize' });;
    jinr = await JaxToken.deploy("Jax Rupee", "JAX RUPEE", 18);

    await wjax.setJaxAdmin(jaxAdmin.address);
    await jusd.setJaxAdmin(jaxAdmin.address);
    await vrp.setJaxAdmin(jaxAdmin.address);
    await jinr.setJaxAdmin(jaxAdmin.address);

    await wait();

    await wjax.setJaxAdmin(jaxAdmin.address);
    await jusd.setJaxAdmin(jaxAdmin.address);
    await vrp.setJaxAdmin(jaxAdmin.address);
    await jinr.setJaxAdmin(jaxAdmin.address);


    
  }

  async function deployJaxSwap() {
    
    const JaxSwap = await ethers.getContractFactory("JaxSwap");
    jaxSwap = await upgrades.deployProxy(JaxSwap, [jaxAdmin.address, pancakeRouter.address], { initializer: 'initialize' });
    await jaxSwap.deployed();
    console.log("JaxSwap");
    await jaxAdmin.setJaxSwap(jaxSwap.address);
    await wait();
    await jaxAdmin.setJaxSwap(jaxSwap.address);

    console.log("setJaxSwap");
    // await wjax.setJaxSwap(owner.address);

    await busd.mint(owner.address, ethers.utils.parseUnits("10000000000000", 18));
    console.log("busd mint");
    await wjax.setGateKeepers([owner.address]);
    console.log("gatekeeper");

    let amount = ethers.utils.parseUnits("10000000000000", 4);
    await wjax.setMintBurnLimit(owner.address, amount, amount);
    
    await wjxn.mint(owner.address, "10000000000000");
    console.log("wjxn mint")
    await wjax.mint(owner.address, amount);
    console.log("wjax mint");
    

    console.log("mint");
    // await jaxAdmin.setJaxSwap(jaxSwap.address);

    console.log("setJaxSwap ---- end");
    await jaxAdmin.setTokenAddresses(busd.address, wjxn.address, wjax.address, vrp.address, jusd.address);

    console.log("setTokenAddresses");

    await wait();

    console.log("setGateKeepers");
    await wjax.setGateKeepers([owner.address]);
    await wjax.setMintBurnLimit(owner.address, amount, amount);
    await jaxAdmin.setTokenAddresses(busd.address, wjxn.address, wjax.address, vrp.address, jusd.address);

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
    jaxAdmin.setJaxPlanet(jaxPlanet.address);
    await wait();
    jaxAdmin.setJaxPlanet(jaxPlanet.address);
    
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
  await deployTokens();
  console.log("deployTokens");
  await deployJaxSwap();
  console.log("deployJaxSwap");
  await createLiquidity();
  console.log("createLiquidity");
  await deployYields();
  console.log("deployYields");
  await deployJaxPlanet();
  console.log("deployJaxPlanet");
  await deployUbi();
  console.log("deployUBI");
  
  const addresses = {
    busd: busd.address,
    wjxn: wjxn.address,
    wjax: wjax.address,
    vrp: vrp.address,
    jusd: jusd.address,
    jinr: jinr.address,
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
}();
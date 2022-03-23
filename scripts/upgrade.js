
async function deployUbi() {
    const [owner] = await ethers.getSigners();
    const Ubi = await ethers.getContractFactory("Ubi");
    const UbiTaxWallet = await ethers.getContractFactory("UbiTaxWallet");
    const TxFeeWallet = await ethers.getContractFactory("TxFeeWallet");
    // ubi = await upgrades.upgradeProxy("0x6d4ad1d14fb5e307d0e4c215c11c6c62ec0f435f", Ubi);
    ubi = await upgrades.upgradeProxy("0xdb44854D1be1546a9D9D2eC1B623F43252de23C1", UbiTaxWallet);
    ubi = await upgrades.upgradeProxy("0x43b81c52f93e92EbE23E1d519235A88fF4C05343", TxFeeWallet);
  }


  async function deployYields() {
    console.log("deploying yields ...")
    const TxFeeWallet = await ethers.getContractFactory("TxFeeWallet"); 
    const UbiTaxWallet = await ethers.getContractFactory("UbiTaxWallet"); 

    let jaxAdmin = "0x363020361AFFC424166248159DcAe59FF7621343";
    let pancakeRouter = "0x9ac64cc6e4415144c455bd8e4837fea55603e5c3";
    let wjxn = "0xD576C53A43Aed9EDF97e134DcE7B9Cdc328B7429";
    let wjax = "0xCeAb7e9BF15E6Ca847C17E6bd35be30a033c916D";
    txFeeWallet = await upgrades.deployProxy(TxFeeWallet, 
        [jaxAdmin, pancakeRouter, wjxn], 
        { initializer: 'initialize' });
    ubiTaxWallet = await upgrades.deployProxy(UbiTaxWallet, 
        [jaxAdmin, pancakeRouter, wjax], { initializer: 'initialize' });
    // await lpYield.set_reward_token(wjax.address);
    console.log("ubiTaxWallet", ubiTaxWallet.address);
    console.log("txFeeWallet", txFeeWallet.address);
  }

  // deployUbi();
  deployYields();
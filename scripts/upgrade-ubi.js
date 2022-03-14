const {ethers, upgrades} = require('hardhat');

async function main() {
    const [owner] = await ethers.getSigners();
    console.log(owner.address);
    const Contract = await ethers.getContractFactory("Ubi");
    // const contract = await upgrades.forceImport("0xd1e91cbb6bb5f5abffc475cbb7d67e180abc0e38", Contract, {});
    const addr = await Contract.deploy();
    console.log(addr.address);
    await upgrades.prepareUpgrade('0xd1e91cbb6bb5f5abffc475cbb7d67e180abc0e38', Contract);
    const contract = await upgrades.upgradeProxy('0xd1e91cbb6bb5f5abffc475cbb7d67e180abc0e38', Contract);
    console.log("Box upgraded", contract.address);
  }
  
  main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
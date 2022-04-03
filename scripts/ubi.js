
const WJAX = '';
const LOCKTIME = 100 * 365 * 24 * 3600;

async function deployUbi() {
    const [owner] = await ethers.getSigners();
    const Ubi = await ethers.getContractFactory("Ubi");
    ubi = await upgrades.deployProxy(Ubi, 
        [owner.address, WJAX, LOCKTIME], 
        { initializer: 'initialize' });
  }

  deployUbi();
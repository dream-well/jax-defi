
async function deployUbi() {
    const [owner] = await ethers.getSigners();
    const Ubi = await ethers.getContractFactory("Ubi");
    ubi = await upgrades.deployProxy(Ubi, 
        [owner.address, '0xCeAb7e9BF15E6Ca847C17E6bd35be30a033c916D', 300], 
        { initializer: 'initialize' });
  }

  deployUbi();
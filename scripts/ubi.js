
async function deployUbi() {
    const [owner] = await ethers.getSigners();
    const Ubi = await ethers.getContractFactory("Ubi");
    ubi = await upgrades.deployProxy(Ubi, 
        [owner.address, '0x757f9226d11400d3ecd9D221b3288d6405Fb6e0b', 300], 
        { initializer: 'initialize' });
  }

  deployUbi();
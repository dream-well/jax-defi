
async function deployUbi() {
    const [owner] = await ethers.getSigners();
    const Haber = await ethers.getContractFactory("HaberStornetta");
    haber = await Haber.deploy("0xD04e9e6f243bD71a286D2A6585599165449cFA88");
    console.log(haber.address);

  }

  deployUbi();
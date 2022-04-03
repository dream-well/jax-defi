
async function deployJAXUD() {
    const [owner] = await ethers.getSigners();
    const JAXUD = await ethers.getContractFactory("JAXUD");
    const jaxud = await JAXUD.deploy();
    await jaxud.deployed();
    const JAXRE = await ethers.getContractFactory("JAXRE");
    const jaxre = await JAXRE.deploy();
    await jaxre.deployed();
    console.log({jaxud: jaxud.address, jaxre: jaxre.address});
  }

  deployJAXUD();
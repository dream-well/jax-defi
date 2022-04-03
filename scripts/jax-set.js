
let addresses = {
    jaxAdmin: "",
    jaxSwap: "",
    jaxPlanet: "",
    busd: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
    wjxn: "0xcA1262e77Fb25c0a4112CFc9bad3ff54F617f2e6",
    wjax: "",
    vrp: "",
    jusd: ""
}

  // await wait(start);
  async function set() {

    await wjax.setJaxAdmin(addresses.jaxAdmin);
    await jusd.setJaxAdmin(addresses.jaxAdmin);
    await vrp.setJaxAdmin(addresses.jaxAdmin);
    await jinr.setJaxAdmin(addresses.jaxAdmin);

    await jaxAdmin.setJaxSwap(addresses.jaxSwap);
    await jaxAdmin.setTokenAddresses(addresses.busd, addresses.wjxn, addresses.wjax, addresses.vrp, addresses.jusd); 
    await jaxAdmin.setJaxPlanet(addresses.jaxPlanet);

  }
  
  set();
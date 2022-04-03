
async function main() {

    const [owner] = await ethers.getSigners();
    console.log(await owner.getTransactionCount());
    const JaxAdmin = await ethers.getContractFactory("JaxAdmin");
   
    console.log("Transferring ownership of ProxyAdmin...");       // The owner of the ProxyAdmin can upgrade our contracts
    await upgrades.prepareUpgrade("0xefDd82E6CF1fB36660303b169A864792A8ee4d8E", JaxAdmin);
    // console.log("Transferred ownership of ProxyAdmin to:", newOwnerOfTheProxyAdmin);
   
    // console.log(await owner.getTransactionCount());
    }

main()
.then(() => process.exit(0))
.catch(error => {
    console.error(error);
    process.exit(1);
});
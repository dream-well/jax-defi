
async function main() {

    const [owner] = await ethers.getSigners();
    console.log(await owner.getTransactionCount());
    const newOwnerOfTheProxyAdmin = '0x67dF2b0B99898EA7CeeEEE5d443D86e59f6663C1';   // this will be the address of the TimeLock, as we need it to be the owner of the Proxy Admin.
   
    console.log("Transferring ownership of ProxyAdmin...");       // The owner of the ProxyAdmin can upgrade our contracts
    await upgrades.admin.transferProxyAdminOwnership(newOwnerOfTheProxyAdmin);
    console.log("Transferred ownership of ProxyAdmin to:", newOwnerOfTheProxyAdmin);
   
    console.log(await owner.getTransactionCount());
    }

main()
.then(() => process.exit(0))
.catch(error => {
    console.error(error);
    process.exit(1);
});
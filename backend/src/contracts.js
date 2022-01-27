import addresses from '../addresses.js'
import fs from 'fs-extra'

export const wjxn = addresses.wjxn;
export const wjax = addresses.wjax;
// export const vrp = addresses.vrp;
export const jusd = addresses.jusd;
export const jinr = addresses.jinr;
export const busd = addresses.busd;

export const vrp = {
    address: addresses.vrp,
    abi: fs.readJsonSync("../abi/contracts/lib/VRP.sol/VRP.json")
}

export const JaxAdmin = {
    address: addresses.jaxAdmin,
    abi: fs.readJsonSync("../abi/contracts/JaxAdmin.sol/JaxAdmin.json")
}

export const JaxSwap = {
    address: addresses.jaxSwap,
    abi: fs.readJsonSync("../abi/contracts/JaxSwap.sol/JaxSwap.json")
}

export const LpYield = {
    address: addresses.lpYield,
    abi: fs.readJsonSync("../abi/contracts/yield/LpYield.sol/LpYield.json")
}

export const Ubi = {
    address: addresses.ubi,
    abi: fs.readJsonSync("../abi/contracts/yield/Ubi.sol/Ubi.json")
}

export const JaxBridgeBsc = {
    address: addresses.jaxBridgeBsc,
    abi: fs.readJsonSync("../abi/contracts/bridge/JaxBridge.sol/JaxBridge.json")
}

export const JaxBridgePolygon = {
    address: addresses.jaxBridgePolygon,
    abi: fs.readJsonSync("../abi/contracts/bridge/JaxBridge.sol/JaxBridge.json")
}

export const JaxToken = fs.readJsonSync("../abi/contracts/JaxToken.sol/JaxToken.json");

export const PancakeFactory = {
    address: addresses.pancakeFactory,
    abi: fs.readJsonSync("../abi/contracts/ref/PancakeFactory.sol/PancakeFactory.json")
}

export const PancakeRouter = {
    address: addresses.pancakeRouter,
    abi: fs.readJsonSync("../abi/contracts/ref/PancakeRouter.sol/IPancakeRouter01.json")
}

export const PancakePair_ABI = fs.readJsonSync("../abi/contracts/ref/PancakeRouter.sol/IPancakePair.json");
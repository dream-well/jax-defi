import Web3 from 'like-web3';
import { JaxAdmin, JaxSwap, LpYield, PancakeFactory, PancakePair_ABI, PancakeRouter, Ubi } from './contracts.js';
import { wjax, vrp, jusd, jinr, busd, wjxn } from './contracts.js';
import { JaxToken } from './contracts.js';
import fs from 'fs-extra'

const privateKey = fs.readJsonSync("../../secrets.json").deployerWalletPrivateKey;

const providers = {
  "bsctestnet": {
    // providers: ['https://bsc-dataseed.binance.org', 'wss://bsc-ws-node.nariox.org:443'],
    // providers: ['https://data-seed-prebsc-2-s3.binance.org:8545'],
    providers: ['https://speedy-nodes-nyc.moralis.io/63021305c6423bed5d079c57/bsc/testnet'],
    testnet: true,
    privateKey
  },
  "polygontestnet": {
    // providers: ['https://bsc-dataseed.binance.org', 'wss://bsc-ws-node.nariox.org:443'],
    providers: [`https://rpc-mumbai.maticvigil.com/`],
    testnet: true,
    privateKey
  },
  "polygonmainnet": {
    // providers: ['https://bsc-dataseed.binance.org', 'wss://bsc-ws-node.nariox.org:443'],
    providers: [`https://rpc-mainnet.maticvigil.com/`],
    // testnet: true,
    privateKey
  },
  avalancheTestnet: {
    providers: ['https://api.avax-test.network/ext/bc/C/rpc'],
    testnet: true,
    privateKey
  },
}

const web3 = new Web3(providers.bsctestnet);

Web3.addContract({ JaxAdmin });
Web3.addContract({ JaxSwap });
Web3.addContract({ LpYield, Ubi });
Web3.addContract({
  wjxn: {
    address: wjxn,
    abi: JaxToken
  },
  wjax: {
    address: wjax,
    abi: JaxToken
  },
  vrp,
  jusd: {
    address: jusd,
    abi: JaxToken
  },
  jinr: {
    address: jinr,
    abi: JaxToken
  },
})

Web3.addContract({
  PancakeFactory
})

Web3.addContract({
  PancakeRouter
})

console.log("pair", await web3.contract("PancakeFactory").getPair(wjax, busd));


Web3.addContract({
  Busd_Wjax_Pair: {
    address: await web3.contract("PancakeFactory").getPair(wjax, busd),
    abi: PancakePair_ABI
  }
})


// Web3.addContract({ JaxBridge });

export default web3;
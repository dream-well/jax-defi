import Router from 'express'
import { get_busd_deposit_range, get_exchange_rate } from './controller.js';
import { get_reserves } from './controller.js';
import { get_fees } from './controller.js';
import { get_exchange_rates_busd } from './controller.js';
import { get_exchange_rates } from './controller.js';
import { get_dex_rates } from './controller.js';
import { get_locked_token_info } from './controller.js';
import { get_total_busd_staked } from './controller.js';
import { get_total_vrp_staked } from './controller.js';
import { get_statistics } from './controller.js';
import { get_apy } from './controller.js';
import addresses from '../addresses.js';
import { JaxAdmin, JaxBridgeBsc, JaxBridgePolygon, JaxSwap, LpYield, Ubi, vrp } from './contracts.js';

const router = Router()

export default router
    .get('/exchange_rate', async (req, resp) => {
        const {token1, token2} = req.query;
        const rate = await get_exchange_rate(token1, token2);
        resp.send({rate})
    })
    .get('/exchange_rates', async (req, resp) => {
        const rates = get_exchange_rates();
        resp.send(rates);
    })
    .get('/dex_rates', async (req, resp) => {
        const rates = await get_dex_rates();
        resp.send(rates);
    })
    .get('/reserves', async (req, resp) => {
        const reserves = await get_reserves();
        resp.send(reserves);
    })
    .get('/fees', async (req, resp) => {
        const fees = await get_fees();
        resp.send(fees);
    })
    .get("/contract_addresses", (req, resp) => {
        let contracts = {...addresses};
        Object.keys(addresses).forEach(key => {
            contracts[key] = {
                address: addresses[key],
            }
        })
        contracts.jaxAdmin = JaxAdmin;
        contracts.jaxSwap = JaxSwap;
        contracts.lpYield = LpYield;
        contracts.ubi = Ubi;
        contracts.vrp = vrp;
        contracts.jaxBridgeBsc = JaxBridgeBsc;
        contracts.jaxBridgePolygon = JaxBridgePolygon;
        resp.send(contracts);
    })
    .get("/locked_tokens", (req, resp) => {
        const locked_tokens = get_locked_token_info();
        resp.send(locked_tokens);
    })
    .get("/total_staked", async (req, resp) => {
        const totalBusdStaked = await get_total_busd_staked();
        const totalVrpStaked = await get_total_vrp_staked();
        resp.send({ totalBusdStaked, totalVrpStaked });
    })
    .get("/statistics", async (req, resp) => {
        const statistics = await get_statistics();
        resp.send( statistics );
    })
    .get("/apy", async (req, resp) => {
        const apy = await get_apy();
        resp.send(apy);
    })
    .get("/busd_deposit_range", (req, resp) => {
        resp.send(get_busd_deposit_range());
    })
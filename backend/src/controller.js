import web3 from './web3.js';
import { JaxSwap, wjxn, busd, wjax, JaxAdmin, jinr, jusd } from './contracts.js';

const state = {
    reserves: {

    },
    lpYield: {

    }
}


const token0 = await web3.contract("Busd_Wjax_Pair").token0();
const { reserve0, reserve1 } = await web3.contract("Busd_Wjax_Pair").getReserves();

let reserve_busd = reserve0;

if( token0 == wjax ) {
  reserve_busd = reserve1;
}


export const get_exchange_rates = () => {
    return state.rates;
}

export const get_exchange_rate = async (token1, token2) => {
    const method = `get_${token1}_${token2}_ratio`;
    console.log(method);
    let rate = await web3.contract('JaxAdmin')[method]();
    rate = web3.fromWei(rate, 8);
    if( token1 == 'jusd' || token2 == "jusd") {
        const other_token = token1 == "jusd" ? token2 : token1;
        let method = `${other_token}_jusd_markup_fee`;
        if( other_token == 'wjax' )
            method = `wjax_jusd_markup_fee`;
        let markup_fee = await web3.contract('JaxAdmin')[method]()
        markup_fee = web3.fromWei( markup_fee, 8 );
        rate = ( 1 - markup_fee ) * rate;
    }
    console.log(token1, token2, rate);
    return rate;
}

export const get_dex_rates = async () => {
    const jaxAdmin = web3.contract('JaxAdmin');
    const lpYield = web3.contract('LpYield');
    let [
        wjxn_busd,
        wjxn_vrp,
        wjax_busd,
        wjax_jusd,
        {
            jusd_ratio: jusd_jinr
        }
    ] = await Promise.all([
        lpYield.getPrice(wjxn, busd),
        jaxAdmin.get_wjxn_vrp_ratio(),
        lpYield.getPrice(wjax, busd),
        jaxAdmin.get_wjax_jusd_ratio(),
        jaxAdmin.jtokens(jinr)
    ])
    wjxn_busd = web3.fromWei(wjxn_busd, 8);
    wjxn_vrp = web3.fromWei(wjxn_vrp, 8);
    wjax_busd = web3.fromWei(wjax_busd, 8);
    wjax_jusd = web3.fromWei(wjax_jusd, 8);
    jusd_jinr = web3.fromWei(jusd_jinr, 8);
    return {
        wjxn_busd, wjxn_vrp, wjax_busd, wjax_jusd, jusd_jinr
    }
}

export const get_exchange_rates_busd = async () => {
    const lpYield = web3.contract('LpYield');
    const jaxAdmin = web3.contract('JaxAdmin');
    let [wjax_busd, busd_wjax] = await Promise.all([
        lpYield.getPrice(wjax, busd),
        lpYield.getPrice(busd, wjax)
    ])
    let [
        wjax_jusd,
        wjax_jusd_markup_fee
    ] = await Promise.all([
        jaxAdmin.get_wjax_jusd_ratio(),
        jaxAdmin.wjax_jusd_markup_fee()
    ])
    let {
        jusd_ratio: jusd_jinr,
        markup_fee: jusd_jinr_markup_fee
    } = await jaxAdmin.jtokens(jinr);

    wjax_busd = web3.fromWei(wjax_busd, 8);
    busd_wjax = web3.fromWei(busd_wjax, 8);
    wjax_jusd = web3.fromWei(wjax_jusd, 8);
    wjax_jusd_markup_fee = web3.fromWei(wjax_jusd_markup_fee, 8);
    jusd_jinr = web3.fromWei(jusd_jinr, 8);
    jusd_jinr_markup_fee = web3.fromWei(jusd_jinr, 8);
    let wjax_buy = wjax_busd;
    let wjax_sell = wjax_busd;
    let jusd_buy = (1 / wjax_jusd) * wjax_busd * (1 - wjax_jusd_markup_fee);
    let jusd_sell = (1 / wjax_busd) * wjax_busd * (1 - wjax_jusd_markup_fee);
    let jinr_buy = (1 / jusd_jinr) * jusd_buy * ( 1- jusd_jinr_markup_fee);
    let jinr_sell = (1 / jusd_jinr) * jusd_sell * ( 1- jusd_jinr_markup_fee);
    return {
        wjax_buy: isNaN(wjax_buy) ? 0 : wjax_buy,
        wjax_sell: isNaN(wjax_sell) ? 0 : wjax_sell,
        jusd_buy: isNaN(jusd_buy) ? 0 : jusd_buy,
        jusd_sell: isNaN(jusd_sell) ? 0 : jusd_sell,
        jinr_buy: isNaN(jinr_buy) ? 0 : jinr_buy,
        jinr_sell: isNaN(jinr_sell) ? 0 : jinr_sell,
    };
}

export const get_reserves = async () => {
    return state.reserves;
}

export const get_locked_token_info = () => {
    return state.lockedTokenInfo;
}

export const get_fees = async () => {
    let results = await Promise.all([
        web3.contract("JaxAdmin").wjax_jusd_markup_fee(),
        web3.contract("JaxAdmin").jtokens(jinr),
        "0",
        web3.contract("wjax").transaction_fee(),
        web3.contract("jusd").transaction_fee(),
        web3.contract("jinr").transaction_fee(),
    ])
    console.log(results);
    results[1] = results[1].markup_fee;
    results = results.map( each => web3.fromWei(each, 8));
    const [
        wjax_jusd_markup_fee,
        jusd_jinr_markup_fee,
        vrp_tx_fee,
        wjax_tx_fee,
        jusd_tx_fee,
        jinrx_tx_fee
    ] = results;

    return {
        wjax_jusd_markup_fee,
        jusd_jinr_markup_fee,
        vrp_tx_fee,
        wjax_tx_fee,
        jusd_tx_fee,
        jinrx_tx_fee
    }
}


async function updateReserves() {
  const wjax_supply = await web3.contract("wjax").totalSupply();
  const { reserve0, reserve1 } = await web3.contract("Busd_Wjax_Pair").getReserves();
  let reserve_busd = reserve0;
  let reserve_wjax = reserve1;
  if( token0 == wjax ) {
    reserve_busd = reserve1;
    reserve_wjax = reserve0;
  }
  const _reserves = await web3.contract("JaxAdmin").show_reserves();
  const { 0: wjax_lsc_ratio, 1: wjax_usd_value, 2: lsc_usd_value }  = _reserves;
  // console.log(reserves);
  const wjxn_reserve = await web3.contract("wjxn").balanceOf(JaxSwap.address);
  const wjax_reserve = await web3.contract("wjax").balanceOf(JaxSwap.address);
  const wjxn_price = await web3.contract("JaxAdmin").get_wjxn_jusd_ratio();
  const wjax_price = await web3.contract("JaxAdmin").get_wjax_jusd_ratio();
  const wjax_collateral = await web3.contract("JaxAdmin").wjax_collateralization_ratio();
  const wjxn_collateral = await web3.contract("JaxAdmin").wjxn_wjax_collateralization_ratio();
  let reserves = {
    reserve_busd: web3.fromWei(reserve_busd, 18),
    wjax_supply: web3.fromWei(wjax_supply, 4),
    wjax_usd_value: web3.fromWei(wjax_usd_value, 18),
    lsc_usd_value: web3.fromWei(lsc_usd_value, 18),
    wjxn_usd_reserve: wjxn_reserve * web3.fromWei(wjxn_price, 8),
    wjax_usd_reserve: web3.fromWei(wjax_reserve, 4) * web3.fromWei(wjax_price, 8),
    wjax_collateral: web3.fromWei(wjax_collateral, 6),
    wjxn_collateral: web3.fromWei(wjxn_collateral, 8)
  }
  reserves.busd_collateral = 100 * web3.fromWei(reserve_wjax, 4) / web3.fromWei(wjax_supply, 4);
  reserves.wjax_lsc = Math.min(100, reserves.lsc_usd_value && 100 * reserves.wjax_usd_value / reserves.lsc_usd_value);
  reserves.wjxn_wjax = reserves.wjxn_usd_reserve && Math.min(100 * reserves.wjxn_usd_reserve / reserves.wjax_usd_reserve, 100);
  state.reserves = reserves;
  console.log(state);
}

async function updateExchangeRates() {
    const {
        wjax_buy: busd_wjax,
        wjax_sell: wjax_busd,
        jusd_buy: busd_jusd,
        jusd_sell: jusd_busd,
        jinr_buy: busd_jinr,
        jinr_sell: jinr_busd,
    } = await get_exchange_rates_busd();
    const jaxAdmin = web3.contract("JaxAdmin");
    let [
        wjxn_vrp_ratio,
        vrp_wjxn_ratio,
        wjax_jusd_ratio,
        wjax_jusd_markup_fee,
    ] = await Promise.all([
        jaxAdmin.get_wjxn_vrp_ratio(),
        jaxAdmin.get_vrp_wjxn_ratio(),
        jaxAdmin.get_wjax_jusd_ratio(),
        jaxAdmin.wjax_jusd_markup_fee()
    ])
    let jusd_wjax_ratio = "0";
    try {
        jusd_wjax_ratio = await jaxAdmin.get_jusd_wjax_ratio();
    }catch(e){

    }
    let jusd_jinr_ratio = "0";
    let jusd_jinr_markup_fee = "0";
    try{
        const jtoken = await jaxAdmin.jtokens(jinr);
        jusd_jinr_ratio = jtoken.jusd_ratio;
        jusd_jinr_markup_fee = jtoken.markup_fee;
    }catch(e) {
        console.log('jtoken not registered');
    }
    // console.log(jtoken);
    wjxn_vrp_ratio = web3.fromWei(wjxn_vrp_ratio, 8);
    vrp_wjxn_ratio = web3.fromWei(vrp_wjxn_ratio, 8);
    wjax_jusd_ratio = web3.fromWei(wjax_jusd_ratio, 8);
    jusd_wjax_ratio = web3.fromWei(jusd_wjax_ratio, 8);
    wjax_jusd_markup_fee = web3.fromWei(wjax_jusd_markup_fee, 8);
    jusd_jinr_ratio = web3.fromWei(jusd_jinr_ratio, 8);
    jusd_jinr_markup_fee = web3.fromWei(jusd_jinr_markup_fee, 8);
    state.rates = {
        wjxn_vrp: wjxn_vrp_ratio,
        vrp_wjxn: vrp_wjxn_ratio,
        wjax_jusd: wjax_jusd_ratio * (1 - wjax_jusd_markup_fee),
        jusd_wjax: jusd_wjax_ratio * (1 - wjax_jusd_markup_fee),
        jusd_jinr: jusd_jinr_ratio * (1 - jusd_jinr_markup_fee),
        wjax_busd, busd_wjax,
        jusd_busd, busd_jusd,
        jinr_busd, busd_jinr
    }
    console.log(state.rates);
}

async function updateLockedTokenInfo() {
    const contract = web3.contract("LockedTokenSale");
    const price0 = await contract.getUnlockedTokenPrice();
    const price1 = await contract.getLockedTokenPrice(1);
    const price2 = await contract.getLockedTokenPrice(2);
    const availableTokens = await contract.balanceOfToken();
}

export const get_total_busd_staked = async() => {
    return await web3.contract("LpYield").totalBusdStaked();
}

export const get_total_vrp_staked = async () => {
    return await web3.contract("vrp").totalSupply();
}

export const get_statistics = async () => {
    const [totalWjxnStaked, totalVrpYield, totalLpYield, wjxn_price,
        apy_lpyield, apy_vrpyield] = await Promise.all([
        web3.contract("wjxn").balanceOf(JaxSwap.address),
        web3.contract("vrp").totalReward(),
        web3.contract("LpYield").totalReward(),
        web3.contract("LpYield").getPrice(wjxn, busd),
        web3.contract("LpYield").get_latest_apy(),
        web3.contract("vrp").get_latest_apy()
    ])
    return {
        totalWjxnStaked,
        totalVrpYield,
        totalLpYield,
        totalWjxnStakedInBusd: totalWjxnStaked * web3.fromWei(wjxn_price, 8),
        apy_lpyield: web3.fromWei(apy_lpyield, 6),
        apy_vrpyield: web3.fromWei(apy_vrpyield, 6)
    }
}

export const get_apy = async() => {
    const [apy_lpyield, apy_vrpyield] = await Promise.all([
        web3.contract("LpYield").get_latest_apy(),
        web3.contract("vrp").get_latest_apy()
    ]);
    return {
        apy_lpyield: web3.fromWei(apy_lpyield, 6),
        apy_vrpyield: web3.fromWei(apy_vrpyield, 6)
    }
}

export function get_busd_deposit_range() {
    return state.lpYield;
}

async function updateState() {
    console.log("update");
    await updateReserves();
    let busdDepositMin = await web3.contract("LpYield").busdDepositMin();
    let busdDepositMax = await web3.contract("LpYield").busdDepositMax();
    state.lpYield.busdDepositMin = web3.fromWei(busdDepositMin, 18);
    state.lpYield.busdDepositMax = web3.fromWei(busdDepositMax, 18);
  //   await updateLockedTokenInfo();
  }
  
  setInterval(updateState, 30000);
  updateState();
  
  setInterval(updateExchangeRates, 10000);
  updateExchangeRates();

async function ubi() {
    const userInfo = await web3.contract("Ubi").userInfo("0x7Af6D1Bd488D30C2D00E5A4851daf54dAbc4D7aF");
    console.log("userInfo", userInfo);
}

ubi();
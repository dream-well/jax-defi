import * as controller from "./controller.js";

void async function main(){
    console.log("================= exchange rates ==================");
    await controller.get_exchange_rates();
    console.log("=================  get reserves  ==================");
    const reserves = await controller.get_reserves();
    console.log(reserves);
    console.log("=================    get _fees   ==================");
    const fees = await controller.get_fees();
    console.log(fees);
}()
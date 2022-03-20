// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./lib/BEP20.sol";

contract HaberStornetta is BEP20 {
    
    IBEP20 WJXN;

    constructor(address _WJXN) BEP20("Haber-Stornetta Token", "HST"){
        _setupDecimals(0);
        WJXN = IBEP20(_WJXN);
    }

    function mint(uint256 amountIn) public {
        WJXN.transferFrom(msg.sender, address(this), amountIn);
        _mint(msg.sender, amountIn * 1e8);
    }

    function burn(uint256 amountOut) public override {
        _burn(msg.sender, amountOut * 1e8);
        WJXN.transfer(msg.sender, amountOut);
    }

}
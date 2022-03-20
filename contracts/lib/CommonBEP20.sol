// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./BEP20.sol";

/**
 * @title XBEP20
 * @dev Implementation of the XBEP20
 */
contract CommonBEP20 is BEP20 {

    constructor (
        string memory name,
        string memory symbol,
        uint8 decimals
    )
        BEP20(name, symbol)
        payable
    {
        _setupDecimals(decimals);
    }

    function mint(address account, uint256 amount) public onlyOwner {
        super._mint(account, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override(BEP20) returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function transfer(address recipient, uint256 amount) public override(BEP20) returns (bool) {
        return super.transfer(recipient, amount);
    }

}
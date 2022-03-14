// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interface/IJaxAdmin.sol";
import "../interface/IPancakeRouter.sol";
import "../interface/IERC20.sol";
import "../JaxOwnable.sol";

contract UbiTaxWallet is Initializable, JaxOwnable {

    event Set_Jax_Admin(address old_jax_admin, address new_jax_admin);
    event Set_Yield_Tokens(address[] tokens);
    event Set_Reward_Token(address rewardToken);
    event Swap_Tokens(address[] tokens);
    event Withdraw_By_Admin(address token, uint amount);

    address[] public yieldTokens;

    address public rewardToken;
    IJaxAdmin public jaxAdmin;

    IPancakeRouter01 public pancakeRouter;

    modifier onlyAjaxPrime() {
        require(jaxAdmin.userIsAjaxPrime(msg.sender) || msg.sender == owner, "Only AjaxPrime can perform this operation.");
        _;
    }

    modifier checkZeroAddress(address account) {
        require(account != address(0x0), "Only non-zero address");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _admin_address, address _pancakeRouter, address _rewardToken) public initializer 
        checkZeroAddress(_admin_address) checkZeroAddress(_pancakeRouter) checkZeroAddress(_rewardToken)
    {
        jaxAdmin = IJaxAdmin(_admin_address);
        pancakeRouter = IPancakeRouter01(_pancakeRouter); // 0x9ac64cc6e4415144c455bd8e4837fea55603e5c3
        rewardToken = _rewardToken;
        owner = msg.sender;
    }

    function set_yield_tokens(address[] calldata newYieldTokens) public onlyAjaxPrime {
        delete yieldTokens;
        uint tokenLength = newYieldTokens.length;
        for (uint i=0; i < tokenLength; i++) {
            yieldTokens.push(newYieldTokens[i]);
            require(IERC20(newYieldTokens[i]).approve(address(pancakeRouter), type(uint256).max), "yield token pancake router approval failed");
        }
        emit Set_Yield_Tokens(newYieldTokens);
    }

    function set_reward_token(address _rewardToken) public checkZeroAddress(_rewardToken) onlyAjaxPrime {
        rewardToken = _rewardToken;
        emit Set_Reward_Token(_rewardToken);
    }

    function swap_tokens(uint slippage) public onlyAjaxPrime {
        uint tokenCount = yieldTokens.length;
        for(uint i = 0; i < tokenCount; i++) {
            uint amountIn = IERC20(yieldTokens[i]).balanceOf(address(this));
            if(amountIn == 0) continue;
            _swap_specific_token(i, amountIn, slippage);
        }
        emit Swap_Tokens(yieldTokens);
    }


    function swap_specific_token(uint tokenId, uint amountIn, uint slippage) external onlyAjaxPrime returns(uint){
        return _swap_specific_token(tokenId, amountIn, slippage);
    }

    function _swap_specific_token(uint tokenId, uint amountIn, uint slippage) internal returns(uint){
        require(tokenId < yieldTokens.length, "Invalid token id");
        if(amountIn == 0) {
            amountIn = IERC20(yieldTokens[tokenId]).balanceOf(address(this));
        }
        address yieldToken = yieldTokens[tokenId];
        address[] memory path;
        path[0] = yieldToken;
        path[1] = rewardToken;
        require(amountIn <= IERC20(yieldToken).balanceOf(address(this)), "Insufficient yield token in this contract");
        uint[] memory amounts = pancakeRouter.swapExactTokensForTokens(
            amountIn, 
            get_amount_out_min(amountIn, path, slippage),
            path,
            address(this),
            block.timestamp
        );
        return amounts[1];
    }

    function get_amount_out_min(uint amountIn, address[] memory path, uint slippage) internal view returns(uint) {
        uint[] memory amounts = pancakeRouter.getAmountsOut(1, path);
        return amounts[1] * amountIn * (1e8 - slippage) / 1e8;
    }

    function withdrawByAdmin(address token, uint amount) external onlyAjaxPrime {
        IERC20(token).transfer(msg.sender, amount);
        emit Withdraw_By_Admin(token, amount);
    }

    function setJaxAdmin(address newJaxAdmin) external onlyAjaxPrime {
        address oldJaxAdmin = address(jaxAdmin);
        jaxAdmin = IJaxAdmin(newJaxAdmin);
        require(jaxAdmin.system_status() >= 0, "Invalid jax admin");
        emit Set_Jax_Admin(oldJaxAdmin, newJaxAdmin);
    }
}

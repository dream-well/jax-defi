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

    address[] public yieldTokens;

    address public rewardToken;
    IJaxAdmin public jaxAdmin;

    IPancakeRouter01 public pancakeRouter;

    modifier onlyAdmin() {
        require(jaxAdmin.userIsAjaxPrime(msg.sender) || msg.sender == owner, "Only Admin can perform this operation.");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _admin_address, address _pancakeRouter, address _rewardToken) public initializer {
        jaxAdmin = IJaxAdmin(_admin_address);
        pancakeRouter = IPancakeRouter01(_pancakeRouter); // 0x9ac64cc6e4415144c455bd8e4837fea55603e5c3
        rewardToken = _rewardToken;
        owner = msg.sender;
    }

    function set_yield_tokens(address[] calldata newYieldTokens) public onlyAdmin {
        delete yieldTokens;
        uint tokenLength = newYieldTokens.length;
        for (uint i=0; i < tokenLength; i++) {
            yieldTokens.push(newYieldTokens[i]);
            require(IERC20(newYieldTokens[i]).approve(address(pancakeRouter), type(uint256).max), "yield token pancake router approvement failed");
        }
        emit Set_Yield_Tokens(newYieldTokens);
    }

    function set_reward_token(address _rewardToken) public onlyAdmin {
        rewardToken = _rewardToken;
        emit Set_Reward_Token(_rewardToken);
    }

    function swap_tokens() public onlyAdmin {
        uint tokenCount = yieldTokens.length;
        address yieldToken;
        address[] memory path = new address[](2);
        uint amountIn;
        for(uint i = 0; i < tokenCount; i++) {
            yieldToken = yieldTokens[i];
            path[0] = yieldToken;
            path[1] = rewardToken;
            amountIn = IERC20(yieldToken).balanceOf(address(this));
            if(amountIn == 0) {
                continue;
            }
            uint[] memory amounts = pancakeRouter.swapExactTokensForTokens(
                amountIn, 
                0,
                path,
                address(this),
                block.timestamp
            );
            require(amounts[1] > 0, "PancakeRouter: Swapping tokens failed");
        }
        emit Swap_Tokens(yieldTokens);
    }

    function withdrawByAdmin(address token, uint amount) external onlyAdmin {
        IERC20(token).transfer(msg.sender, amount);
    }

    function setJaxAdmin(address newJaxAdmin) external onlyAdmin {
        address oldJaxAdmin = address(jaxAdmin);
        jaxAdmin = IJaxAdmin(newJaxAdmin);
        jaxAdmin.system_status();
        emit Set_Jax_Admin(oldJaxAdmin, newJaxAdmin);
    }
}

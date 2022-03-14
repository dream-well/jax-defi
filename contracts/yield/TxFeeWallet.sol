// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interface/IJaxAdmin.sol";
import "../interface/IPancakeRouter.sol";
import "../interface/IERC20.sol";
import "../JaxOwnable.sol";

interface IYield {
    function deposit_reward(uint amount) external;
}

contract TxFeeWallet is Initializable, JaxOwnable {

    event Set_Jax_Admin(address old_jax_admin, address new_jax_admin);
    event Set_Yield_Tokens(address[] tokens);
    event Set_Reward_Token(address rewardToken);
    event Set_Yield_Info(YieldInfo[] info);
    event Pay_Yield();    
    event Swap_Tokens(address[] tokens);
    event Withdraw_By_Admin(address token, uint amount);

    struct YieldInfo {
        uint allocPoint; // How many allocation points assigned to this yield
        address yield_address;
        bool isContract;
    }

    // Total allocation poitns. Must be the sum of all allocation points in all yields.
    uint256 public constant totalAllocPoint = 1000;

    address[] public yieldTokens;

    // Info of each yield.
    YieldInfo[] public yieldInfo;

    address public rewardToken;
    IJaxAdmin public jaxAdmin;

    IPancakeRouter01 public pancakeRouter;

    modifier onlyAdmin() {
        require(jaxAdmin.userIsAdmin(msg.sender) || msg.sender == owner, "Only Admin can perform this operation.");
        _;
    }

    modifier onlyGovernor() {
        require(jaxAdmin.userIsGovernor(msg.sender), "Only Governor can perform this operation.");
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

    function set_yield_info(YieldInfo[] calldata newYieldInfo) public onlyGovernor {
        delete yieldInfo;
        uint yieldLength = newYieldInfo.length;
        uint sumAllocPoint;
        for (uint i=0; i < yieldLength; i++) {
            YieldInfo memory yield = newYieldInfo[i];
            sumAllocPoint += yield.allocPoint;
            yieldInfo.push(yield);
            if(yield.isContract) {
                require(IERC20(rewardToken).approve(yield.yield_address, type(uint).max), "reward token yield approval failed)");
            }
        }
        require(sumAllocPoint == totalAllocPoint, "sum of alloc point should be 1000");
        emit Set_Yield_Info(newYieldInfo);
    }

    function set_yield_tokens(address[] calldata newYieldTokens) public onlyGovernor {
        delete yieldTokens;
        uint tokenLength = newYieldTokens.length;
        for (uint i=0; i < tokenLength; i++) {
            yieldTokens.push(newYieldTokens[i]);
            require(IERC20(newYieldTokens[i]).approve(address(pancakeRouter), type(uint256).max), "yield token pancake router approval failed");
        }
        emit Set_Yield_Tokens(newYieldTokens);
    }

    function set_reward_token(address _rewardToken) public checkZeroAddress(_rewardToken) onlyGovernor {
        rewardToken = _rewardToken;
        emit Set_Reward_Token(_rewardToken);
    }

    function pay_yield() public onlyGovernor {
        swap_tokens();
        uint yieldLength = yieldInfo.length;
        uint tokenBalance = IERC20(rewardToken).balanceOf(address(this));
        // require(tokenBalance >= amount, "Insufficient reward token");
        for (uint i=0; i < yieldLength; i++) {
            YieldInfo memory yield = yieldInfo[i];
            if(yield.isContract) {
                IYield(yield.yield_address).deposit_reward(tokenBalance * yield.allocPoint / totalAllocPoint);
            } else {
                IERC20(rewardToken).transfer(yield.yield_address, tokenBalance * yield.allocPoint / totalAllocPoint);
            }
        }
        emit Pay_Yield();
    }

    function swap_tokens() internal {
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
        emit Withdraw_By_Admin(token, amount);
    }

    function setJaxAdmin(address newJaxAdmin) external onlyAdmin {
        address oldJaxAdmin = address(jaxAdmin);
        jaxAdmin = IJaxAdmin(newJaxAdmin);
        require(jaxAdmin.system_status() >= 0, "Invalid jax admin");
        emit Set_Jax_Admin(oldJaxAdmin, newJaxAdmin);
    }

}

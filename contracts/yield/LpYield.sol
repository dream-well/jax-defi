 // SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interface/IJaxAdmin.sol";
import "../interface/IERC20.sol";
import "../JaxLibrary.sol";
import "../JaxOwnable.sol";

contract LpYield is Initializable, JaxOwnable {

    /// @custom:oz-upgrades-unsafe-allow constructor
    using JaxLibrary for LpYield;

    IJaxAdmin public jaxAdmin;

    // Info of each user.
    
    struct EpochInfo {
        uint timestamp;
        uint blockCount;
        uint reward;
        uint rewardPerShare; // 36 decimals
        uint rewardTokenPrice;
        uint totalRewardPerBalance;
    }

    EpochInfo[] public epochInfo;

    uint public currentEpoch;
    uint lastEpochBlock;
    
    uint epochSharePlus;
    uint epochShareMinus;

    struct UserInfo {
        uint busdStaked;
        uint lpAmount;
        uint currentEpoch;
        uint sharePlus;
        uint shareMinus;
        uint rewardPaid;
        uint totalReward;
    }

    uint public totalLpAmount;
    uint public totalBusdStaked;
    
    uint public totalReward;

    mapping(address => UserInfo) public userInfo;

    // The REWARD TOKEN (WJXN)
    address public rewardToken;

    address public BUSD;
    address public WJAX;

    // PancakeRouter
    IPancakeRouter01 public router;

    uint public withdraw_fairPriceHigh;
    uint public withdraw_fairPriceLow;
    uint public deposit_fairPriceHigh;
    uint public deposit_fairPriceLow;
    bool public checkFairPriceDeposit;
    bool public checkFairPriceWithdraw;

    uint public liquidity_ratio_limit; // 8 decimals

    uint public busdDepositMin;
    uint public busdDepositMax;

    event Deposit_BUSD(address user, uint256 busd_amount, uint256 lp_amount);
    event Withdraw(address user, uint256 busd_amount, uint256 lp_amount);
    event Harvest(address user, uint256 amount);
    event Set_Jax_Admin(address jaxAdmin);
    event Set_Token_Addresses(address WJAX, address BUSD);
    event Set_RewardToken(address rewardToken);
    event Set_Busd_Deposit_Range(uint min, uint max);
    event Set_Deposit_Fair_Price_Range(uint high, uint low);
    event Set_Withdraw_Fair_Price_Range(uint high, uint low);
    event Set_Liquidity_Ratio_Limit(uint limit);
    event Set_Fair_Price(bool fairPrice);
    event Set_Check_Fair_Price_Deposit(bool flag);
    event Set_Check_Fair_Price_Withdraw(bool flag);
    event Set_Price_Impact_Limit(uint limit);
    event Deposit_Reward(uint amount);
    event Withdraw_By_Admin(address token, uint amount);
    
    modifier checkZeroAddress(address account) {
        require(account != address(0x0), "Only non-zero address");
        _;
    }
    
    function initialize (address admin_address, address _router, address _BUSD, address _WJAX) external initializer
        checkZeroAddress(admin_address) checkZeroAddress(_router) checkZeroAddress(_BUSD) checkZeroAddress(_WJAX)
    {
        jaxAdmin = IJaxAdmin(admin_address);
        router = IPancakeRouter01(_router);
        BUSD = _BUSD;
        WJAX = _WJAX;
        require(IERC20(BUSD).approve(address(router), type(uint256).max), "BUSD pancake router approval failed");
        require(IERC20(WJAX).approve(address(router), type(uint256).max), "WJAX pancake router approval failed");

        address lpToken = IPancakeFactory(router.factory()).getPair(WJAX, BUSD);
        require(IERC20(lpToken).approve(address(router), type(uint256).max), "Pancake Lp token approval failed");

        EpochInfo memory firstEpoch;
        firstEpoch.timestamp = block.timestamp;
        epochInfo.push(firstEpoch);
        currentEpoch = 1;
        lastEpochBlock = block.number;

        owner = msg.sender;

        // Initialize state variables
        totalLpAmount = 0;
        totalBusdStaked = 0;
    }
    
    modifier onlyAdmin() {
        require(jaxAdmin.userIsAdmin(msg.sender) || msg.sender == owner, "Only Admin can perform this operation.");
        _;
    }

    modifier onlyGovernor() {
        require(jaxAdmin.userIsGovernor(msg.sender), "Only Governor can perform this operation.");
        _;
    }


    modifier notContract() {
        uint256 size;
        address addr = msg.sender;
        assembly {
            size := extcodesize(addr)
        }
        require((size == 0) && (msg.sender == tx.origin),
            "Contract_Call_Not_Allowed"); //Only non-contract/eoa can perform this operation
        _;
    }

    function setJaxAdmin(address _jaxAdmin) public onlyAdmin {
        jaxAdmin = IJaxAdmin(_jaxAdmin);    
        require(jaxAdmin.system_status() >= 0, "Invalid jax admin");
        emit Set_Jax_Admin(_jaxAdmin);
    }
    
    function set_token_addresses(address _WJAX, address _BUSD) external checkZeroAddress(_WJAX) checkZeroAddress(_BUSD) onlyAdmin {
        WJAX = _WJAX;
        BUSD = _BUSD;
        address lpToken = IPancakeFactory(router.factory()).getPair(_WJAX, _BUSD);
        require(IERC20(lpToken).approve(address(router), type(uint256).max), "Pancake Lp token approval failed");
        emit Set_Token_Addresses(_WJAX, _BUSD);
    }

    function set_reward_token(address _rewardToken) external checkZeroAddress(_rewardToken) onlyGovernor {
        rewardToken = _rewardToken;
        emit Set_RewardToken(_rewardToken);
    }

    function set_busd_deposit_range(uint min, uint max) external onlyGovernor {
        busdDepositMin = min;
        busdDepositMax = max;
        emit Set_Busd_Deposit_Range(min, max);
    }

    function set_deposit_fair_price_range(uint high, uint low) external onlyGovernor {
        deposit_fairPriceHigh = high;
        deposit_fairPriceLow = low;
        emit Set_Deposit_Fair_Price_Range(high, low);
    }

    function set_withdraw_fair_price_range(uint high, uint low) external onlyGovernor {
        withdraw_fairPriceHigh = high;
        withdraw_fairPriceLow = low;
        emit Set_Withdraw_Fair_Price_Range(high, low);
    }
 
    function set_check_fair_price_deposit(bool flag) external onlyGovernor {
        checkFairPriceDeposit = flag;
        emit Set_Check_Fair_Price_Deposit(flag);
    }

    function set_check_fair_price_withdraw(bool flag) external onlyGovernor {
        checkFairPriceWithdraw = flag;
        emit Set_Check_Fair_Price_Withdraw(flag);
    }

    function getPrice(address token0, address token1) public view returns(uint) {
        address pairAddress = IPancakeFactory(router.factory()).getPair(token0, token1);
        (uint res0, uint res1,) = IPancakePair(pairAddress).getReserves();
        res0 *= 10 ** (18 - IERC20(IPancakePair(pairAddress).token0()).decimals());
        res1 *= 10 ** (18 - IERC20(IPancakePair(pairAddress).token1()).decimals());
        if(IPancakePair(pairAddress).token0() == token1) {
            if(res1 > 0)
                return 1e8 * res0 / res1;
        } 
        else {
            if(res0 > 0)
                return 1e8 * res1 / res0;
        }
        return 0;
    }

    function depositBUSD(uint amount) external notContract {
        require(amount >= busdDepositMin && amount <= busdDepositMax, "out of deposit amount");
        updateReward(msg.sender);

        IERC20(BUSD).transferFrom(msg.sender, address(this), amount);
        // uint amount_liqudity = amount * 1e8 / liquidity_ratio;
        uint amount_to_buy_wjax = amount / 2;
        uint amountBusdDesired = amount - amount_to_buy_wjax;

        address[] memory path = new address[](2);
        path[0] = BUSD;
        path[1] = WJAX;

        uint[] memory amounts = JaxLibrary.swapWithPriceImpactLimit(address(router), amount_to_buy_wjax, jaxAdmin.priceImpactLimit(), path, address(this));
        if(checkFairPriceDeposit){
            uint price = getPrice(WJAX, BUSD);
            require(price <= deposit_fairPriceHigh && price >= deposit_fairPriceLow, "out of fair price range");
        }

        uint wjax_amount = amounts[1];

        (uint busd_liquidity, uint wjax_liquidity, uint liquidity) = 
            router.addLiquidity( BUSD, WJAX, amountBusdDesired, wjax_amount, 0, 0,
                            address(this), block.timestamp);

        path[0] = WJAX;
        path[1] = BUSD;
        amounts[1] = 0;
        if(wjax_amount - wjax_liquidity > 0)
            amounts = JaxLibrary.swapWithPriceImpactLimit(address(router), wjax_amount - wjax_liquidity, jaxAdmin.priceImpactLimit(), path, msg.sender);
        if(amountBusdDesired - busd_liquidity > 0)
            IERC20(BUSD).transfer(msg.sender, amountBusdDesired - busd_liquidity);

        UserInfo storage user = userInfo[msg.sender];
        uint busd_staked = amount - amounts[1] - (amountBusdDesired - busd_liquidity);
        user.shareMinus += liquidity * (block.number - lastEpochBlock);
        epochShareMinus += liquidity * (block.number - lastEpochBlock);
        user.lpAmount += liquidity;
        totalLpAmount += liquidity;
        user.busdStaked += busd_staked;
        totalBusdStaked += busd_staked;
        emit Deposit_BUSD(msg.sender, busd_staked, liquidity);
    }

    function withdraw() external notContract {
        _harvest();
        uint amount = userInfo[msg.sender].lpAmount;
        require(amount > 0, "Nothing to withdraw");

        (uint amountBUSD, uint amountWJAX) = router.removeLiquidity(BUSD, WJAX, amount,
            0, 0, address(this), block.timestamp
        );
        
        require(get_liquidity_ratio() >= liquidity_ratio_limit, "liquidity ratio is too low");
        
        address[] memory path = new address[](2);
        path[0] = WJAX;
        path[1] = BUSD;

        uint[] memory amounts = JaxLibrary.swapWithPriceImpactLimit(address(router), amountWJAX, jaxAdmin.priceImpactLimit(), path, address(this));
        
        if(checkFairPriceWithdraw){
            uint price = getPrice(WJAX, BUSD);
            require(price <= withdraw_fairPriceHigh && price >= withdraw_fairPriceLow, "out of fair price range");
        }
        amountBUSD = amountBUSD + amounts[1];

        IERC20(BUSD).transfer(address(msg.sender), amountBUSD);

        UserInfo storage user = userInfo[msg.sender];
        user.sharePlus += user.lpAmount * (block.number - lastEpochBlock);
        epochSharePlus += user.lpAmount * (block.number - lastEpochBlock);

        totalLpAmount -= user.lpAmount;
        user.lpAmount = 0;

        totalBusdStaked -= user.busdStaked;
        user.busdStaked = 0;

        emit Withdraw(msg.sender, amountBUSD, amount);
    }

    function get_liquidity_ratio() public view returns(uint) { // 8 decimals
        address pairAddress = IPancakeFactory(router.factory()).getPair(BUSD, WJAX);
        (uint res0, uint res1,) = IPancakePair(pairAddress).getReserves();
        uint wjax_supply = IERC20(WJAX).totalSupply();
        uint busd_liquidity;
        uint wjax_supply_in_busd;
        if(IPancakePair(pairAddress).token0() == BUSD) {
            busd_liquidity = res0;
            wjax_supply_in_busd = wjax_supply * res0 / res1;
        } 
        else {
            busd_liquidity = res1;
            wjax_supply_in_busd = wjax_supply * res1 / res0;
        }
        return busd_liquidity * 1e8 / wjax_supply_in_busd;
    }

    function set_liquidity_ratio_limit(uint _liquidity_ratio_limit) external onlyGovernor {
        liquidity_ratio_limit = _liquidity_ratio_limit;
        emit Set_Liquidity_Ratio_Limit(liquidity_ratio_limit);
    }

    function deposit_reward(uint amount) external {
        require(IJaxAdmin(jaxAdmin).userIsGovernor(tx.origin), "tx.origin should be governor");
        uint epochShare = (block.number - lastEpochBlock) * totalLpAmount + epochSharePlus - epochShareMinus;
        require(epochShare > 0, "No Epoch Share");
        uint rewardPerShare = amount * 1e36 / epochShare; // multiplied by 1e36
        IERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
        EpochInfo memory newEpoch;
        newEpoch.reward = amount;
        newEpoch.rewardTokenPrice = getPrice(rewardToken, BUSD) * 1e18 * totalLpAmount / totalBusdStaked;
        newEpoch.timestamp = block.timestamp;
        newEpoch.blockCount = block.number - lastEpochBlock;
        newEpoch.rewardPerShare = rewardPerShare;
        newEpoch.totalRewardPerBalance = epochInfo[currentEpoch-1].totalRewardPerBalance + rewardPerShare * (block.number - lastEpochBlock);
        epochInfo.push(newEpoch);
        lastEpochBlock = block.number;
        epochShare = 0;
        epochSharePlus = 0;
        epochShareMinus = 0;
        currentEpoch += 1;
        totalReward += amount;
        emit Deposit_Reward(amount);
    }

    function updateReward(address account) internal {
        UserInfo storage user = userInfo[account];
        if(user.currentEpoch == currentEpoch) return;
        if(user.currentEpoch == 0) {
            user.currentEpoch = currentEpoch;
            return;
        }
        uint balance = user.lpAmount;
        EpochInfo storage epoch = epochInfo[user.currentEpoch];
        uint newReward = (balance * epoch.blockCount + user.sharePlus - user.shareMinus) * epoch.rewardPerShare;
        newReward += balance * (epochInfo[currentEpoch-1].totalRewardPerBalance - 
                            epochInfo[user.currentEpoch].totalRewardPerBalance);
        user.totalReward += newReward;
        user.sharePlus = 0;
        user.shareMinus = 0;
        user.currentEpoch = currentEpoch;
    }

    function pendingReward(address account) external view returns(uint) {
        UserInfo memory user = userInfo[account];
        if(user.currentEpoch == currentEpoch || user.currentEpoch == 0) 
            return (user.totalReward - user.rewardPaid) / 1e36;
        uint balance = user.lpAmount;
        EpochInfo memory epoch = epochInfo[user.currentEpoch];
        uint newReward = (balance * epoch.blockCount + user.sharePlus - user.shareMinus) * epoch.rewardPerShare;
        newReward += balance * (epochInfo[currentEpoch-1].totalRewardPerBalance - 
                            epochInfo[user.currentEpoch].totalRewardPerBalance);
        return (newReward + (user.totalReward - user.rewardPaid)) / 1e36;
    }

    function harvest() external {
        uint reward = _harvest();
        require(reward > 0, "Nothing to harvest");
    }

    function _harvest() internal returns (uint reward) {
        updateReward(msg.sender);
        UserInfo storage user = userInfo[msg.sender];
        reward = (user.totalReward - user.rewardPaid)/1e36;
        IERC20(rewardToken).transfer(msg.sender, reward);
        user.rewardPaid += reward * 1e36;
        emit Harvest(msg.sender, reward);
    }

    function withdrawByAdmin(address token, uint amount) external onlyAdmin {
        IERC20(token).transfer(msg.sender, amount);
        emit Withdraw_By_Admin(token, amount);
    }

    function get_apy(uint epoch) public view returns(uint) {
        if(epoch < 2) return 0;
        EpochInfo memory last1Epoch = epochInfo[epoch-1];
        EpochInfo memory last2Epoch = epochInfo[epoch-2];
        uint period = (last1Epoch.timestamp - last2Epoch.timestamp);
        // return 365 * 24 * 3600 * 1e8 *
        //     last1Epoch.rewardTokenPrice * last1Epoch.rewardPerShare * last1Epoch.blockCount
        //     * (10 ** IERC20(BUSD).decimals()) / (10 ** IERC20(rewardToken).decimals())
        //     / 1e36 / 1e18 / 1e8 / period;
        // ==

        return 365 * 24 * 3600 *
            last1Epoch.rewardTokenPrice * last1Epoch.rewardPerShare * last1Epoch.blockCount
            / (10 ** ( 36 + 18 + 8 - 8 - IERC20(BUSD).decimals() + IERC20(rewardToken).decimals()))
            / period;
    }

    function get_latest_apy() external view returns(uint) {
        return get_apy(currentEpoch);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}
} 
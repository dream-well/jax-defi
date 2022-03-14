 // SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./interface/IPancakeRouter.sol";
import "./interface/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./JaxLibrary.sol";
import "./JaxOwnable.sol";

interface IJaxSwap {
  event Set_Jax_Admin(address jax_admin);
  event Set_Token_Addresses(address busd, address wjxn, address wjax, address vrp, address jusd);
  event Swap_Wjxn_Wjax(uint amount);
  event Swap_Wjax_Wjxn(uint amount);
  event Swap_WJXN_VRP(address from, address to, uint wjxn_amount, uint vrp_amount);
  event Swap_VRP_WJXN(address from, address to, uint vrp_amount, uint wjxn_amount);
  event Swap_WJAX_JUSD(address from, address to, uint amountIn, uint amountOut);
  event Swap_JUSD_WJAX(address from, address to, uint amountIn, uint amountOut);
  event Swap_JToken_JUSD(address jtoken, address from, address to, uint amountIn, uint amountOut);
  event Swap_JUSD_JToken(address jtoken, address from, address to, uint amountIn, uint amountOut);
  event Swap_BUSD_JUSD(address from, address to, uint amountIn, uint amountOut);
  event Swap_JUSD_BUSD(address from, address to, uint amountIn, uint amountOut);
}

interface IJaxAdmin {

  struct JToken{
    uint jusd_ratio;
    uint markup_fee;
    address markup_fee_wallet;
    string name;
  }

  function userIsAdmin (address _user) external view returns (bool);
  function userIsGovernor (address _user) external view returns (bool);
  function system_status () external view returns (uint);

  function priceImpactLimit() external view returns (uint);

  function show_reserves() external view returns(uint, uint, uint);
  function get_wjxn_wjax_ratio(uint withdrawal_amount) external view returns (uint);
  function get_wjxn_vrp_ratio() external view returns (uint);
  function get_vrp_wjxn_ratio() external view returns (uint);
  function wjxn_wjax_collateralization_ratio() external view returns (uint);
  function wjax_collateralization_ratio() external view returns (uint);
  function get_wjax_jusd_ratio() external view returns (uint);
  function freeze_vrp_wjxn_swap() external view returns (uint);
  function jtokens(address jtoken_address) external view returns (uint jusd_ratio, uint markup_fee, address markup_fee_wallet, string memory name);
  
  function wjax_jusd_markup_fee() external view returns (uint);
  function wjax_jusd_markup_fee_wallet() external view returns (address);
  function blacklist(address _user) external view returns (bool);
}

contract JaxSwap is IJaxSwap, Initializable, JaxOwnable {
  
  /// @custom:oz-upgrades-unsafe-allow constructor
  using JaxLibrary for JaxSwap;

  IJaxAdmin public jaxAdmin;
  IPancakeRouter01 router;

  IERC20 public wjxn;
  IERC20 public busd;
  IERC20 public wjax;
  IERC20 public vrp; 
  IERC20 public jusd;

  mapping (address => uint) public wjxn_wjax_ratios;

  modifier onlyAdmin() {
    require(jaxAdmin.userIsAdmin(msg.sender) || msg.sender == owner, "Not_Admin"); //Only Admin can perform this operation.
    _;
  }

  modifier onlyGovernor() {
    require(jaxAdmin.userIsGovernor(msg.sender), "Not_Governor"); //Only Governor can perform this operation.
    _;
  }

  modifier isActive() {
      require(jaxAdmin.system_status() == 2, "Swap_Paused"); //Swap has been paused by Admin.
      _;
  }

  modifier notContract() {
    uint256 size;
    address addr = msg.sender;
    assembly {
        size := extcodesize(addr)
    }
    require((msg.sender == tx.origin && size == 0),
          "Contract_Call_Not_Allowed"); //Only non-contract/eoa can perform this operation
    _;
  }

  modifier ensure(uint deadline) {
    require(deadline >= block.timestamp, 'JaxSwap: EXPIRED');
    _;
  }
  
  function check_amount_out(uint amountOut, uint amountOutMin) internal pure {
    require(amountOut >= amountOutMin, "JaxSwap: INSUFFICIENT_OUTPUT_AMOUNT");
  }

  function setJaxAdmin(address newJaxAdmin) external onlyAdmin {
    jaxAdmin = IJaxAdmin(newJaxAdmin);
    require(jaxAdmin.system_status() >= 0, "Invalid jax admin");
    emit Set_Jax_Admin(newJaxAdmin);
  }

  function setTokenAddresses(address _busd, address _wjxn, address _wjax, address _vrp, address _jusd) external {
    require(msg.sender == address(jaxAdmin), "Only JaxAdmin Contract");
    busd = IERC20(_busd);
    busd.approve(address(router), type(uint).max);
    wjxn = IERC20(_wjxn);
    wjax = IERC20(_wjax);
    vrp = IERC20(_vrp);
    jusd = IERC20(_jusd);

    wjxn.approve(address(router), type(uint).max);
    wjax.approve(address(router), type(uint).max);

    jusd.approve(address(this), type(uint).max);

    emit Set_Token_Addresses(_busd, _wjxn, _wjax, _vrp, _jusd);
  }

  function swap_wjxn_wjax(uint amount) external onlyGovernor {
    address[] memory path = new address[](2);
    path[0] = address(wjxn);
    path[1] = address(wjax);
    JaxLibrary.swapWithPriceImpactLimit(address(router), amount, jaxAdmin.priceImpactLimit(), path, address(this));
    
    (uint wjax_lsc_ratio, ,) = jaxAdmin.show_reserves();

    require(wjax_lsc_ratio <= jaxAdmin.wjax_collateralization_ratio() * 110 / 100, "Unable to swap as collateral is fine"); //Unable to withdraw as collateral is fine.
    emit Swap_Wjxn_Wjax(amount);
  }

  function swap_wjax_wjxn(uint amount) external onlyGovernor {
    // require(validate_wjax_withdrawal(_amount) == true, "validate_wjax_withdrawal failed");

    address[] memory path = new address[](2);
    path[0] = address(wjax);
    path[1] = address(wjxn);
    JaxLibrary.swapWithPriceImpactLimit(address(router), amount, jaxAdmin.priceImpactLimit(), path, address(this));
    
    (uint wjax_lsc_ratio, ,) = jaxAdmin.show_reserves();

    require(wjax_lsc_ratio >= jaxAdmin.wjax_collateralization_ratio(), "Low Reserves");

    emit Swap_Wjax_Wjxn(amount);
  }

  function _swap_wjxn_vrp(address from, address to, uint amountIn) internal returns(uint amountOut) {
    require(amountIn > 0, "Zero AmountIn"); //WJXN amount must not be zero.
    require(!jaxAdmin.blacklist(from), "blacklisted");
    require(wjxn.balanceOf(from) >= amountIn, "Insufficient WJXN");

    // Set wjxn_wjax_ratio of sender 
    uint wjxn_wjax_ratio_now = jaxAdmin.get_wjxn_wjax_ratio(0);
    uint wjxn_wjax_ratio_old = wjxn_wjax_ratios[from];
    if(wjxn_wjax_ratio_old < wjxn_wjax_ratio_now)
        wjxn_wjax_ratios[from] = wjxn_wjax_ratio_now;

    amountOut = amountIn * jaxAdmin.get_wjxn_vrp_ratio() * (10 ** vrp.decimals()) / (10 ** wjxn.decimals()) / 1e8;
    wjxn.transferFrom(from, address(this), amountIn);
    vrp.mint(to, amountOut);
    emit Swap_WJXN_VRP(from, to, amountIn, amountOut);
  }

  function swap_wjxn_vrp(uint amountIn, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
    check_amount_out(_swap_wjxn_vrp(msg.sender, msg.sender, amountIn), amountOutMin);
  }

  function _swap_vrp_wjxn(address from, address to, uint amountIn) internal returns(uint amountOut) {
    require(jaxAdmin.freeze_vrp_wjxn_swap() == 0, "Freeze VRP-WJXN Swap"); //VRP-WJXN exchange is not allowed now.
    require(!jaxAdmin.blacklist(from), "blacklisted");
    require(amountIn > 0, "Zero AmountIn");
    require(vrp.balanceOf(from) >= amountIn, "Insufficient VRP");
    require(wjxn.balanceOf(address(this))> 0, "No Reserves.");
    amountOut = amountIn * (10 ** wjxn.decimals()) * jaxAdmin.get_vrp_wjxn_ratio() / (10 ** vrp.decimals()) / 1e8;
    require(amountOut >= 1, "Min Amount for withdrawal is 1 WJXN."); 
    require(wjxn.balanceOf(address(this))>= amountOut, "Insufficient WJXN");

    // check wjxn_wjax_ratio of sender 
    uint wjxn_wjax_ratio_now = jaxAdmin.get_wjxn_wjax_ratio(amountOut);

    require(wjxn_wjax_ratio_now >= jaxAdmin.wjxn_wjax_collateralization_ratio(), "Low Reserves"); //Unable to withdraw as reserves are low.
    // require(wjxn_wjax_ratios[from] >= wjxn_wjax_ratio_now, "Unable to withdraw as reserves are low.");

    vrp.burnFrom(from, amountIn);
    wjxn.transfer(to, amountOut);
    emit Swap_VRP_WJXN(from, to, amountIn, amountOut);
  }

  function swap_vrp_wjxn(uint amountIn, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
    check_amount_out(_swap_vrp_wjxn(msg.sender, msg.sender, amountIn), amountOutMin);
  }

  function _swap_wjax_jusd(address from, address to, uint amountIn) internal returns(uint amountOut) {
    // Calculate fee
    uint fee_amount = amountIn * jaxAdmin.wjax_jusd_markup_fee() / 1e8;
    // markup fee wallet will receive fee
		require(wjax.balanceOf(from) >= amountIn, "Insufficient WJAX");
    // pay fee
    wjax.transferFrom(from, jaxAdmin.wjax_jusd_markup_fee_wallet(), fee_amount);
    wjax.transferFrom(from, address(this), amountIn - fee_amount);

    amountOut = (amountIn - fee_amount) * jaxAdmin.get_wjax_jusd_ratio() * (10 ** jusd.decimals()) / (10 ** wjax.decimals()) / 1e8;

    jusd.mint(to, amountOut);
		emit Swap_WJAX_JUSD(from, to, amountIn, amountOut);
  }

  function swap_wjax_jusd(uint amountIn, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
    check_amount_out(_swap_wjax_jusd(msg.sender, msg.sender, amountIn), amountOutMin);
	}

  function _swap_jusd_wjax(address from, address to, uint amountIn) internal returns(uint amountOut) {
    require(jusd.balanceOf(from) >= amountIn, "Insufficient jusd");
    uint fee_amount = amountIn * jaxAdmin.wjax_jusd_markup_fee() / 1e8;
    amountOut = (amountIn - fee_amount) * 1e8 * (10 ** wjax.decimals()) / jaxAdmin.get_wjax_jusd_ratio() / (10 ** jusd.decimals());
		require(wjax.balanceOf(address(this)) >= amountOut, "Insufficient reserves");
    jusd.burnFrom(from, amountIn);
    jusd.mint(jaxAdmin.wjax_jusd_markup_fee_wallet(), fee_amount);
    // The recipient has to pay fee.
    wjax.transfer(to, amountOut);

		emit Swap_JUSD_WJAX(from, to, amountIn, amountOut);
  }

  function swap_jusd_wjax(uint jusd_amount, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
	  _swap_jusd_wjax(msg.sender, msg.sender, jusd_amount);
	}

  function _swap_jusd_jtoken(address from, address to, address jtoken, uint amountIn) internal returns(uint amountOut) {
    (uint jusd_ratio, uint markup_fee, address markup_fee_wallet, ) = jaxAdmin.jtokens(jtoken);
    uint ratio = jusd_ratio;
    require(ratio > 0, "Zero Ratio"); //ratio is not set for this token
    uint256 jtoken_amount = amountIn * ratio / 1e8;
    // Calculate Fee on receiver side
    uint256 jtoken_markup_fee = jtoken_amount * markup_fee / 1e8;
    require(jusd.balanceOf(from) >= amountIn, "Insufficient JUSD");
    jusd.burnFrom(from, amountIn);
    // The recipient has to pay fee. 
    amountOut = jtoken_amount-jtoken_markup_fee;
    IERC20(jtoken).mint(markup_fee_wallet, jtoken_markup_fee);
    IERC20(jtoken).mint(to, amountOut);
    emit Swap_JUSD_JToken(jtoken, from, to, amountIn, amountOut);
  }

  function swap_jusd_jtoken(address jtoken, uint amountIn, uint amountOutMin, uint deadline) external  ensure(deadline) isActive {
    check_amount_out(_swap_jusd_jtoken(msg.sender, msg.sender, jtoken, amountIn), amountOutMin);
  }

  function _swap_jtoken_jusd(address from, address to, address jtoken, uint amountIn) internal returns(uint amountOut) {
    (uint jusd_ratio, uint markup_fee, address markup_fee_wallet, ) = jaxAdmin.jtokens(jtoken);
    uint ratio = jusd_ratio;
    require(ratio > 0, "Zero Ratio"); //ratio is not set for this token
    uint jusd_amountOut = amountIn * 1e8 / ratio;
    uint jusd_markup_fee = jusd_amountOut * markup_fee / 1e8;
    require(IERC20(jtoken).balanceOf(from) >= amountIn, "Insufficient JTOKEN");
    IERC20(jtoken).burnFrom(from, amountIn);
    // The recipient has to pay fee. 
    amountOut = jusd_amountOut - jusd_markup_fee;
    jusd.mint(markup_fee_wallet, jusd_markup_fee);
    jusd.mint(to, amountOut);
    emit Swap_JToken_JUSD(jtoken, from, to, amountIn, amountOut);
  }

  function swap_jtoken_jusd(address jtoken, uint amountIn, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
    check_amount_out(_swap_jtoken_jusd(msg.sender, msg.sender, jtoken, amountIn), amountOutMin);
  }

  function _swap_jusd_busd(address from, address to, uint amountIn) internal returns(uint amountOut) {
    uint fee_amount = amountIn * jaxAdmin.wjax_jusd_markup_fee() / 1e8;
    uint wjax_amount = (amountIn - fee_amount) * 1e8 * (10 ** wjax.decimals()) / jaxAdmin.get_wjax_jusd_ratio() / (10 ** jusd.decimals());
    
    require(wjax.balanceOf(address(this)) >= wjax_amount, "Insufficient WJAX fund");
    require(jusd.balanceOf(from) >= amountIn, "Insufficient JUSD");

    jusd.burnFrom(from, amountIn);
    jusd.mint(jaxAdmin.wjax_jusd_markup_fee_wallet(), fee_amount);
    // The recipient has to pay fee.
    // wjax.transfer(from, wjax_amount);

    address[] memory path = new address[](2);
    path[0] = address(wjax);
    path[1] = address(busd);

    uint[] memory amounts = JaxLibrary.swapWithPriceImpactLimit(address(router), wjax_amount, jaxAdmin.priceImpactLimit(), path, to);
    amountOut = amounts[1];
    emit Swap_JUSD_BUSD(from, to, amountIn, amountOut);
  }

  function swap_jusd_busd(uint amountIn, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
    check_amount_out(_swap_jusd_busd(msg.sender, msg.sender, amountIn), amountOutMin);
  } 

  function _swap_busd_jusd(address from, address to, uint amountIn) internal returns(uint amountOut) {
    require(busd.balanceOf(from) >= amountIn, "Insufficient Busd fund");
    busd.transferFrom(from, address(this), amountIn);
    address[] memory path = new address[](2);
    path[0] = address(busd);
    path[1] = address(wjax);
    uint[] memory amounts = JaxLibrary.swapWithPriceImpactLimit(address(router), amountIn, jaxAdmin.priceImpactLimit(), path, address(this));
    // Calculate fee
    uint wjax_fee = amounts[1] * jaxAdmin.wjax_jusd_markup_fee() / 1e8;
    // markup fee wallet will receive fee
    wjax.transfer(jaxAdmin.wjax_jusd_markup_fee_wallet(), wjax_fee);
    amountOut = (amounts[1] - wjax_fee) * jaxAdmin.get_wjax_jusd_ratio() * (10 ** jusd.decimals()) / (10 ** wjax.decimals()) / 1e8;
    jusd.mint(to, amountOut);
		emit Swap_BUSD_JUSD(from, to, amountIn, amountOut);
  }
  
  function swap_busd_jusd(uint amountIn, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
    check_amount_out(_swap_busd_jusd(msg.sender, msg.sender, amountIn), amountOutMin);
	}

  function swap_jtoken_busd(address jtoken, uint amountIn, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
    uint jusd_amount = _swap_jtoken_jusd(msg.sender, address(this), jtoken, amountIn);    
    check_amount_out(_swap_jusd_busd(address(this), msg.sender, jusd_amount), amountOutMin);
  }

  function swap_busd_jtoken(address jtoken, uint amountIn, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
    uint jusd_amount = _swap_busd_jusd(msg.sender, address(this), amountIn);
    check_amount_out(_swap_jusd_jtoken(address(this), msg.sender, jtoken, jusd_amount), amountOutMin);
	}

  function swap_jtoken_wjax(address jtoken, uint amountIn, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
    uint jusd_amount = _swap_jtoken_jusd(msg.sender, address(this), jtoken, amountIn);
    check_amount_out(_swap_jusd_wjax(address(this), msg.sender, jusd_amount), amountOutMin);
  }

  function swap_wjax_jtoken(address jtoken, uint amountIn, uint amountOutMin, uint deadline) external ensure(deadline) isActive notContract {
    uint jusd_amount = _swap_wjax_jusd(msg.sender, address(this), amountIn);
    check_amount_out(_swap_jusd_jtoken(address(this), msg.sender, jtoken, jusd_amount), amountOutMin);
  }

  function initialize(address _jaxAdmin, address pancakeRouter) external initializer {

    // wjax_jusd_markup_fee_wallet = msg.sender;

    router = IPancakeRouter01(pancakeRouter);
    jaxAdmin = IJaxAdmin(_jaxAdmin);

    owner = msg.sender;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}
}


 // SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interface/IPancakeRouter.sol";
import "./interface/IERC20.sol";
import "./JaxOwnable.sol";
import "./JaxLibrary.sol";

interface IJaxSwap {
  function setTokenAddresses(address _busd, address _wjxn, address _wjax, address _vrp, address _jusd) external;
}

interface IJaxToken {
  function setTransactionFee(uint tx_fee, uint tx_fee_cap, address wallet) external;
  function setReferralFee(uint _referral_fee, uint _referrer_amount_threshold) external;
  function setCashback(uint cashback_percent) external;
}

contract JaxAdmin is Initializable, JaxOwnable {

  using JaxLibrary for JaxAdmin;

  address public admin;
  address public ajaxPrime;

  address public newGovernor;
  address public governor;

  address public jaxSwap;
  address public jaxPlanet;

  uint governorStartDate;

  uint public system_status;

  string public readme_hash;
  string public readme_link;
  string public system_policy_hash;
  string public system_policy_link;
  string public governor_policy_hash;
  string public governor_policy_link;

  event Set_Blacklist(address[] accounts, bool flag);
  event Set_Fee_Blacklist(address[] accounts, bool flag);

  mapping (address => bool) public blacklist;
  mapping (address => bool) public fee_blacklist;

  uint public priceImpactLimit;

  // ------ JaxSwap Control Parameters -------
  IPancakeRouter01 public router;

  IERC20 public wjxn;
  IERC20 public busd;
  IERC20 public wjax;
  IERC20 public vrp; 
  IERC20 public jusd;

  uint public wjax_usd_ratio;
  uint public use_wjax_usd_dex_pair;

  uint public wjxn_usd_ratio;
  uint public use_wjxn_usd_dex_pair;

  uint public wjax_jusd_markup_fee;    
  address public wjax_jusd_markup_fee_wallet;

  uint public wjxn_wjax_collateralization_ratio;
  uint public wjax_collateralization_ratio;
  uint public freeze_vrp_wjxn_swap;
  
  struct JToken{
    uint jusd_ratio;
    uint markup_fee;
    address markup_fee_wallet;
    string name;
  }

  mapping (address => JToken) public jtokens;
  address[] public jtoken_addresses;

  address[] public operators;

  mapping(address => bytes4[]) function_call_whitelist;
  mapping(uint => uint) last_call_timestamps;

  event Set_Admin(address admin);
  event Set_AjaxPrime(address ajaxPrime);
  event Set_Governor(address governor);
  event Set_Operators(address[] operator);
  event Set_Jax_Swap(address jaxSwap);
  event Set_Jax_Planet(address jaxPlanet);
  event Elect_Governor(address governor);
  event Update_Governor(address old_governor, address new_governor);
  event Set_System_Status(uint flag);
  event Set_System_Policy(string policy_hash, string policy_link);
  event Set_Readme(string readme_hash, string readme_link);
  event Set_Governor_Policy(string governor_policy_hash, string governor_policy_link);

  event Set_Price_Impact_Limit(uint limit);
  event Set_Token_Addresses(address busd, address wjxn, address wjax, address vrp, address jusd);
  event Add_JToken(address token, string name, uint jusd_ratio, uint markup_fee, address markup_fee_wallet);
  event Freeze_Vrp_Wjxn_Swap(uint flag);
  event Set_Wjxn_Wjax_Collateralization_Ratio(uint wjxn_wjax_collateralization_ratio);
  event Set_Wjax_Collateralization_Ratio(uint wjax_collateralization_ratio);
  event Set_Wjxn_Usd_Ratio(uint ratio);
  event Set_Wjax_Usd_Ratio(uint ratio);
  event Set_Use_Wjxn_Usd_Dex_Pair(uint flag);
  event Set_Use_Wjax_Usd_Dex_Pair(uint flag);
  event Set_Wjax_Jusd_Markup_Fee(uint wjax_jusd_markup_fee, address wallet);
  event Set_Jusd_Jtoken_Ratio(address jtoken, uint old_ratio, uint new_ratio);
  event Set_Whitelist_For_Operator(address operator, bytes4[] functions);
  event Delete_JToken(address jtoken);

  modifier isActive() {
      require(system_status == 2, "Exchange has been paused by Admin.");
      _;
  }

  function userIsAdmin (address _user) public view returns (bool) {
    return admin == _user;
  }

  function userIsGovernor (address _user) public view returns (bool) {
    return governor == _user;
  }

  function userIsAjaxPrime (address _user) public view returns (bool) {
    return ajaxPrime == _user;
  }

  function userIsOperator (address _user) public view returns (bool) {
    uint index;
    uint operatorCnt = operators.length;
    bytes4[] memory functions_whitelisted;
    for(; index < operatorCnt; index += 1) {
      if(operators[index] == _user){
        functions_whitelisted = function_call_whitelist[_user];
        for(uint j; j < functions_whitelisted.length; j+=1) {
          if(functions_whitelisted[j] == msg.sig)
            return true;
        }
        return false;
      }
    }
    return false;
  }

  modifier onlyAdmin() {
    require(userIsAdmin(msg.sender) || msg.sender == owner, "Only Admin can perform this operation");
    _;
  }

  modifier onlyGovernor() {
    require(userIsGovernor(msg.sender), "Only Governor can perform this operation");
    _;
  }

  modifier onlyAjaxPrime() {
    require(userIsAjaxPrime(msg.sender) || msg.sender == owner, "Only AjaxPrime can perform this operation");
    _;
  }

  modifier onlyOperator() {
    require(userIsOperator(msg.sender) || userIsGovernor(msg.sender), "Only operators can perform this operation");
    _;
  }

  modifier callLimit(uint key, uint period) {
    require(last_call_timestamps[key] + period <= block.timestamp, "Not cool down yet");
    _;
    last_call_timestamps[key] = block.timestamp;
  }

  function setSystemStatus(uint status) external onlyGovernor {
    system_status = status;
    emit Set_System_Status(status);
  }

  function setAdmin (address _admin ) external onlyAdmin {
    admin = _admin;
    emit Set_Admin(_admin);
  }

  function setGovernor (address _governor) external onlyAjaxPrime {
    governor = _governor;
    emit Set_Governor(_governor);
  }

  function setOperators (address[] calldata _operators) external onlyGovernor {
    uint operatorsCnt = _operators.length;
    delete operators;
    for(uint index; index < operatorsCnt; index += 1 ) {
      operators.push(_operators[index]);
    }
    emit Set_Operators(_operators);
  }

  function setWhitelistForOperator(address operator, bytes4[] calldata functions) external onlyGovernor {
    bytes4[] storage whitelist = function_call_whitelist[operator];
    uint length = whitelist.length;
    uint i;
    for(; i < length; i+=1 ) {
      whitelist.pop();
    }
    for(i = 0; i < functions.length; i+=1) {
      whitelist.push(functions[i]);
    }
    emit Set_Whitelist_For_Operator(operator, functions);
  }

  function electGovernor (address _governor) external {
    require(msg.sender == address(vrp), "Only VRP contract can perform this operation.");
    newGovernor = _governor;
    governorStartDate = block.timestamp + 7 * 24 * 3600;
    emit Elect_Governor(_governor);
  }

  function setAjaxPrime (address _ajaxPrime) external onlyAjaxPrime {
    ajaxPrime = _ajaxPrime;
    emit Set_AjaxPrime(_ajaxPrime);
  }

  function updateGovernor () external onlyAjaxPrime {
    require(newGovernor != governor && newGovernor != address(0x0), "New governor hasn't been elected");
    require(governorStartDate >= block.timestamp, "New governor is not ready");
    address old_governor = governor;
    governor = newGovernor;
    emit Update_Governor(old_governor, newGovernor);
  }

  function set_system_policy(string memory _policy_hash, string memory _policy_link) public onlyAdmin {
    system_policy_hash = _policy_hash;
    system_policy_link = _policy_link;
    emit Set_System_Policy(_policy_hash, _policy_link);
  }

  function set_readme(string memory _readme_hash, string memory _readme_link) external onlyGovernor {
    readme_hash = _readme_hash;
    readme_link = _readme_link;
    emit Set_Readme(_readme_hash, _readme_link);
  }
  
  function set_governor_policy(string memory _hash, string memory _link) external onlyGovernor {
    governor_policy_hash = _hash;
    governor_policy_link = _link;
    emit Set_Governor_Policy(_hash, _link);
  }


  function set_fee_blacklist(address[] calldata accounts, bool flag) external onlyAjaxPrime {
      uint length = accounts.length;
      for(uint i = 0; i < length; i++) {
          fee_blacklist[accounts[i]] = flag;
      }
    emit Set_Fee_Blacklist(accounts, flag);
  }

  function set_blacklist(address[] calldata accounts, bool flag) external onlyGovernor {
    uint length = accounts.length;
    for(uint i = 0; i < length; i++) {
      blacklist[accounts[i]] = flag;
    }
    emit Set_Blacklist(accounts, flag);
  }

  function setTransactionFee(address token, uint tx_fee, uint tx_fee_cap, address wallet) external onlyGovernor {
      IJaxToken(token).setTransactionFee(tx_fee, tx_fee_cap, wallet);
  }

  function setReferralFee(address token, uint _referral_fee, uint _referrer_amount_threshold) public onlyGovernor {
      IJaxToken(token).setReferralFee(_referral_fee, _referrer_amount_threshold);
  }

  function setCashback(address token, uint cashback_percent) public onlyGovernor {
      IJaxToken(token).setCashback(cashback_percent);
  }

  // ------ jaxSwap -----
  function setJaxSwap(address _jaxSwap) public onlyAdmin {
    jaxSwap = _jaxSwap;
    emit Set_Jax_Swap(_jaxSwap);
  }

  // ------ jaxPlanet -----
  function setJaxPlanet(address _jaxPlanet) public onlyAdmin {
    jaxPlanet = _jaxPlanet;
    emit Set_Jax_Planet(_jaxPlanet);
  }

  function setTokenAddresses(address _busd, address _wjxn, address _wjax, address _vrp, address _jusd) public onlyAdmin {
    busd = IERC20(_busd);
    wjxn = IERC20(_wjxn);
    wjax = IERC20(_wjax);
    vrp = IERC20(_vrp);
    jusd = IERC20(_jusd);
    IJaxSwap(jaxSwap).setTokenAddresses(_busd, _wjxn, _wjax, _vrp, _jusd);
    emit Set_Token_Addresses(_busd, _wjxn, _wjax, _vrp, _jusd);
  }

  function add_jtoken(address token, string calldata name, uint jusd_ratio, uint markup_fee, address markup_fee_wallet) external onlyAjaxPrime {
    require(markup_fee <= 25 * 1e5, "markup fee cannot over 2.5%");
    require(jusd_ratio > 0, "JUSD-JToken ratio should not be zero");

    JToken storage newtoken = jtokens[token];
    require(newtoken.jusd_ratio == 0, "Already added");
    jtoken_addresses.push(token);

    newtoken.name = name;
    newtoken.jusd_ratio = jusd_ratio;
    newtoken.markup_fee = markup_fee;
    newtoken.markup_fee_wallet = markup_fee_wallet;
    emit Add_JToken(token, name, jusd_ratio, markup_fee, markup_fee_wallet);
  }

  function delete_jtoken(address token) external onlyAjaxPrime {
    JToken storage jtoken = jtokens[token];
    jtoken.jusd_ratio = 0;
    uint jtoken_index;
    uint jtoken_count = jtoken_addresses.length;
    for(; jtoken_index < jtoken_count; jtoken_index += 1){
      if(jtoken_addresses[jtoken_index] == token)
      {
        if(jtoken_count > 1)
          jtoken_addresses[jtoken_index] = jtoken_addresses[jtoken_count-1];
        jtoken_addresses.pop();
        break;
      }
    }
    require(jtoken_index != jtoken_count, "Invalid JToken Address");
    emit Delete_JToken(token);
  }

  function check_price_bound(uint oldPrice, uint newPrice, uint percent) internal pure returns(bool) {
    return newPrice <= oldPrice * (100 + percent) / 100 
           && newPrice >= oldPrice * (100 - percent) / 100;
  }

  function set_jusd_jtoken_ratio(address token, uint jusd_ratio) external onlyOperator callLimit(uint(uint160(token)), 180) {
    JToken storage jtoken = jtokens[token];
    uint old_ratio = jtoken.jusd_ratio;
    require(check_price_bound(old_ratio, jusd_ratio, 3), "Out of 3% ratio change");
    jtoken.jusd_ratio = jusd_ratio;
    emit Set_Jusd_Jtoken_Ratio(token, old_ratio, jusd_ratio);
  }

  function set_use_wjxn_usd_dex_pair(uint flag) external onlyGovernor {
    use_wjxn_usd_dex_pair = flag;
    emit Set_Use_Wjxn_Usd_Dex_Pair(flag);
  }

  function set_use_wjax_usd_dex_pair(uint flag) external onlyGovernor {
    use_wjax_usd_dex_pair = flag;
    emit Set_Use_Wjax_Usd_Dex_Pair(flag);
  }

  function set_wjxn_usd_ratio(uint ratio) external onlyOperator callLimit(0x1, 180){
    require(wjxn_usd_ratio == 0 || check_price_bound(wjxn_usd_ratio, ratio, 10),
        "Out of 10% ratio change");
    wjxn_usd_ratio = ratio;
    emit Set_Wjxn_Usd_Ratio(ratio);
  }

  function set_wjax_usd_ratio(uint ratio) external onlyOperator callLimit(0x2, 180) {
    require(wjax_usd_ratio == 0 || check_price_bound(wjax_usd_ratio, ratio, 5), 
      "Out of 5% ratio change");
    wjax_usd_ratio = ratio;
    emit Set_Wjax_Usd_Ratio(ratio);
  }

  function get_wjxn_wjax_ratio(uint withdrawal_amount) public view returns (uint) {
    if( wjax.balanceOf(jaxSwap) == 0 ) return 1e8;
    if( wjxn.balanceOf(jaxSwap) == 0 ) return 0;
    return 1e8 * ((10 ** wjax.decimals()) * (wjxn.balanceOf(jaxSwap) - withdrawal_amount) 
        * get_wjxn_jusd_ratio()) / (wjax.balanceOf(jaxSwap) * get_wjax_jusd_ratio());
  }
  
  function get_wjxn_jusd_ratio() public view returns (uint){
    
    // Using manual ratio.
    if( use_wjxn_usd_dex_pair == 0 ) {
      return wjxn_usd_ratio;
    }

    return getPrice(address(wjxn), address(busd)); // return amount of token0 needed to buy token1
  }

  function get_wjxn_vrp_ratio() public view returns (uint wjxn_vrp_ratio) {
    if( vrp.totalSupply() == 0){
      wjxn_vrp_ratio = 1e8;
    }
    else if(wjxn.balanceOf(jaxSwap) == 0) {
      wjxn_vrp_ratio = 0;
    }
    else {
      wjxn_vrp_ratio = 1e8 * vrp.totalSupply() * (10 ** wjxn.decimals()) / wjxn.balanceOf(jaxSwap) / (10 ** vrp.decimals());
    }
  }
  
  function get_vrp_wjxn_ratio() public view returns (uint) {
    uint vrp_wjxn_ratio = 0;
    if(wjxn.balanceOf(jaxSwap) == 0 || vrp.totalSupply() == 0) {
        vrp_wjxn_ratio = 0;
    }
    else {
        vrp_wjxn_ratio = 1e8 * wjxn.balanceOf(jaxSwap) * (10 ** vrp.decimals()) / vrp.totalSupply() / (10 ** wjxn.decimals());
    }
    return (vrp_wjxn_ratio);
  }

  function get_wjax_jusd_ratio() public view returns (uint){
    // Using manual ratio.
    if( use_wjax_usd_dex_pair == 0 ) {
        return wjax_usd_ratio;
    }

    return getPrice(address(wjax), address(busd));
  }

  function get_jusd_wjax_ratio() public view returns (uint){
    return 1e8 * 1e8 / get_wjax_jusd_ratio();
  }

  function set_freeze_vrp_wjxn_swap(uint flag) external onlyGovernor {
    freeze_vrp_wjxn_swap = flag;
    emit Freeze_Vrp_Wjxn_Swap(flag);
  }

  function set_wjxn_wjax_collateralization_ratio(uint ratio) external onlyGovernor {
    wjxn_wjax_collateralization_ratio = ratio;
    emit Set_Wjxn_Wjax_Collateralization_Ratio(ratio);
  }

  function set_wjax_collateralization_ratio(uint ratio) external onlyGovernor {
    wjax_collateralization_ratio = ratio;
    emit Set_Wjax_Collateralization_Ratio(ratio);
  }

  function set_wjax_jusd_markup_fee(uint _wjax_jusd_markup_fee, address _wallet) external onlyGovernor {
    require(_wjax_jusd_markup_fee <= 25 * 1e5, "Markup fee must be less than 2.5%");
    wjax_jusd_markup_fee = _wjax_jusd_markup_fee;
    wjax_jusd_markup_fee_wallet = _wallet;
    emit Set_Wjax_Jusd_Markup_Fee(_wjax_jusd_markup_fee, _wallet);
  }

  function setPriceImpactLimit(uint limit) external onlyGovernor {
    require(limit <= 3e6, "price impact cannot be over 3%");
    priceImpactLimit = limit;
    emit Set_Price_Impact_Limit(limit);
  }

  // wjax_usd_value: decimal 8, lsc_usd_value decimal: 18
  function show_reserves() public view returns(uint, uint, uint){
    uint wjax_reserves = wjax.balanceOf(jaxSwap);

    uint wjax_usd_value = wjax_reserves * get_wjax_jusd_ratio() * (10 ** jusd.decimals()) / 1e8 / (10 ** wjax.decimals());
    uint lsc_usd_value = jusd.totalSupply();

    uint jtoken_count = jtoken_addresses.length;
    for(uint i = 0; i < jtoken_count; i++) {
      address addr = jtoken_addresses[i];
      lsc_usd_value += IERC20(addr).totalSupply() * 1e8 / jtokens[addr].jusd_ratio;
    }
    uint wjax_lsc_ratio = 1;
    if( lsc_usd_value > 0 ){
      wjax_lsc_ratio = wjax_usd_value * 1e8 / lsc_usd_value;
    }
    return (wjax_lsc_ratio, wjax_usd_value, lsc_usd_value);
  }
  // ------ end jaxSwap ------

  function getPrice(address token0, address token1) internal view returns(uint) {
    IPancakePair pair = IPancakePair(IPancakeFactory(router.factory()).getPair(token0, token1));
    (uint res0, uint res1,) = pair.getReserves();
    res0 *= 10 ** (18 - IERC20(pair.token0()).decimals());
    res1 *= 10 ** (18 - IERC20(pair.token1()).decimals());
    if(pair.token0() == token1) {
        if(res1 > 0)
            return 1e8 * res0 / res1;
    } 
    else {
        if(res0 > 0)
            return 1e8 * res1 / res0;
    }
    return 0;
  }
  
  function initialize(address pancakeRouter) public initializer {
    address sender = msg.sender;
    admin = sender;
    governor = sender;
    ajaxPrime = sender;
    // System state
    system_status = 2;
    owner = sender;
    router = IPancakeRouter01(pancakeRouter);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}
}

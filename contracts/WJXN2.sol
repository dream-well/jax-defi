// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./lib/BEP20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./JaxProtection.sol";


interface IJaxPlanet {

  struct Colony {
    uint128 level;
    uint128 transaction_tax;
    bytes32 _policy_hash;
    string _policy_link;
  }

  function ubi_tax_wallet() external view returns (address);
  function ubi_tax() external view returns (uint);
  function jaxcorp_dao_wallet() external view returns (address);
  function getMotherColonyAddress(address) external view returns(address);
  function getColony(address addr) external view returns(Colony memory);
  function getUserColonyAddress(address user) external view returns(address);
}

interface IJaxAdmin {
  
  function userIsAdmin (address _user) external view returns (bool);
  function userIsAjaxPrime (address _user) external view returns (bool);

  function jaxSwap() external view returns (address);
  function jaxPlanet() external view returns (address);

  function system_status() external view returns (uint);

  function blacklist(address _user) external view returns (bool);
  function fee_freelist(address _user) external view returns (bool);
} 

/**
* @title WJXN2
* @dev Implementation of WJXN with mint function and 8 decimals.
*/
contract WJXN2 is BEP20, JaxProtection {
  
  using SafeERC20 for IERC20;

  IJaxAdmin public jaxAdmin;
  IERC20 wjxn = IERC20(0xcA1262e77Fb25c0a4112CFc9bad3ff54F617f2e6);
  address[] public gateKeepers;

  // transaction fee
  uint public transaction_fee = 0;
  uint public transaction_fee_cap = 0;

  uint public referral_fee = 0;
  uint public referrer_amount_threshold = 0;
  uint public cashback = 0; // Cashback has 8 decimals

  bool public fee_disabled = false;

  struct Colony {
    uint128 level;
    uint128 transaction_tax;
    bytes32 _policy_hash;
    string _policy_link;
  }

  address public tx_fee_wallet;
  
  mapping (address => address) public referrers;

  struct GateKeeper {
    uint mintLimit;
  }

  mapping (address => GateKeeper) gateKeeperInfo;

  event Set_Jax_Admin(address jax_admin);
  event Set_Gate_Keepers(address[] gate_keepers);
  event Set_Mint_Limit(address gateKeeper, uint mintLimit);
  event Set_Transaction_Fee(uint transaction_fee, uint trasnaction_fee_cap, address transaction_fee_wallet);
  event Set_Referral_Fee(uint referral_fee, uint referral_amount_threshold);
  event Set_Cashback(uint cashback_percent);
  event Disable_Fees(bool flag);

  /**
    * @dev Sets the value of the `cap`. This value is immutable, it can only be
    * set once during construction.
    */
    
  constructor ()
      BEP20("Wrapped JAXNET 2", "WJXN-2")
  {
      _setupDecimals(8);
      tx_fee_wallet = msg.sender;
  }

  modifier onlyJaxAdmin() {
    require(msg.sender == address(jaxAdmin), "Only JaxAdmin Contract");
    _;
  }

  modifier onlyAjaxPrime() {
    require(jaxAdmin.userIsAjaxPrime(msg.sender) || msg.sender == owner(), "Only AjaxPrime can perform this operation.");
    _;
  }

  modifier onlyGateKeeper(address account) {
    uint cnt = gateKeepers.length;
    uint index = 0;
    for(; index < cnt; index += 1) {
      if(gateKeepers[index] == account)
        break;
    }
    require(index < cnt, "Only GateKeeper can perform this action");
    _;
  }

  
  modifier notFrozen() {
    require(jaxAdmin.system_status() > 0, "Transactions have been frozen.");
    _;
  }

  function setJaxAdmin(address newJaxAdmin) external onlyOwner {
    jaxAdmin = IJaxAdmin(newJaxAdmin);  
    emit Set_Jax_Admin(newJaxAdmin);
  }

  function setGateKeepers(address[] calldata newGateKeepers) external onlyAjaxPrime runProtection {
    uint cnt = newGateKeepers.length;
    delete gateKeepers;
    for(uint index = 0; index < cnt; index += 1) {
      gateKeepers.push(newGateKeepers[index]);
    }
    emit Set_Gate_Keepers(newGateKeepers);
  }

  function setMintLimit(address gateKeeper, uint mintLimit) external onlyAjaxPrime onlyGateKeeper(gateKeeper) runProtection {
    GateKeeper storage info = gateKeeperInfo[gateKeeper];
    info.mintLimit = mintLimit;
    emit Set_Mint_Limit(gateKeeper, mintLimit);
  }

  function setTransactionFee(uint txFee, uint txFeeCap, address wallet) external onlyJaxAdmin {
      require(txFee <= 1e8 * 3 / 100 , "Tx Fee percent can't be more than 3.");
      require(wallet != address(0x0), "Only non-zero address");
      transaction_fee = txFee;
      transaction_fee_cap = txFeeCap;
      tx_fee_wallet = wallet;
      emit Set_Transaction_Fee(txFee, txFeeCap, wallet);
  }

  /**
    * @dev Set referral fee and minimum amount that can set sender as referrer
    */
  function setReferralFee(uint newReferralFee, uint newReferrerAmountThreshold) external onlyJaxAdmin {
      require(newReferralFee <= 1e8 * 50 / 100 , "Referral Fee percent can't be more than 50.");
      referral_fee = newReferralFee;
      referrer_amount_threshold = newReferrerAmountThreshold;
      emit Set_Referral_Fee(newReferralFee, newReferrerAmountThreshold);
  }

  /**
    * @dev Set cashback
    */
  function setCashback(uint newCashback) external onlyJaxAdmin {
      require(newCashback <= 1e8 * 30 / 100 , "Cashback percent can't be more than 30.");
      cashback = newCashback; // Cashback has 8 decimals
      emit Set_Cashback(newCashback);
  }

  function transfer(address recipient, uint amount) public override(BEP20) notFrozen returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  } 

  function transferFrom(address sender, address recipient, uint amount) public override(BEP20) notFrozen returns (bool) {
    _transfer(sender, recipient, amount);
    uint currentAllowance = allowance(sender, msg.sender);
    require(currentAllowance >= amount, "BEP20: transfer amount exceeds allowance");
    _approve(sender, msg.sender, currentAllowance - amount);
    return true;
  } 

  function _transfer(address sender, address recipient, uint amount) internal override(BEP20) {
    require(!jaxAdmin.blacklist(sender), "sender is blacklisted");
    require(!jaxAdmin.blacklist(recipient), "recipient is blacklisted");
    if(amount == 0) return;
    if(jaxAdmin.fee_freelist(msg.sender) || jaxAdmin.fee_freelist(recipient) || fee_disabled) {
        return super._transfer(sender, recipient, amount);
    }
    if(referrers[sender] == address(0)) {
        referrers[sender] = address(0xdEaD);
    }

    // Calculation of transaction fee
    uint tx_fee_amount = amount * transaction_fee / 1e8;

    if(tx_fee_amount > transaction_fee_cap) {
        tx_fee_amount = transaction_fee_cap;
    }
    
    address referrer = referrers[recipient];
    uint totalreferral_fees = 0;
    uint maxreferral_fee = tx_fee_amount * referral_fee;

    IJaxPlanet jaxPlanet = IJaxPlanet(jaxAdmin.jaxPlanet());
    
    // Calculation of UBI amount       
    uint ubi_tax_amount = amount * jaxPlanet.ubi_tax() / 1e8;

    address colony_address = jaxPlanet.getUserColonyAddress(recipient);

    if(colony_address == address(0)) {
        colony_address = jaxPlanet.getMotherColonyAddress(recipient);
    }
    
    // Transfer transaction tax to colonies.
    // immediate colony will get 50% of transaction tax, mother of that colony will get 25% ... mother of 4th colony will get 3.125%
    // 3.125% of transaction tax will go to JaxCorp Dao public key address.
    uint tx_tax_amount = amount * jaxPlanet.getColony(colony_address).transaction_tax / 1e8;     // Calculate transaction tax amount
   
    // Transfer tokens to recipient. recipient will pay the fees.
    require( amount > (tx_fee_amount + ubi_tax_amount + tx_tax_amount), "Total fee is greater than the transfer amount");
    super._transfer(sender, recipient, amount - tx_fee_amount - ubi_tax_amount - tx_tax_amount);

    // Transfer transaction fee to transaction fee wallet
    // Sender will get cashback.
    if( tx_fee_amount > 0){
        uint cashback_amount = (tx_fee_amount * cashback / 1e8);
        if(cashback_amount > 0)
          super._transfer(sender, sender, cashback_amount);
        
        // Transfer referral fees to referrers (70% to first referrer, each 10% to other referrers)
        if( maxreferral_fee > 0 && referrer != address(0xdEaD) && referrer != address(0)){

            super._transfer(sender, referrer, 70 * maxreferral_fee / 1e8 / 100);
            referrer = referrers[referrer];
            totalreferral_fees += 70 * maxreferral_fee / 1e8 / 100;
            if( referrer != address(0xdEaD) && referrer != address(0)){
                super._transfer(sender, referrer, 10 * maxreferral_fee / 1e8 / 100);
                referrer = referrers[referrer];
                totalreferral_fees += 10 * maxreferral_fee / 1e8 / 100;
                if( referrer != address(0xdEaD) && referrer != address(0)){
                    super._transfer(sender, referrer, 10 * maxreferral_fee / 1e8 / 100);
                    referrer = referrers[referrer];
                    totalreferral_fees += 10 * maxreferral_fee / 1e8 / 100;
                    if( referrer != address(0xdEaD) && referrer != address(0)){
                        super._transfer(sender, referrer, 10 * maxreferral_fee / 1e8 / 100);
                        referrer = referrers[referrer];
                        totalreferral_fees += 10 * maxreferral_fee / 1e8 / 100;
                    }
                }
            }
        }
        super._transfer(sender, tx_fee_wallet, tx_fee_amount - totalreferral_fees - cashback_amount);
    }
    
    if(ubi_tax_amount > 0){
        super._transfer(sender, jaxPlanet.ubi_tax_wallet(), ubi_tax_amount);  // ubi tax
    }
     
    // transferTransactionTax(mother_colony_addresses[recipient], tx_tax_amount, 1);          
    // Transfer tax to colonies and jaxCorp Dao
    // Optimize transferTransactionTax by using loop instead of recursive function

    if( tx_tax_amount > 0 ){
        uint level = 1;
        uint tx_tax_temp = tx_tax_amount;
        
        // Level is limited to 5
        while( colony_address != address(0) && level++ <= 5 ){
            super._transfer(sender, colony_address, tx_tax_temp / 2);
            colony_address = jaxPlanet.getMotherColonyAddress(colony_address);
            tx_tax_temp = tx_tax_temp / 2;            
        }

        // transfer remain tx_tax to jaxcorpDao
        super._transfer(sender, jaxPlanet.jaxcorp_dao_wallet(), tx_tax_temp);
    }


    // set referrers as first sender when transferred amount exceeds the certain limit.
    // recipient mustn't be sender's referrer, recipient couldn't be referrer itself
    if( recipient != sender  && amount >= referrer_amount_threshold  && referrers[recipient] == address(0)) {
        referrers[recipient] = sender;

    }
  }

  function mint(address account, uint amount) external notFrozen onlyGateKeeper(msg.sender) {
    require(!jaxAdmin.blacklist(account), "account is blacklisted");
    GateKeeper storage gateKeeper = gateKeeperInfo[msg.sender];
    require(gateKeeper.mintLimit >= amount, "Mint amount exceeds limit");
    super._mint(account, amount);
    gateKeeper.mintLimit -= amount;
  }

  function swapWjxnToWjxn2(uint amountIn) external {
    wjxn.safeTransferFrom(msg.sender, address(this), amountIn);
    super._mint(msg.sender, amountIn * (10 ** decimals()));
  }

  function swapWjxn2ToWjxn(uint amountOut) external {
    super._burn(msg.sender, amountOut * (10 ** decimals()));
    wjxn.safeTransfer(msg.sender, amountOut);
  }

  function disableFees(bool flag) external onlyAjaxPrime runProtection {
    fee_disabled = flag;
    emit Disable_Fees(flag);
  }
}
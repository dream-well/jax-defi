
 // SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

contract JaxOwnable {

  address public owner;
  address public new_owner;
  uint public new_owner_locktime;
  
  event Set_New_Owner(address newOwner, uint newOwnerLocktime);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  modifier onlyOwner() {
      require(owner == msg.sender, "JaxOwnable: caller is not the owner");
      _;
  }

  function setNewOwner(address newOwner) external onlyOwner {
    new_owner = newOwner;
    new_owner_locktime = block.timestamp + 48 hours;
    emit Set_New_Owner(newOwner, new_owner_locktime);
  }

  function updateOwner(address newOwner) external onlyOwner {
    require(newOwner != address(0), "new owner is the zero address");
    require(block.timestamp >= new_owner_locktime, "New admin is not unlocked yet");
    _transferOwnership(newOwner);
  }

  function renounceOwnership() external onlyOwner {
    _transferOwnership(address(0));
  }

  /**
  * @dev Transfers ownership of the contract to a new account (`newOwner`).
  * Internal function without access restriction.
  */
  function _transferOwnership(address newOwner) internal virtual {
    address oldOwner = owner;
    owner = newOwner;
    emit OwnershipTransferred(oldOwner, newOwner);
  }
}
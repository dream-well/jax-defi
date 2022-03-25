
 // SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

contract JaxProtection {

    struct RunProtection {
        bytes32 data_hash;
        uint64 request_timestamp;
        address sender;
        bool executed;
    }

    mapping(bytes4 => RunProtection) run_protection_info;

    event Request_Update(bytes4 sig, bytes data);

    modifier runProtection() {
        RunProtection storage protection = run_protection_info[msg.sig];
        bytes32 data_hash = keccak256(msg.data);
        if(data_hash != protection.data_hash || protection.sender != msg.sender) {
        protection.sender = msg.sender;
        protection.data_hash = keccak256(msg.data);
            protection.request_timestamp = uint64(block.timestamp);
            protection.executed = false;
            emit Request_Update(msg.sig, msg.data);
            return;
        }
        require(protection.executed == false, "Already executed");
        require(block.timestamp >= uint(protection.request_timestamp) + 2 days, "Running is Locked");
        _;
        protection.executed = true;
    }
}
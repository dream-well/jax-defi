// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interface/IERC20.sol";

contract Ubi is Initializable {

    event Set_Ajax_Prime(address oldAjaxPrime, address newAjaxPrime);
    event Set_Reward_Token(address rewardToken);
    event Register(address user);
    event Accept_User(address user, uint idHash, string remarks);
    event Reject_User(address user, string remarks);
    event Collect_UBI(address indexed user, uint amount);
    event Deposit_Reward(uint amount);
    event Set_Minimum_Reward_Per_Person(uint amount);
    event Set_Verifiers(address[] verifiers);
    event Set_Verifier_Limit(address verifier, uint limit);

    address public ajaxPrime;
    address public rewardToken;

    enum Status { Init, Pending, Approved, Rejected }

    struct UserInfo {
        uint harvestedReward;
        uint idHash;
        Status status;
        string remarks;
    }

    uint public totalRewardPerPerson;
    uint public userCount;
    uint public minimumRewardPerPerson;

    mapping(address => UserInfo) public userInfo;
    mapping(address => uint) public verifierLimitInfo;
    address[] public verifiers;
    mapping(uint => address) public idHashInfo;


    modifier onlyAjaxPrime() {
        require(msg.sender == ajaxPrime, "Only Admin");
        _;
    }

    modifier onlyVerifier() {
        uint verifierCnt = verifiers.length;
        uint index;
        for(; index < verifierCnt; index += 1) {
            if(verifiers[index] == msg.sender){
                break;
            }
        }
        require(index < verifierCnt, "Only Verifier");
        require(verifierLimitInfo[msg.sender] > 0, "Operating limit reached");
        _;
        verifierLimitInfo[msg.sender] -= 1;
    }

    function setVerifiers (address[] calldata _verifiers) external onlyAjaxPrime {
        uint verifiersCnt = _verifiers.length;
        delete verifiers;
        for(uint index; index < verifiersCnt; index += 1 ) {
            verifiers.push(_verifiers[index]);
        }
        emit Set_Verifiers(_verifiers);
    }

    function setVerifierLimit(address verifier, uint limit) external onlyAjaxPrime {
        verifierLimitInfo[verifier] = limit;
        emit Set_Verifier_Limit(verifier, limit);
    }

    function set_reward_token(address _rewardToken) external onlyAjaxPrime {
        rewardToken = _rewardToken;
        emit Set_Reward_Token(_rewardToken);
    }

    function set_minimum_reward_per_person(uint amount) external onlyAjaxPrime {
        minimumRewardPerPerson = amount;
        emit Set_Minimum_Reward_Per_Person(amount);
    }

    function deposit_reward(uint amount) external {
        require(userCount > 0, "No valid users in UBI");
        uint rewardPerPerson = amount / userCount;
        require(rewardPerPerson >= minimumRewardPerPerson, "Reward is too small");
        IERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
        totalRewardPerPerson += rewardPerPerson;
        emit Deposit_Reward(amount);
    }

    function collect_ubi() external {
        UserInfo storage info = userInfo[msg.sender];
        require(info.status == Status.Approved, "You are not approved");
        uint reward = totalRewardPerPerson - info.harvestedReward;
        require(reward > 0, "Nothing to harvest");
        IERC20(rewardToken).transfer(msg.sender, reward);
        info.harvestedReward = totalRewardPerPerson;
        emit Collect_UBI(msg.sender, reward);
    }

    function approveUser(address user, uint idHash, string calldata remarks) external onlyVerifier {
        UserInfo storage info = userInfo[user];
        require(info.status != Status.Init, "User is not registered");
        require(info.status != Status.Approved, "Already approved");
        require(idHashInfo[idHash] == address(0), "Id hash should be unique");
        if(info.status != Status.Approved) {
            userCount += 1;
            info.harvestedReward = totalRewardPerPerson;
        }
        info.idHash = idHash;
        info.remarks = remarks;
        info.status = Status.Approved;
        idHashInfo[idHash] = user;
        emit Accept_User(user, idHash, remarks);
    }

    function rejectUser(address user, string calldata remarks) external onlyVerifier {
        UserInfo storage info = userInfo[user];
        require(info.status != Status.Init, "User is not registered");
        if(info.status == Status.Approved) {
            userCount -= 1;
        }
        info.status = Status.Rejected;
        idHashInfo[info.idHash] = address(0);
        info.remarks = remarks;
        emit Reject_User(user, remarks);
    }

    function register() external {
        UserInfo storage info = userInfo[msg.sender];
        require(info.status == Status.Init, "You already registered");
        userInfo[msg.sender].status = Status.Pending;
        emit Register(msg.sender);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _ajaxPrime, address _rewardToken) external initializer {
        ajaxPrime = _ajaxPrime;
        rewardToken = _rewardToken;
    }

    function set_ajax_prime(address newAjaxPrime) external onlyAjaxPrime {
        address oldAjaxPrime = ajaxPrime;
        ajaxPrime = newAjaxPrime;
        emit Set_Ajax_Prime(oldAjaxPrime, newAjaxPrime);
    }

    function withdrawByAdmin(address token, uint amount) external onlyAjaxPrime {
        IERC20(token).transfer(msg.sender, amount);
    }
}

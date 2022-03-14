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
    event Change_My_JaxCorp_Governor(address jaxCorp_governor);
    event Collect_UBI(address indexed user, uint collect_id, uint amount);
    event Release_Collect(address indexed user, uint collect_id, uint amount);
    event Unlock_Collect(address indexed user, uint collect_id, address jaxCorp_governor);
    event Deposit_Reward(uint amount);
    event Set_Minimum_Reward_Per_Person(uint amount);
    event Set_JaxCorp_Governors(address[] jaxCorp_governors);
    event Set_JaxCorp_Governor_Limit(address jaxCorp_governor, uint limit);
    event Set_Locktime(uint locktime);
    event Set_Major_Ajax_Prime_Nominee(address ajaxPrimeNominee);

    address public ajaxPrime;
    address public rewardToken;

    enum Status { Init, Pending, Approved, Rejected }

    struct CollectInfo {
        uint amount;
        uint64 collect_timestamp;
        uint64 unlock_timestamp;
        uint64 release_timestamp;
    }

    struct UserInfo {
        uint harvestedReward;
        uint collectedReward;
        uint releasedReward;
        uint idHash;
        address jaxCorp_governor;
        Status status;
        string remarks;
        CollectInfo[] collects;
    }

    uint public totalRewardPerPerson;
    uint public userCount;
    uint public minimumRewardPerPerson;

    uint public locktime;

    address public majorAjaxPrimeNominee;

    mapping(address => UserInfo) userInfo;
    mapping(address => uint) public jaxCorpGovernorLimitInfo;
    address[] public jaxCorp_governors;
    mapping(uint => address) public idHashInfo;
    mapping(address => uint) public voteCountInfo;
    mapping(address => address) public ajaxPrimeNomineeInfo;

    modifier onlyAjaxPrime() {
        require(msg.sender == ajaxPrime, "Only Admin");
        _;
    }

    modifier onlyJaxCorpGovernor() {
        require(isJaxCorpGovernor(msg.sender), "Only Governor");
        require(jaxCorpGovernorLimitInfo[msg.sender] > 0, "Operating limit reached");
        _;
        jaxCorpGovernorLimitInfo[msg.sender] -= 1;
    }

    
  modifier checkZeroAddress(address account) {
    require(account != address(0x0), "Only non-zero address");
    _;
  }

    function get_user_info(address account) external view returns(Status status, uint idHash, uint collectedReward, uint releasedReward, uint collect_count, uint release_count, address jaxCorp_governor, string memory remarks) {
        UserInfo memory user = userInfo[account];
        status = user.status;
        idHash = user.idHash;
        collectedReward = user.collectedReward;
        releasedReward = user.releasedReward;
        collect_count = user.collects.length;
        jaxCorp_governor = user.jaxCorp_governor;
        for(uint i = 0; i < user.collects.length; i += 1) {
            if(user.collects[i].release_timestamp>0)
                release_count += 1;
        }
        remarks = user.remarks;
    }

    function get_collect_info(address account) external view returns(CollectInfo[] memory) {
        return userInfo[account].collects;
    }

    function isJaxCorpGovernor(address jaxCorp_governor) public view returns (bool) {
        uint jaxCorp_governorCnt = jaxCorp_governors.length;
        uint index = 0;
        for(index; index < jaxCorp_governorCnt; index += 1) {
            if(jaxCorp_governors[index] == jaxCorp_governor){
                return true;
            }
        }
        return false;
    }

    function setGovernors (address[] calldata _jaxCorp_governors) external onlyAjaxPrime {
        uint jaxCorp_governorsCnt = _jaxCorp_governors.length;
        delete jaxCorp_governors;
        for(uint index = 0; index < jaxCorp_governorsCnt; index += 1 ) {
            jaxCorp_governors.push(_jaxCorp_governors[index]);
        }
        emit Set_JaxCorp_Governors(_jaxCorp_governors);
    }

    function setGovernorLimit(address jaxCorp_governor, uint limit) external onlyAjaxPrime {
        jaxCorpGovernorLimitInfo[jaxCorp_governor] = limit;
        emit Set_JaxCorp_Governor_Limit(jaxCorp_governor, limit);
    }

    function set_reward_token(address _rewardToken) external checkZeroAddress(_rewardToken) onlyAjaxPrime {
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
        info.harvestedReward = totalRewardPerPerson;
        info.collectedReward += reward;
        CollectInfo memory collect;
        collect.collect_timestamp = uint64(block.timestamp);
        collect.unlock_timestamp = uint64(block.timestamp + locktime);
        collect.amount = reward;
        info.collects.push(collect);
        emit Collect_UBI(msg.sender, info.collects.length - 1, reward);
        if(locktime == 0) {
            _release_collect(msg.sender, info.collects.length - 1);
        }
    }

    function unlock_collect(address user, uint collect_id) external onlyJaxCorpGovernor {
        UserInfo storage info = userInfo[user];
        require(info.jaxCorp_governor == msg.sender, "Invalid jaxCorp_governor");
        require(info.collects.length > collect_id, "Invalid collect_id");
        CollectInfo storage collect = info.collects[collect_id];
        require(collect.release_timestamp == 0, "Already released");
        require(uint(collect.unlock_timestamp) > block.timestamp, "Already unlocked");
        collect.unlock_timestamp = uint64(block.timestamp);
        emit Unlock_Collect(user, collect_id, msg.sender);
        _release_collect(user, collect_id);
    }

    function _release_collect(address user, uint collect_id) internal {
        UserInfo storage info = userInfo[user];
        require(info.collects.length > collect_id, "Invalid collect_id");
        CollectInfo storage collect = info.collects[collect_id];
        require(collect.release_timestamp == 0, "Already released");
        require(uint(collect.unlock_timestamp) <= block.timestamp, "Locked");
        collect.release_timestamp = uint64(block.timestamp);
        info.releasedReward += collect.amount;
        IERC20(rewardToken).transfer(user, collect.amount);
        emit Release_Collect(user, collect_id, collect.amount);
    }

    function release_collect(uint collect_id) public {
        _release_collect(msg.sender, collect_id);
    }

    function approveUser(address user, uint idHash, string calldata remarks) external onlyJaxCorpGovernor {
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
        info.jaxCorp_governor = msg.sender;
        info.status = Status.Approved;
        idHashInfo[idHash] = user;
        emit Accept_User(user, idHash, remarks);
    }

    function rejectUser(address user, string calldata remarks) external onlyJaxCorpGovernor {
        UserInfo storage info = userInfo[user];
        require(info.status != Status.Init, "User is not registered");
        if(info.status == Status.Approved) {
            userCount -= 1;
            address ajaxPrimeNominee = ajaxPrimeNomineeInfo[user];
            if(ajaxPrimeNomineeInfo[user] != address(0)) {
                voteCountInfo[ajaxPrimeNominee] -= 1;
                ajaxPrimeNomineeInfo[user] = address(0);
                check_major_ajax_prime_nominee(ajaxPrimeNominee);
            }
        }
        info.status = Status.Rejected;
        idHashInfo[info.idHash] = address(0);
        info.remarks = remarks;
        emit Reject_User(user, remarks);
    }

    function changeMyJaxCorpGovernor(address jaxCorp_governor) external {
        UserInfo storage info = userInfo[msg.sender];
        require(info.status == Status.Approved, "You are not approved");
        require(isJaxCorpGovernor(jaxCorp_governor), "Only valid jaxCorp_governor");
        info.jaxCorp_governor = jaxCorp_governor;
        emit Change_My_JaxCorp_Governor(jaxCorp_governor);
    }

    function register() external {
        UserInfo storage info = userInfo[msg.sender];
        require(info.status == Status.Init, "You already registered");
        info.status = Status.Pending;
        emit Register(msg.sender);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _ajaxPrime, address _rewardToken, uint _locktime) external initializer 
     checkZeroAddress(_ajaxPrime) checkZeroAddress(_rewardToken)
    {
        ajaxPrime = _ajaxPrime;
        rewardToken = _rewardToken;
        locktime = _locktime;
    }

    function set_ajax_prime(address newAjaxPrime) external checkZeroAddress(newAjaxPrime) onlyAjaxPrime {
        address oldAjaxPrime = ajaxPrime;
        ajaxPrime = newAjaxPrime;
        emit Set_Ajax_Prime(oldAjaxPrime, newAjaxPrime);
    }

    function set_ajax_prime_nominee(address ajaxPrimeNominee) external {
        require(ajaxPrimeNominee != address(0), "AjaxPrimeNominee should not be zero address");
        UserInfo memory info = userInfo[msg.sender];
        require(info.status == Status.Approved, "You are not approved");
        address old_ajaxPrimeNominee = ajaxPrimeNomineeInfo[msg.sender];
        require(old_ajaxPrimeNominee != ajaxPrimeNominee, "Voted already");
        if(old_ajaxPrimeNominee != address(0)) {
            voteCountInfo[old_ajaxPrimeNominee] -= 1;
        }
        ajaxPrimeNomineeInfo[msg.sender] = ajaxPrimeNominee;
        voteCountInfo[ajaxPrimeNominee] += 1;
        check_major_ajax_prime_nominee(ajaxPrimeNominee);
    }

    function check_major_ajax_prime_nominee(address ajaxPrimeNominee) public {
        if(voteCountInfo[ajaxPrimeNominee] > userCount / 2){
            majorAjaxPrimeNominee = ajaxPrimeNominee;
            emit Set_Major_Ajax_Prime_Nominee(ajaxPrimeNominee);
        }
        else if(voteCountInfo[majorAjaxPrimeNominee] <= userCount / 2){
            majorAjaxPrimeNominee = address(0);
            emit Set_Major_Ajax_Prime_Nominee(address(0));
        }
    }

    function set_locktime(uint _locktime) external onlyAjaxPrime {
        locktime = _locktime;
        emit Set_Locktime(_locktime);
    }

    function withdrawByAdmin(address token, uint amount) external onlyAjaxPrime {
        IERC20(token).transfer(msg.sender, amount);
    }
}

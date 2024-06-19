pragma solidity ^0.8.11;import "@openzeppelin/contracts/token/ERC20/IERC20.sol";import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";import "@openzeppelin/contracts/security/ReentrancyGuard.sol";import "@openzeppelin/contracts/security/Pausable.sol";import "@openzeppelin/contracts/access/Ownable.sol";import "./MasterChef.sol";contract StakingRewards is Ownable, ReentrancyGuard, Pausable {using SafeERC20 for IERC20;MasterChef public immutable masterChef;IERC20 public rewardsToken;IERC20 public stakingToken;uint256 public periodFinish = 0;uint256 public rewardRate = 0;uint256 public rewardsDuration = 7 days;uint256 public lastUpdateTime;uint256 public rewardPerTokenStored;mapping(address => uint256) public userRewardPerTokenPaid;mapping(address => uint256) public rewards;uint256 private _totalSupply;mapping(address => uint256) private _balances;address public rewardsDistribution;constructor(address _rewardsDistribution,address _rewardsToken,address _stakingToken,MasterChef _masterChef) {rewardsToken = IERC20(_rewardsToken);stakingToken = IERC20(_stakingToken);rewardsDistribution = _rewardsDistribution;masterChef = _masterChef;}function totalSupply() external view returns (uint256) {return _totalSupply;}function balanceOf(address account) external view returns (uint256) {return _balances[account];}function lastTimeRewardApplicable() public view returns (uint256) {return block.timestamp < periodFinish ? block.timestamp : periodFinish;}function rewardPerToken() public view returns (uint256) {if (_totalSupply == 0) {return rewardPerTokenStored;}returnrewardPerTokenStored +(((lastTimeRewardApplicable() - lastUpdateTime) *rewardRate *1e18) / _totalSupply);}function earned(address account) public view returns (uint256) {return(_balances[account] *(rewardPerToken() - userRewardPerTokenPaid[account])) /1e18 +rewards[account];}function getRewardForDuration() external view returns (uint256) {return rewardRate * rewardsDuration;}function stake(uint256 amount)externalnonReentrantwhenNotPausedupdateReward(msg.sender){require(amount > 0, "Cannot stake 0");_totalSupply += amount;_balances[msg.sender] += amount;stakingToken.safeTransferFrom(msg.sender, address(this), amount);uint256 pid = masterChef.pid(address(stakingToken));masterChef.deposit(msg.sender, pid, amount);emit Staked(msg.sender, amount);}function withdraw(uint256 amount)publicnonReentrantupdateReward(msg.sender){require(amount > 0, "Cannot withdraw 0");_totalSupply -= amount;_balances[msg.sender] -= amount;stakingToken.safeTransfer(msg.sender, amount);uint256 pid = masterChef.pid(address(stakingToken));masterChef.withdraw(msg.sender, pid, amount);emit Withdrawn(msg.sender, amount);}function getReward() public nonReentrant updateReward(msg.sender) {uint256 reward = rewards[msg.sender];if (reward > 0) {rewards[msg.sender] = 0;rewardsToken.safeTransfer(msg.sender, reward);emit RewardPaid(msg.sender, reward);}}function exit() external {withdraw(_balances[msg.sender]);getReward();}function notifyRewardAmount(uint256 reward)externalupdateReward(address(0)){require(msg.sender == rewardsDistribution,"Caller is not RewardsDistribution contract");if (block.timestamp >= periodFinish) {rewardRate = reward / rewardsDuration;} else {uint256 remaining = periodFinish - block.timestamp;uint256 leftover = remaining * rewardRate;rewardRate = (reward + leftover) / rewardsDuration;}uint256 balance = rewardsToken.balanceOf(address(this));require(rewardRate <= balance / rewardsDuration,"Provided reward too high");lastUpdateTime = block.timestamp;periodFinish = block.timestamp + rewardsDuration;emit RewardAdded(reward);}function recoverERC20(address tokenAddress, uint256 tokenAmount)externalonlyOwner{require(tokenAddress != address(stakingToken),"Cannot withdraw the staking token");IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);emit Recovered(tokenAddress, tokenAmount);}function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {require(block.timestamp > periodFinish,"Previous rewards period must be complete before changing the duration for the new period");rewardsDuration = _rewardsDuration;emit RewardsDurationUpdated(rewardsDuration);}function setRewardsDistribution(address _rewardsDistribution)externalonlyOwner{require(block.timestamp > periodFinish,"Previous rewards period must be complete before changing the duration for the new period");rewardsDistribution = _rewardsDistribution;emit RewardsDistributionUpdated(rewardsDistribution);}modifier updateReward(address account) {rewardPerTokenStored = rewardPerToken();lastUpdateTime = lastTimeRewardApplicable();if (account != address(0)) {rewards[account] = earned(account);userRewardPerTokenPaid[account] = rewardPerTokenStored;}_;}event RewardAdded(uint256 reward);event Staked(address indexed user, uint256 amount);event Withdrawn(address indexed user, uint256 amount);event RewardPaid(address indexed user, uint256 reward);event RewardsDurationUpdated(uint256 newDuration);event RewardsDistributionUpdated(address indexed newDistribution);event Recovered(address token, uint256 amount);}
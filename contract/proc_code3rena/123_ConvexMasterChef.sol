pragma solidity 0.6.12;import "@openzeppelin/contracts-0.6/math/SafeMath.sol";import "@openzeppelin/contracts-0.6/token/ERC20/IERC20.sol";import "@openzeppelin/contracts-0.6/token/ERC20/SafeERC20.sol";import "@openzeppelin/contracts-0.6/utils/Context.sol";import "@openzeppelin/contracts-0.6/access/Ownable.sol";import "./interfaces/IRewarder.sol";contract ConvexMasterChef is Ownable {using SafeMath for uint256;using SafeERC20 for IERC20;struct UserInfo {uint256 amount;uint256 rewardDebt;}struct PoolInfo {IERC20 lpToken;uint256 allocPoint;uint256 lastRewardBlock;uint256 accCvxPerShare;IRewarder rewarder;}IERC20 public immutable cvx;uint256 public immutable rewardPerBlock;uint256 public constant BONUS_MULTIPLIER = 2;PoolInfo[] public poolInfo;mapping(uint256 => mapping(address => UserInfo)) public userInfo;uint256 public totalAllocPoint = 0;uint256 public immutable startBlock;uint256 public immutable endBlock;event Deposit(address indexed user, uint256 indexed pid, uint256 amount);event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);event RewardPaid(address indexed user, uint256 indexed pid, uint256 amount);event EmergencyWithdraw(address indexed user,uint256 indexed pid,uint256 amount);constructor(IERC20 _cvx,uint256 _rewardPerBlock,uint256 _startBlock,uint256 _endBlock) public {cvx = _cvx;rewardPerBlock = _rewardPerBlock;startBlock = _startBlock;endBlock = _endBlock;}function poolLength() external view returns (uint256) {return poolInfo.length;}function add(uint256 _allocPoint,IERC20 _lpToken,IRewarder _rewarder,bool _withUpdate) public onlyOwner {if (_withUpdate) {massUpdatePools();}uint256 lastRewardBlock = block.number > startBlock? block.number: startBlock;totalAllocPoint = totalAllocPoint.add(_allocPoint);poolInfo.push(PoolInfo({lpToken: _lpToken,allocPoint: _allocPoint,lastRewardBlock: lastRewardBlock,accCvxPerShare: 0,rewarder: _rewarder}));}function set(uint256 _pid,uint256 _allocPoint,IRewarder _rewarder,bool _withUpdate,bool _updateRewarder) public onlyOwner {if (_withUpdate) {massUpdatePools();}totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);poolInfo[_pid].allocPoint = _allocPoint;if(_updateRewarder){poolInfo[_pid].rewarder = _rewarder;}}function getMultiplier(uint256 _from, uint256 _to)publicviewreturns (uint256){uint256 clampedTo = _to > endBlock ? endBlock : _to;uint256 clampedFrom = _from > endBlock ? endBlock : _from;return clampedTo.sub(clampedFrom);}function pendingCvx(uint256 _pid, address _user)externalviewreturns (uint256){PoolInfo storage pool = poolInfo[_pid];UserInfo storage user = userInfo[_pid][_user];uint256 accCvxPerShare = pool.accCvxPerShare;uint256 lpSupply = pool.lpToken.balanceOf(address(this));if (block.number > pool.lastRewardBlock && lpSupply != 0) {uint256 multiplier = getMultiplier(pool.lastRewardBlock,block.number);uint256 cvxReward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);accCvxPerShare = accCvxPerShare.add(cvxReward.mul(1e12).div(lpSupply));}return user.amount.mul(accCvxPerShare).div(1e12).sub(user.rewardDebt);}function massUpdatePools() public {uint256 length = poolInfo.length;for (uint256 pid = 0; pid < length; ++pid) {updatePool(pid);}}function updatePool(uint256 _pid) public {PoolInfo storage pool = poolInfo[_pid];if (block.number <= pool.lastRewardBlock) {return;}uint256 lpSupply = pool.lpToken.balanceOf(address(this));if (lpSupply == 0) {pool.lastRewardBlock = block.number;return;}uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);uint256 cvxReward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);pool.accCvxPerShare = pool.accCvxPerShare.add(cvxReward.mul(1e12).div(lpSupply));pool.lastRewardBlock = block.number;}function deposit(uint256 _pid, uint256 _amount) public {PoolInfo storage pool = poolInfo[_pid];UserInfo storage user = userInfo[_pid][msg.sender];updatePool(_pid);if (user.amount > 0) {uint256 pending = user.amount.mul(pool.accCvxPerShare).div(1e12).sub(user.rewardDebt);safeRewardTransfer(msg.sender, pending);}pool.lpToken.safeTransferFrom(address(msg.sender),address(this),_amount);user.amount = user.amount.add(_amount);user.rewardDebt = user.amount.mul(pool.accCvxPerShare).div(1e12);IRewarder _rewarder = pool.rewarder;if (address(_rewarder) != address(0)) {_rewarder.onReward(_pid, msg.sender, msg.sender, 0, user.amount);}emit Deposit(msg.sender, _pid, _amount);}function withdraw(uint256 _pid, uint256 _amount) public {PoolInfo storage pool = poolInfo[_pid];UserInfo storage user = userInfo[_pid][msg.sender];require(user.amount >= _amount, "withdraw: not good");updatePool(_pid);uint256 pending = user.amount.mul(pool.accCvxPerShare).div(1e12).sub(user.rewardDebt);safeRewardTransfer(msg.sender, pending);user.amount = user.amount.sub(_amount);user.rewardDebt = user.amount.mul(pool.accCvxPerShare).div(1e12);pool.lpToken.safeTransfer(address(msg.sender), _amount);IRewarder _rewarder = pool.rewarder;if (address(_rewarder) != address(0)) {_rewarder.onReward(_pid, msg.sender, msg.sender, pending, user.amount);}emit RewardPaid(msg.sender, _pid, pending);emit Withdraw(msg.sender, _pid, _amount);}function claim(uint256 _pid, address _account) external{PoolInfo storage pool = poolInfo[_pid];UserInfo storage user = userInfo[_pid][_account];updatePool(_pid);uint256 pending = user.amount.mul(pool.accCvxPerShare).div(1e12).sub(user.rewardDebt);safeRewardTransfer(_account, pending);user.rewardDebt = user.amount.mul(pool.accCvxPerShare).div(1e12);IRewarder _rewarder = pool.rewarder;if (address(_rewarder) != address(0)) {_rewarder.onReward(_pid, _account, _account, pending, user.amount);}emit RewardPaid(_account, _pid, pending);}function emergencyWithdraw(uint256 _pid) public {PoolInfo storage pool = poolInfo[_pid];UserInfo storage user = userInfo[_pid][msg.sender];pool.lpToken.safeTransfer(address(msg.sender), user.amount);emit EmergencyWithdraw(msg.sender, _pid, user.amount);user.amount = 0;user.rewardDebt = 0;IRewarder _rewarder = pool.rewarder;if (address(_rewarder) != address(0)) {_rewarder.onReward(_pid, msg.sender, msg.sender, 0, 0);}}function safeRewardTransfer(address _to, uint256 _amount) internal {uint256 cvxBal = cvx.balanceOf(address(this));if (_amount > cvxBal) {cvx.safeTransfer(_to, cvxBal);} else {cvx.safeTransfer(_to, _amount);}}}
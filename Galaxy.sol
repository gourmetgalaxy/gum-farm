pragma solidity ^0.5.8;

import './IERC20.sol';
import './SafeMath.sol';
import './Ownable.sol';
import './SafeERC20.sol';
import './GumToken.sol';

contract Galaxy is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct UserInfo {
    uint256 amount;
    uint256 rewardDebt;
  }

  struct PoolInfo {
    IERC20 lpToken;
    uint256 allocPoint;
    uint256 lastRewardBlock;
    uint256 accGumPerShare;
  }

  GumToken public gum;
  uint256 public bonusEndBlock;
  uint256 public rewardsEndBlock;
  uint256 public gumPerBlock = 1e18;
  uint256 public constant BONUS_MULTIPLIER = 3;

  PoolInfo[] public poolInfo;
  mapping(address => bool) public lpTokenExistsInPool;
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  uint256 public totalAllocPoint = 0;
  uint256 public startBlock;

  uint256 public blockIn2Weeks = 80640;
  uint256 public blockIn2Years = 4204800;

  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(
    address indexed user,
    uint256 indexed pid,
    uint256 amount
  );

  constructor(
    GumToken _gum
  ) public {
    gum = _gum;
    startBlock = block.number;
    bonusEndBlock = startBlock + blockIn2Weeks;
    rewardsEndBlock = startBlock + blockIn2Years;
  }

  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  function add(
    uint256 _allocPoint,
    IERC20 _lpToken,
    bool _withUpdate
  ) public onlyOwner {
    require(
      !lpTokenExistsInPool[address(_lpToken)],
      'Galaxy: LP Token Address already exists in pool'
    );
    if (_withUpdate) {
      massUpdatePools();
    }
    uint256 blockNumber = min(block.number, rewardsEndBlock);
    uint256 lastRewardBlock = blockNumber > startBlock
    ? blockNumber
    : startBlock;
    totalAllocPoint = totalAllocPoint.add(_allocPoint);
    poolInfo.push(
      PoolInfo({
      lpToken: _lpToken,
      allocPoint: _allocPoint,
      lastRewardBlock: lastRewardBlock,
      accGumPerShare: 0
      })
    );
    lpTokenExistsInPool[address(_lpToken)] = true;
  }

  function updateLpTokenExists(address _lpTokenAddr, bool _isExists)
  external
  onlyOwner
  {
    lpTokenExistsInPool[_lpTokenAddr] = _isExists;
  }

  function set(
    uint256 _pid,
    uint256 _allocPoint,
    bool _withUpdate
  ) public onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }
    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
      _allocPoint
    );
    poolInfo[_pid].allocPoint = _allocPoint;
  }

  function getMultiplier(uint256 _from, uint256 _to)
  public
  view
  returns (uint256)
  {
    if (_to <= bonusEndBlock) {
      return _to.sub(_from).mul(BONUS_MULTIPLIER);
    } else if (_from >= bonusEndBlock) {
      return _to.sub(_from);
    } else {
      return
      bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
        _to.sub(bonusEndBlock)
      );
    }
  }

  function pendingGum(uint256 _pid, address _user)
  external
  view
  returns (uint256)
  {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accGumPerShare = pool.accGumPerShare;
    uint256 blockNumber = min(block.number, rewardsEndBlock);
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (blockNumber > pool.lastRewardBlock && lpSupply != 0) {
      uint256 multiplier = getMultiplier(
        pool.lastRewardBlock,
        blockNumber
      );
      uint256 gumReward = multiplier
      .mul(gumPerBlock)
      .mul(pool.allocPoint)
      .div(totalAllocPoint);
      accGumPerShare = accGumPerShare.add(
        gumReward.mul(1e12).div(lpSupply)
      );
    }
    return user.amount.mul(accGumPerShare).div(1e12).sub(user.rewardDebt);
  }

  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(pid);
    }
  }

  function updatePool(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    uint256 blockNumber = min(block.number, rewardsEndBlock);
    if (blockNumber <= pool.lastRewardBlock) {
      return;
    }
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (lpSupply == 0) {
      pool.lastRewardBlock = blockNumber;
      return;
    }
    uint256 multiplier = getMultiplier(pool.lastRewardBlock, blockNumber);
    uint256 gumReward = multiplier
    .mul(gumPerBlock)
    .mul(pool.allocPoint)
    .div(totalAllocPoint);
    gum.releaseFarmAllocation(address(this), gumReward);
    pool.accGumPerShare = pool.accGumPerShare.add(
      gumReward.mul(1e12).div(lpSupply)
    );
    pool.lastRewardBlock = blockNumber;
  }

  function deposit(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    updatePool(_pid);
    if (user.amount > 0) {
      uint256 pending = user.amount.mul(pool.accGumPerShare).div(1e12).sub(user.rewardDebt);
      safeGumTransfer(msg.sender, pending);
    }
    pool.lpToken.safeTransferFrom(
      address(msg.sender),
      address(this),
      _amount
    );
    user.amount = user.amount.add(_amount);
    user.rewardDebt = user.amount.mul(pool.accGumPerShare).div(1e12);
    emit Deposit(msg.sender, _pid, _amount);
  }

  function withdraw(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(
      user.amount >= _amount,
      'Galaxy: Insufficient Amount to withdraw'
    );
    updatePool(_pid);
    uint256 pending = user.amount.mul(pool.accGumPerShare).div(1e12).sub(user.rewardDebt);
    safeGumTransfer(msg.sender, pending);
    user.amount = user.amount.sub(_amount);
    user.rewardDebt = user.amount.mul(pool.accGumPerShare).div(1e12);
    pool.lpToken.safeTransfer(address(msg.sender), _amount);
    emit Withdraw(msg.sender, _pid, _amount);
  }

  function emergencyWithdraw(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    pool.lpToken.safeTransfer(address(msg.sender), user.amount);
    emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
  }

  function safeGumTransfer(address _to, uint256 _amount) internal {
    uint256 gumBalance = gum.balanceOf(address(this));
    if (_amount > gumBalance) {
      gum.transfer(_to, gumBalance);
    } else {
      gum.transfer(_to, _amount);
    }
  }

  function isRewardsActive() public view returns (bool) {
    return rewardsEndBlock > block.number;
  }

  function min(uint256 a, uint256 b) public pure returns (uint256) {
    if (a > b) {
      return b;
    }
    return a;
  }
}

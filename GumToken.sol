pragma solidity 0.5.8;

import './Ownable.sol';
import './ERC20.sol';

contract GumToken is ERC20('GumToken', 'GUM', 20e6 * 1e18, address(this)), Ownable {

  uint private constant teamAllocation = 3e6 * 1e18;
  uint private constant communityAllocation = 5e4 * 1e18;
  uint private constant adviserAllocation = 1e6 * 1e18;
  uint private constant farmingAllocation = 9950000 * 1e18;
  uint private constant marketingAllocation = 5e5 * 1e18;
  uint private constant privateSaleAllocation = 5e6 * 1e18;
  uint private constant publicSaleAllocation = 5e5 * 1e18;

  uint private teamReleased = 0;
  uint private communityReleased = 0;
  uint private adviserReleased = 0;
  uint private farmingReleased = 0;
  uint private marketingReleased = 125000 * 1e18; // TGE
  uint private privateSaleReleased = 2e6 * 1e18;

  uint private lastTeamReleased = now + 30 days;
  uint private lastCommunityReleased = now + 30 days;
  uint private lastAdviserReleased = now + 30 days;
  uint private lastMarketingReleased = now + 30 days;
  uint private lastPrivateSaleReleased = now + 30 days;

  uint private constant amountEachTeamRelease = 150000 * 1e18;
  uint private constant amountEachCommunityRelease = 2500 * 1e18;
  uint private constant amountEachAdviserRelease = 50000 * 1e18;
  uint private constant amountEachMarketingRelease = 125000 * 1e18;
  uint private constant amountEachPrivateSaleRelease = 1e6 * 1e18;

  constructor(
    address _marketingTGEAddress,
    address _privateSaleTGEAddress,
    address _publicSaleTGEAddress
  ) public {
    _transfer(address(this), _marketingTGEAddress, marketingReleased);
    _transfer(address(this), _privateSaleTGEAddress, privateSaleReleased);
    _transfer(address(this), _publicSaleTGEAddress, publicSaleAllocation);
  }

  function releaseFarmAllocation(address _farmAddress, uint256 _amount) public onlyFarmContract {
    require(farmingReleased.add(_amount) <= farmingAllocation, 'Max farming allocation released');
    _transfer(address(this), _farmAddress, _amount);
    farmingReleased = farmingReleased.add(_amount);
  }

  function releaseTeamAllocation(address _receiver) public onlyOwner {
    require(teamReleased.add(amountEachTeamRelease) <= teamAllocation, 'Max team allocation released');
    require(now - lastTeamReleased >= 30 days, 'Please wait to next checkpoint');
    _transfer(address(this), _receiver, amountEachTeamRelease);
    teamReleased = teamReleased.add(amountEachTeamRelease);
    lastTeamReleased = lastTeamReleased + 30 days;
  }

  function releaseCommunityAllocation(address _receiver) public onlyOwner {
    require(communityReleased.add(amountEachCommunityRelease) <= communityAllocation, 'Max community allocation released');
    require(now - lastCommunityReleased >= 90 days, 'Please wait to next checkpoint');
    _transfer(address(this), _receiver, amountEachCommunityRelease);
    communityReleased = communityReleased.add(amountEachCommunityRelease);
    lastCommunityReleased = lastCommunityReleased + 90 days;
  }

  function releaseAdviserAllocation(address _receiver) public onlyOwner {
    require(adviserReleased.add(amountEachAdviserRelease) <= adviserAllocation, 'Max adviser allocation released');
    require(now - lastAdviserReleased >= 30 days, 'Please wait to next checkpoint');
    _transfer(address(this), _receiver, amountEachAdviserRelease);
    adviserReleased = adviserReleased.add(amountEachAdviserRelease);
    lastAdviserReleased = lastAdviserReleased + 30 days;
  }

  function releaseMarketingAllocation(address _receiver) public onlyOwner {
    require(marketingReleased.add(amountEachMarketingRelease) <= marketingAllocation, 'Max marketing allocation released');
    require(now - lastMarketingReleased >= 90 days, 'Please wait to next checkpoint');
    _transfer(address(this), _receiver, amountEachMarketingRelease);
    marketingReleased = marketingReleased.add(amountEachMarketingRelease);
    lastMarketingReleased = lastMarketingReleased + 90 days;
  }

  function releasePrivateSaleAllocation(address _receiver) public onlyOwner {
    require(privateSaleReleased.add(amountEachPrivateSaleRelease) <= privateSaleAllocation, 'Max privateSale allocation released');
    require(now - lastPrivateSaleReleased >= 90 days, 'Please wait to next checkpoint');
    _transfer(address(this), _receiver, amountEachPrivateSaleRelease);
    privateSaleReleased = privateSaleReleased.add(amountEachPrivateSaleRelease);
    lastPrivateSaleReleased = lastPrivateSaleReleased + 90 days;
  }
}

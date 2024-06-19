pragma solidity =0.8.10;import { ERC721, ERC721Enumerable, Strings } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";import { IEIP2612 } from "./interfaces/IEIP2612.sol";import { IXDEFIDistribution } from "./interfaces/IXDEFIDistribution.sol";contract XDEFIDistribution is IXDEFIDistribution, ERC721Enumerable {uint88 internal MAX_TOTAL_XDEFI_SUPPLY = uint88(240_000_000_000_000_000_000_000_000);uint256 internal constant _pointsMultiplier = uint256(2**128);uint256 internal _pointsPerUnit;address public immutable XDEFI;uint256 public distributableXDEFI;uint256 public totalDepositedXDEFI;uint256 public totalUnits;mapping(uint256 => Position) public positionOf;mapping(uint256 => uint8) public bonusMultiplierOf;uint256 internal immutable _zeroDurationPointBase;string public baseURI;address public owner;address public pendingOwner;uint256 internal _locked;constructor (address XDEFI_, string memory baseURI_, uint256 zeroDurationPointBase_) ERC721("Locked XDEFI", "lXDEFI") {require((XDEFI = XDEFI_) != address(0), "INVALID_TOKEN");owner = msg.sender;baseURI = baseURI_;_zeroDurationPointBase = zeroDurationPointBase_;}modifier onlyOwner() {require(owner == msg.sender, "NOT_OWNER");_;}modifier noReenter() {require(_locked == 0, "LOCKED");_locked = uint256(1);_;_locked = uint256(0);}function acceptOwnership() external {require(pendingOwner == msg.sender, "NOT_PENDING_OWNER");emit OwnershipAccepted(owner, msg.sender);owner = msg.sender;pendingOwner = address(0);}function proposeOwnership(address newOwner_) external onlyOwner {emit OwnershipProposed(owner, pendingOwner = newOwner_);}function setBaseURI(string memory baseURI_) external onlyOwner {baseURI = baseURI_;}function setLockPeriods(uint256[] memory durations_, uint8[] memory multipliers) external onlyOwner {uint256 count = durations_.length;for (uint256 i; i < count; ++i) {uint256 duration = durations_[i];require(duration <= uint256(18250 days), "INVALID_DURATION");emit LockPeriodSet(duration, bonusMultiplierOf[duration] = multipliers[i]);}}function lock(uint256 amount_, uint256 duration_, address destination_) external noReenter returns (uint256 tokenId_) {SafeERC20.safeTransferFrom(IERC20(XDEFI), msg.sender, address(this), amount_);return _lock(amount_, duration_, destination_);}function lockWithPermit(uint256 amount_, uint256 duration_, address destination_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) external noReenter returns (uint256 tokenId_) {IEIP2612(XDEFI).permit(msg.sender, address(this), amount_, deadline_, v_, r_, s_);SafeERC20.safeTransferFrom(IERC20(XDEFI), msg.sender, address(this), amount_);return _lock(amount_, duration_, destination_);}function relock(uint256 tokenId_, uint256 lockAmount_, uint256 duration_, address destination_) external noReenter returns (uint256 amountUnlocked_, uint256 newTokenId_) {amountUnlocked_ = _unlock(msg.sender, tokenId_);require(lockAmount_ <= amountUnlocked_, "INSUFFICIENT_AMOUNT_UNLOCKED");newTokenId_ = _lock(lockAmount_, duration_, destination_);uint256 withdrawAmount = amountUnlocked_ - lockAmount_;if (withdrawAmount != uint256(0)) {SafeERC20.safeTransfer(IERC20(XDEFI), destination_, withdrawAmount);}_updateXDEFIBalance();}function unlock(uint256 tokenId_, address destination_) external noReenter returns (uint256 amountUnlocked_) {amountUnlocked_ = _unlock(msg.sender, tokenId_);SafeERC20.safeTransfer(IERC20(XDEFI), destination_, amountUnlocked_);_updateXDEFIBalance();}function updateDistribution() external {uint256 totalUnitsCached = totalUnits;require(totalUnitsCached > uint256(0), "NO_UNIT_SUPPLY");uint256 newXDEFI = _toUint256Safe(_updateXDEFIBalance());if (newXDEFI == uint256(0)) return;_pointsPerUnit += ((newXDEFI * _pointsMultiplier) / totalUnitsCached);emit DistributionUpdated(msg.sender, newXDEFI);}function withdrawableOf(uint256 tokenId_) public view returns (uint256 withdrawableXDEFI_) {Position storage position = positionOf[tokenId_];return _withdrawableGiven(position.units, position.depositedXDEFI, position.pointsCorrection);}function relockBatch(uint256[] memory tokenIds_, uint256 lockAmount_, uint256 duration_, address destination_) external noReenter returns (uint256 amountUnlocked_, uint256 newTokenId_) {amountUnlocked_ = _unlockBatch(msg.sender, tokenIds_);require(lockAmount_ <= amountUnlocked_, "INSUFFICIENT_AMOUNT_UNLOCKED");newTokenId_ = _lock(lockAmount_, duration_, destination_);uint256 withdrawAmount = amountUnlocked_ - lockAmount_;if (withdrawAmount != uint256(0)) {SafeERC20.safeTransfer(IERC20(XDEFI), destination_, withdrawAmount);}_updateXDEFIBalance();}function unlockBatch(uint256[] memory tokenIds_, address destination_) external noReenter returns (uint256 amountUnlocked_) {amountUnlocked_ = _unlockBatch(msg.sender, tokenIds_);SafeERC20.safeTransfer(IERC20(XDEFI), destination_, amountUnlocked_);_updateXDEFIBalance();}function getPoints(uint256 amount_, uint256 duration_) external view returns (uint256 points_) {return _getPoints(amount_, duration_);}function merge(uint256[] memory tokenIds_, address destination_) external returns (uint256 tokenId_) {uint256 count = tokenIds_.length;require(count > uint256(1), "MIN_2_TO_MERGE");uint256 points;for (uint256 i; i < count; ++i) {uint256 tokenId = tokenIds_[i];require(ownerOf(tokenId) == msg.sender, "NOT_OWNER");require(positionOf[tokenId].expiry == uint32(0), "POSITION_NOT_UNLOCKED");_burn(tokenId);points += _getPointsFromTokenId(tokenId);}_safeMint(destination_, tokenId_ = _generateNewTokenId(points));}function pointsOf(uint256 tokenId_) external view returns (uint256 points_) {require(_exists(tokenId_), "NO_TOKEN");return _getPointsFromTokenId(tokenId_);}function tokenURI(uint256 tokenId_) public view override(IXDEFIDistribution, ERC721) returns (string memory tokenURI_) {require(_exists(tokenId_), "NO_TOKEN");return string(abi.encodePacked(baseURI, Strings.toString(tokenId_)));}function _generateNewTokenId(uint256 points_) internal view returns (uint256 tokenId_) {return (points_ << uint256(128)) + uint128(totalSupply() + 1);}function _getPoints(uint256 amount_, uint256 duration_) internal view returns (uint256 points_) {return amount_ * (duration_ + _zeroDurationPointBase);}function _getPointsFromTokenId(uint256 tokenId_) internal pure returns (uint256 points_) {return tokenId_ >> uint256(128);}function _lock(uint256 amount_, uint256 duration_, address destination_) internal returns (uint256 tokenId_) {require(amount_ != uint256(0) && amount_ <= MAX_TOTAL_XDEFI_SUPPLY, "INVALID_AMOUNT");uint8 bonusMultiplier = bonusMultiplierOf[duration_];require(bonusMultiplier != uint8(0), "INVALID_DURATION");_safeMint(destination_, tokenId_ = _generateNewTokenId(_getPoints(amount_, duration_)));totalDepositedXDEFI += amount_;uint96 units = uint96((amount_ * uint256(bonusMultiplier)) / uint256(100));totalUnits += units;positionOf[tokenId_] =Position({units: units,depositedXDEFI: uint88(amount_),expiry: uint32(block.timestamp + duration_),created: uint32(block.timestamp),bonusMultiplier: bonusMultiplier,pointsCorrection: -_toInt256Safe(_pointsPerUnit * units)});emit LockPositionCreated(tokenId_, destination_, amount_, duration_);}function _toInt256Safe(uint256 x_) internal pure returns (int256 y_) {y_ = int256(x_);assert(y_ >= int256(0));}function _toUint256Safe(int256 x_) internal pure returns (uint256 y_) {assert(x_ >= int256(0));return uint256(x_);}function _unlock(address account_, uint256 tokenId_) internal returns (uint256 amountUnlocked_) {require(ownerOf(tokenId_) == account_, "NOT_OWNER");Position storage position = positionOf[tokenId_];uint96 units = position.units;uint88 depositedXDEFI = position.depositedXDEFI;uint32 expiry = position.expiry;require(expiry != uint32(0), "NO_LOCKED_POSITION");require(block.timestamp >= uint256(expiry), "CANNOT_UNLOCK");amountUnlocked_ = _withdrawableGiven(units, depositedXDEFI, position.pointsCorrection);totalDepositedXDEFI -= uint256(depositedXDEFI);totalUnits -= units;delete positionOf[tokenId_];emit LockPositionWithdrawn(tokenId_, account_, amountUnlocked_);}function _unlockBatch(address account_, uint256[] memory tokenIds_) internal returns (uint256 amountUnlocked_) {uint256 count = tokenIds_.length;require(count > uint256(1), "USE_UNLOCK");for (uint256 i; i < count; ++i) {amountUnlocked_ += _unlock(account_, tokenIds_[i]);}}function _updateXDEFIBalance() internal returns (int256 newFundsTokenBalance_) {uint256 previousDistributableXDEFI = distributableXDEFI;uint256 currentDistributableXDEFI = distributableXDEFI = IERC20(XDEFI).balanceOf(address(this)) - totalDepositedXDEFI;return _toInt256Safe(currentDistributableXDEFI) - _toInt256Safe(previousDistributableXDEFI);}function _withdrawableGiven(uint96 units_, uint88 depositedXDEFI_, int256 pointsCorrection_) internal view returns (uint256 withdrawableXDEFI_) {return(_toUint256Safe(_toInt256Safe(_pointsPerUnit * uint256(units_)) +pointsCorrection_) / _pointsMultiplier) + uint256(depositedXDEFI_);}}
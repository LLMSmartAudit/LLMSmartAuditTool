pragma solidity 0.8.3;import "./interfaces/iERC20.sol";import "./interfaces/iUTILS.sol";import "./interfaces/iVADER.sol";import "./interfaces/iFACTORY.sol";contract Pools {bool private inited;uint public pooledVADER;uint public pooledUSDV;address public VADER;address public USDV;address public ROUTER;address public FACTORY;mapping(address => bool) _isMember;mapping(address => bool) _isAsset;mapping(address => bool) _isAnchor;mapping(address => uint) public mapToken_Units;mapping(address => mapping(address => uint)) public mapTokenMember_Units;mapping(address => uint) public mapToken_baseAmount;mapping(address => uint) public mapToken_tokenAmount;event AddLiquidity(address indexed member, address indexed base, uint baseAmount, address indexed token, uint tokenAmount, uint liquidityUnits);event RemoveLiquidity(address indexed member, address indexed base, uint baseAmount, address indexed token, uint tokenAmount, uint liquidityUnits, uint totalUnits);event Swap(address indexed member, address indexed inputToken, uint inputAmount, address indexed outputToken, uint outputAmount, uint swapFee);event Sync(address indexed token, address indexed pool, uint addedAmount);event SynthSync(address indexed token, uint burntSynth, uint deletedUnits);constructor() {}function init(address _vader, address _usdv, address _router, address _factory) public {require(inited == false);inited = true;VADER = _vader;USDV = _usdv;ROUTER = _router;FACTORY = _factory;}function addLiquidity(address base, address token, address member) external returns(uint liquidityUnits) {require(token != USDV && token != VADER); // Prohibiteduint _actualInputBase;if(base == VADER){if(!isAnchor(token)){        // If new Anchor_isAnchor[token] = true;}_actualInputBase = getAddedAmount(VADER, token);} else if (base == USDV) {if(!isAsset(token)){        // If new Asset_isAsset[token] = true;}_actualInputBase = getAddedAmount(USDV, token);}uint _actualInputToken = getAddedAmount(token, token);liquidityUnits = iUTILS(UTILS()).calcLiquidityUnits(_actualInputBase, mapToken_baseAmount[token], _actualInputToken, mapToken_tokenAmount[token], mapToken_Units[token]);mapTokenMember_Units[token][member] += liquidityUnits; // Add units to membermapToken_Units[token] += liquidityUnits;        // Add in totalmapToken_baseAmount[token] += _actualInputBase;     // Add BASEmapToken_tokenAmount[token] += _actualInputToken;    // Add tokenemit AddLiquidity(member, base, _actualInputBase, token, _actualInputToken, liquidityUnits);}function removeLiquidity(address base, address token, uint basisPoints) external returns (uint outputBase, uint outputToken) {return _removeLiquidity(base, token, basisPoints, tx.origin); // Because this contract is wrapped by a router}function removeLiquidityDirectly(address base, address token, uint basisPoints) external returns (uint outputBase, uint outputToken) {return _removeLiquidity(base, token, basisPoints, msg.sender); // If want to interact directly}function _removeLiquidity(address base, address token, uint basisPoints, address member) internal returns (uint outputBase, uint outputToken) {require(base == USDV || base == VADER);uint _units = iUTILS(UTILS()).calcPart(basisPoints, mapTokenMember_Units[token][member]);outputBase = iUTILS(UTILS()).calcShare(_units, mapToken_Units[token], mapToken_baseAmount[token]);outputToken = iUTILS(UTILS()).calcShare(_units, mapToken_Units[token], mapToken_tokenAmount[token]);mapToken_Units[token] -=_units;mapTokenMember_Units[token][member] -= _units;mapToken_baseAmount[token] -= outputBase;mapToken_tokenAmount[token] -= outputToken;emit RemoveLiquidity(member, base, outputBase, token, outputToken, _units, mapToken_Units[token]);transferOut(base, outputBase, member);transferOut(token, outputToken, member);return (outputBase, outputToken);}function swap(address base, address token, address member, bool toBase) external returns (uint outputAmount) {if(toBase){uint _actualInput = getAddedAmount(token, token);outputAmount = iUTILS(UTILS()).calcSwapOutput(_actualInput, mapToken_tokenAmount[token], mapToken_baseAmount[token]);uint _swapFee = iUTILS(UTILS()).calcSwapFee(_actualInput, mapToken_tokenAmount[token], mapToken_baseAmount[token]);mapToken_tokenAmount[token] += _actualInput;mapToken_baseAmount[token] -= outputAmount;emit Swap(member, token, _actualInput, base, outputAmount, _swapFee);transferOut(base, outputAmount, member);} else {uint _actualInput = getAddedAmount(base, token);outputAmount = iUTILS(UTILS()).calcSwapOutput(_actualInput, mapToken_baseAmount[token], mapToken_tokenAmount[token]);uint _swapFee = iUTILS(UTILS()).calcSwapFee(_actualInput, mapToken_baseAmount[token], mapToken_tokenAmount[token]);mapToken_baseAmount[token] += _actualInput;mapToken_tokenAmount[token] -= outputAmount;emit Swap(member, base, _actualInput, token, outputAmount, _swapFee);transferOut(token, outputAmount, member);}}function sync(address token, address pool) external {uint _actualInput = getAddedAmount(token, pool);if (token == VADER || token == USDV){mapToken_baseAmount[pool] += _actualInput;} else {mapToken_tokenAmount[pool] += _actualInput;}emit Sync(token, pool, _actualInput);}function deploySynth(address token) external {require(token != VADER || token != USDV);iFACTORY(FACTORY).deploySynth(token);}function mintSynth(address base, address token, address member) external returns (uint outputAmount) {require(iFACTORY(FACTORY).isSynth(getSynth(token)), "!synth");uint _actualInputBase = getAddedAmount(base, token);          // Get inputuint _synthUnits = iUTILS(UTILS()).calcSynthUnits(_actualInputBase, mapToken_baseAmount[token], mapToken_Units[token]);   // Get UnitsoutputAmount = iUTILS(UTILS()).calcSwapOutput(_actualInputBase, mapToken_baseAmount[token], mapToken_tokenAmount[token]);  // Get outputmapTokenMember_Units[token][address(this)] += _synthUnits;         // Add units for selfmapToken_Units[token] += _synthUnits;                    // Add supplymapToken_baseAmount[token] += _actualInputBase;               // Add BASEemit AddLiquidity(member, base, _actualInputBase, token, 0, _synthUnits);  // Add Liquidity EventiFACTORY(FACTORY).mintSynth(getSynth(token), member, outputAmount);     // Ask factory to mint to member}function burnSynth(address base, address token, address member) external returns (uint outputBase) {uint _actualInputSynth = iERC20(getSynth(token)).balanceOf(address(this)); // Get inputuint _unitsToDelete = iUTILS(UTILS()).calcShare(_actualInputSynth, iERC20(getSynth(token)).totalSupply(), mapTokenMember_Units[token][address(this)]); // Pro rataiERC20(getSynth(token)).burn(_actualInputSynth);              // Burn itmapTokenMember_Units[token][address(this)] -= _unitsToDelete;        // Delete units for selfmapToken_Units[token] -= _unitsToDelete;                  // Delete unitsoutputBase = iUTILS(UTILS()).calcSwapOutput(_actualInputSynth, mapToken_tokenAmount[token], mapToken_baseAmount[token]);  // Get outputmapToken_baseAmount[token] -= outputBase;                  // Remove BASEemit RemoveLiquidity(member, base, outputBase, token, 0, _unitsToDelete, mapToken_Units[token]);    // Remove liquidity eventtransferOut(base, outputBase, member);                   // Send BASE to member}function syncSynth(address token) external {uint _actualInputSynth = iERC20(getSynth(token)).balanceOf(address(this)); // Get inputuint _unitsToDelete = iUTILS(UTILS()).calcShare(_actualInputSynth, iERC20(getSynth(token)).totalSupply(), mapTokenMember_Units[token][address(this)]); // Pro rataiERC20(getSynth(token)).burn(_actualInputSynth);              // Burn itmapTokenMember_Units[token][address(this)] -= _unitsToDelete;        // Delete units for selfmapToken_Units[token] -= _unitsToDelete;                  // Delete unitsemit SynthSync(token, _actualInputSynth, _unitsToDelete);}function lockUnits(uint units, address token, address member) external {mapTokenMember_Units[token][member] -= units;mapTokenMember_Units[token][msg.sender] += units;    // Assign to protocol}function unlockUnits(uint units, address token, address member) external {mapTokenMember_Units[token][msg.sender] -= units;mapTokenMember_Units[token][member] += units;}function getAddedAmount(address _token, address _pool) internal returns(uint addedAmount) {uint _balance = iERC20(_token).balanceOf(address(this));if(_token == VADER && _pool != VADER){ // Want to know added VADERaddedAmount = _balance - pooledVADER;pooledVADER = pooledVADER + addedAmount;} else if(_token == USDV) {       // Want to know added USDVaddedAmount = _balance - pooledUSDV;pooledUSDV = pooledUSDV + addedAmount;} else {                // Want to know added Asset/AnchoraddedAmount = _balance - mapToken_tokenAmount[_pool];}}function transferOut(address _token, uint _amount, address _recipient) internal {if(_token == VADER){pooledVADER = pooledVADER - _amount; // Accounting} else if(_token == USDV) {pooledUSDV = pooledUSDV - _amount; // Accounting}if(_recipient != address(this)){iERC20(_token).transfer(_recipient, _amount);}}function isMember(address member) public view returns(bool) {return _isMember[member];}function isAsset(address token) public view returns(bool) {return _isAsset[token];}function isAnchor(address token) public view returns(bool) {return _isAnchor[token];}function getPoolAmounts(address token) external view returns(uint, uint) {return (getBaseAmount(token), getTokenAmount(token));}function getBaseAmount(address token) public view returns(uint) {return mapToken_baseAmount[token];}function getTokenAmount(address token) public view returns(uint) {return mapToken_tokenAmount[token];}function getUnits(address token) external view returns(uint) {return mapToken_Units[token];}function getMemberUnits(address token, address member) external view returns(uint) {return mapTokenMember_Units[token][member];}function getSynth(address token) public view returns (address) {return iFACTORY(FACTORY).getSynth(token);}function isSynth(address token) public view returns (bool) {return iFACTORY(FACTORY).isSynth(token);}function UTILS() public view returns(address){return iVADER(VADER).UTILS();}}
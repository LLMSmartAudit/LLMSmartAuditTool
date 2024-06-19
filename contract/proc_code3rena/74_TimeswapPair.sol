pragma solidity =0.8.4;import {IPair} from './interfaces/IPair.sol';import {IFactory} from './interfaces/IFactory.sol';import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';import {MintMath} from './libraries/MintMath.sol';import {BurnMath} from './libraries/BurnMath.sol';import {LendMath} from './libraries/LendMath.sol';import {WithdrawMath} from './libraries/WithdrawMath.sol';import {BorrowMath} from './libraries/BorrowMath.sol';import {PayMath} from './libraries/PayMath.sol';import {SafeTransfer} from './libraries/SafeTransfer.sol';import {Array} from './libraries/Array.sol';import {Callback} from './libraries/Callback.sol';import {BlockNumber} from './libraries/BlockNumber.sol';contract TimeswapPair is IPair {using SafeTransfer for IERC20;using Array for Due[];IFactory public immutable override factory;IERC20 public immutable override asset;IERC20 public immutable override collateral;uint16 public immutable override fee;uint16 public immutable override protocolFee;mapping(uint256 => Pool) private pools;uint256 private locked;function constantProduct(uint256 maturity)externalviewoverridereturns (uint112 x,uint112 y,uint112 z){State memory state = pools[maturity].state;return (state.x, state.y, state.z);}function totalReserves(uint256 maturity) external view override returns (Tokens memory) {return pools[maturity].state.reserves;}function totalLiquidity(uint256 maturity) external view override returns (uint256) {return pools[maturity].state.totalLiquidity;}function liquidityOf(uint256 maturity, address owner) external view override returns (uint256) {return pools[maturity].liquidities[owner];}function totalClaims(uint256 maturity) external view override returns (Claims memory) {return pools[maturity].state.totalClaims;}function claimsOf(uint256 maturity, address owner) external view override returns (Claims memory) {return pools[maturity].claims[owner];}function totalDebtCreated(uint256 maturity) external view override returns (uint120) {return pools[maturity].state.totalDebtCreated;}function dueOf(uint256 maturity, address owner, uint256 id) external view override returns (Due memory) {return pools[maturity].dues[owner][id];}constructor(IERC20 _asset,IERC20 _collateral,uint16 _fee,uint16 _protocolFee) {factory = IFactory(msg.sender);asset = _asset;collateral = _collateral;fee = _fee;protocolFee = _protocolFee;}modifier lock() {require(locked == 0, 'E211');locked = 1;_;locked = 0;}function mint(uint256 maturity,address liquidityTo,address dueTo,uint112 xIncrease,uint112 yIncrease,uint112 zIncrease,bytes calldata data)externaloverridelockreturns (uint256 liquidityOut,uint256 id,Due memory dueOut){require(block.timestamp < maturity, 'E202');require(maturity - block.timestamp < 0x100000000, 'E208');require(liquidityTo != address(0) && dueTo != address(0), 'E201');require(liquidityTo != address(this) && dueTo != address(this), 'E204');require(xIncrease > 0 && yIncrease > 0 && zIncrease > 0, 'E205');Pool storage pool = pools[maturity];if (pool.state.totalLiquidity == 0) {uint256 liquidityTotal = MintMath.getLiquidityTotal(xIncrease);liquidityOut = MintMath.getLiquidity(maturity, liquidityTotal, protocolFee);pool.state.totalLiquidity += liquidityTotal;pool.liquidities[factory.owner()] += liquidityTotal - liquidityOut;} else {uint256 liquidityTotal = MintMath.getLiquidityTotal(pool.state, xIncrease, yIncrease, zIncrease);liquidityOut = MintMath.getLiquidity(maturity, liquidityTotal, protocolFee);pool.state.totalLiquidity += liquidityTotal;pool.liquidities[factory.owner()] += liquidityTotal - liquidityOut;}require(liquidityOut > 0, 'E212');pool.liquidities[liquidityTo] += liquidityOut;dueOut.debt = MintMath.getDebt(maturity, xIncrease, yIncrease);dueOut.collateral = MintMath.getCollateral(maturity, zIncrease);dueOut.startBlock = BlockNumber.get();Callback.mint(asset, collateral, xIncrease, dueOut.collateral, data);id = pool.dues[dueTo].insert(dueOut);pool.state.reserves.asset += xIncrease;pool.state.reserves.collateral += dueOut.collateral;pool.state.totalDebtCreated += dueOut.debt;pool.state.x += xIncrease;pool.state.y += yIncrease;pool.state.z += zIncrease;emit Sync(maturity, pool.state.x, pool.state.y, pool.state.z);emit Mint(maturity, msg.sender, liquidityTo, dueTo, xIncrease, liquidityOut, id, dueOut);}function burn(uint256 maturity,address assetTo,address collateralTo,uint256 liquidityIn) external override lock returns (Tokens memory tokensOut) {require(block.timestamp >= maturity, 'E203');require(assetTo != address(0) && collateralTo != address(0), 'E201');require(assetTo != address(this) && collateralTo != address(this), 'E204');require(liquidityIn > 0, 'E205');Pool storage pool = pools[maturity];tokensOut.asset = BurnMath.getAsset(pool.state, liquidityIn);tokensOut.collateral = BurnMath.getCollateral(pool.state, liquidityIn);pool.state.totalLiquidity -= liquidityIn;pool.liquidities[msg.sender] -= liquidityIn;pool.state.reserves.asset -= tokensOut.asset;pool.state.reserves.collateral -= tokensOut.collateral;if (tokensOut.asset > 0) asset.safeTransfer(assetTo, tokensOut.asset);if (tokensOut.collateral > 0) collateral.safeTransfer(collateralTo, tokensOut.collateral);emit Burn(maturity, msg.sender, assetTo, collateralTo, liquidityIn, tokensOut);}function lend(uint256 maturity,address bondTo,address insuranceTo,uint112 xIncrease,uint112 yDecrease,uint112 zDecrease,bytes calldata data) external override lock returns (Claims memory claimsOut) {require(block.timestamp < maturity, 'E202');require(bondTo != address(0) && insuranceTo != address(0), 'E201');require(bondTo != address(this) && insuranceTo != address(this), 'E204');require(xIncrease > 0, 'E205');Pool storage pool = pools[maturity];require(pool.state.totalLiquidity > 0, 'E206');LendMath.check(pool.state, xIncrease, yDecrease, zDecrease, fee);claimsOut.bond = LendMath.getBond(maturity, xIncrease, yDecrease);claimsOut.insurance = LendMath.getInsurance(maturity, pool.state, xIncrease, zDecrease);Callback.lend(asset, xIncrease, data);pool.state.totalClaims.bond += claimsOut.bond;pool.state.totalClaims.insurance += claimsOut.insurance;pool.claims[bondTo].bond += claimsOut.bond;pool.claims[insuranceTo].insurance += claimsOut.insurance;pool.state.reserves.asset += xIncrease;pool.state.x += xIncrease;pool.state.y -= yDecrease;pool.state.z -= zDecrease;emit Sync(maturity, pool.state.x, pool.state.y, pool.state.z);emit Lend(maturity, msg.sender, bondTo, insuranceTo, xIncrease, claimsOut);}function withdraw(uint256 maturity,address assetTo,address collateralTo,Claims memory claimsIn) external override lock returns (Tokens memory tokensOut) {require(block.timestamp >= maturity, 'E203');require(assetTo != address(0) && collateralTo != address(0), 'E201');require(assetTo != address(this) && collateralTo != address(this), 'E204');require(claimsIn.bond > 0 || claimsIn.insurance > 0, 'E205');Pool storage pool = pools[maturity];tokensOut.asset = WithdrawMath.getAsset(pool.state, claimsIn.bond);tokensOut.collateral = WithdrawMath.getCollateral(pool.state, claimsIn.insurance);pool.state.totalClaims.bond -= claimsIn.bond;pool.state.totalClaims.insurance -= claimsIn.insurance;Claims storage sender = pool.claims[msg.sender];sender.bond -= claimsIn.bond;sender.insurance -= claimsIn.insurance;pool.state.reserves.asset -= tokensOut.asset;pool.state.reserves.collateral -= tokensOut.collateral;if (tokensOut.asset > 0) asset.safeTransfer(assetTo, tokensOut.asset);if (tokensOut.collateral > 0) collateral.safeTransfer(collateralTo, tokensOut.collateral);emit Withdraw(maturity, msg.sender, assetTo, collateralTo, claimsIn, tokensOut);}function borrow(uint256 maturity,address assetTo,address dueTo,uint112 xDecrease,uint112 yIncrease,uint112 zIncrease,bytes calldata data) external override lock returns (uint256 id, Due memory dueOut) {require(block.timestamp < maturity, 'E202');require(assetTo != address(0) && dueTo != address(0), 'E201');require(assetTo != address(this) && dueTo != address(this), 'E204');require(xDecrease > 0, 'E205');Pool storage pool = pools[maturity];require(pool.state.totalLiquidity > 0, 'E206');BorrowMath.check(pool.state, xDecrease, yIncrease, zIncrease, fee);dueOut.debt = BorrowMath.getDebt(maturity, xDecrease, yIncrease);dueOut.collateral = BorrowMath.getCollateral(maturity, pool.state, xDecrease, zIncrease);dueOut.startBlock = BlockNumber.get();Callback.borrow(collateral, dueOut.collateral, data);id = pool.dues[dueTo].insert(dueOut);pool.state.reserves.asset -= xDecrease;pool.state.reserves.collateral += dueOut.collateral;pool.state.totalDebtCreated += dueOut.debt;pool.state.x -= xDecrease;pool.state.y += yIncrease;pool.state.z += zIncrease;asset.safeTransfer(assetTo, xDecrease);emit Sync(maturity, pool.state.x, pool.state.y, pool.state.z);emit Borrow(maturity, msg.sender, assetTo, dueTo, xDecrease, id, dueOut);}function pay(uint256 maturity,address to,address owner,uint256[] memory ids,uint112[] memory assetsIn,uint112[] memory collateralsOut,bytes calldata data) external override lock returns (uint128 assetIn, uint128 collateralOut) {require(block.timestamp < maturity, 'E202');require(ids.length == assetsIn.length && ids.length == collateralsOut.length, 'E205');require(to != address(0), 'E201');require(to != address(this), 'E204');Pool storage pool = pools[maturity];Due[] storage dues = pool.dues[owner];for (uint256 i; i < ids.length; i++) {Due storage due = dues[ids[i]];require(due.startBlock != BlockNumber.get(), 'E207');if (owner != msg.sender) require(collateralsOut[i] == 0, 'E213');PayMath.checkProportional(assetsIn[i], collateralsOut[i], due);due.debt -= assetsIn[i];due.collateral -= collateralsOut[i];assetIn += assetsIn[i];collateralOut += collateralsOut[i];}if (assetIn > 0) Callback.pay(asset, assetIn, data);pool.state.reserves.asset += assetIn;pool.state.reserves.collateral -= collateralOut;if (collateralOut > 0) collateral.safeTransfer(to, collateralOut);emit Pay(maturity, msg.sender, to, owner, ids, assetsIn, collateralsOut, assetIn, collateralOut);}}
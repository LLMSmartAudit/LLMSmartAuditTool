pragma solidity >=0.8.0;contract HybridPool is IPool, TridentERC20 {using MathUtils for uint256;event Mint(address indexed sender, uint256 amount0, uint256 amount1, address indexed recipient);event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed recipient);event Sync(uint256 reserve0, uint256 reserve1);uint256 internal constant MINIMUM_LIQUIDITY = 10**3;uint8 internal constant PRECISION = 112;uint256 private constant MAX_LOOP_LIMIT = 256;uint256 internal constant MAX_FEE = 10000;uint256 public immutable swapFee;address public immutable barFeeTo;address public immutable bento;address public immutable masterDeployer;address public immutable token0;address public immutable token1;uint256 public immutable A;uint256 internal immutable N_A;uint256 internal constant A_PRECISION = 100;uint256 public immutable token0PrecisionMultiplier;uint256 public immutable token1PrecisionMultiplier;uint256 public barFee;uint128 internal reserve0;uint128 internal reserve1;bytes32 public constant override poolIdentifier = "Trident:HybridPool";uint256 internal unlocked;modifier lock() {require(unlocked == 1, "LOCKED");unlocked = 2;_;unlocked = 1;}constructor(bytes memory _deployData, address _masterDeployer) {(address _token0, address _token1, uint256 _swapFee, uint256 a) = abi.decode(_deployData, (address, address, uint256, uint256));require(_token0 != address(0), "ZERO_ADDRESS");require(_token0 != _token1, "IDENTICAL_ADDRESSES");require(_swapFee <= MAX_FEE, "INVALID_SWAP_FEE");require(a != 0, "ZERO_A");(, bytes memory _barFee) = _masterDeployer.staticcall(abi.encodeWithSelector(IMasterDeployer.barFee.selector));(, bytes memory _barFeeTo) = _masterDeployer.staticcall(abi.encodeWithSelector(IMasterDeployer.barFeeTo.selector));(, bytes memory _bento) = _masterDeployer.staticcall(abi.encodeWithSelector(IMasterDeployer.bento.selector));(, bytes memory _decimals0) = _token0.staticcall(abi.encodeWithSelector(0x313ce567));(, bytes memory _decimals1) = _token1.staticcall(abi.encodeWithSelector(0x313ce567));token0 = _token0;token1 = _token1;swapFee = _swapFee;barFee = abi.decode(_barFee, (uint256));barFeeTo = abi.decode(_barFeeTo, (address));bento = abi.decode(_bento, (address));masterDeployer = _masterDeployer;A = a;N_A = 2 * a;token0PrecisionMultiplier = 10**(decimals - abi.decode(_decimals0, (uint8)));token1PrecisionMultiplier = 10**(decimals - abi.decode(_decimals1, (uint8)));unlocked = 1;}function mint(bytes calldata data) public override lock returns (uint256 liquidity) {address recipient = abi.decode(data, (address));(uint256 _reserve0, uint256 _reserve1) = _getReserves();(uint256 balance0, uint256 balance1) = _balance();uint256 _totalSupply = totalSupply;uint256 amount0 = balance0 - _reserve0;uint256 amount1 = balance1 - _reserve1;(uint256 fee0, uint256 fee1) = _nonOptimalMintFee(amount0, amount1, _reserve0, _reserve1);uint256 newLiq = _computeLiquidity(balance0 - fee0, balance1 - fee1);if (_totalSupply == 0) {liquidity = newLiq - MINIMUM_LIQUIDITY;_mint(address(0), MINIMUM_LIQUIDITY);} else {uint256 oldLiq = _computeLiquidity(_reserve0, _reserve1);liquidity = ((newLiq - oldLiq) * _totalSupply) / oldLiq;}require(liquidity != 0, "INSUFFICIENT_LIQUIDITY_MINTED");_mint(recipient, liquidity);_updateReserves();emit Mint(msg.sender, amount0, amount1, recipient);}function burn(bytes calldata data) public override lock returns (IPool.TokenAmount[] memory withdrawnAmounts) {(address recipient, bool unwrapBento) = abi.decode(data, (address, bool));(uint256 balance0, uint256 balance1) = _balance();uint256 _totalSupply = totalSupply;uint256 liquidity = balanceOf[address(this)];uint256 amount0 = (liquidity * balance0) / _totalSupply;uint256 amount1 = (liquidity * balance1) / _totalSupply;_burn(address(this), liquidity);_transfer(token0, amount0, recipient, unwrapBento);_transfer(token1, amount1, recipient, unwrapBento);balance0 -= _toShare(token0, amount0);balance1 -= _toShare(token1, amount1);_updateReserves();withdrawnAmounts = new TokenAmount[](2);withdrawnAmounts[0] = TokenAmount({token: token0, amount: amount0});withdrawnAmounts[1] = TokenAmount({token: token1, amount: amount1});emit Burn(msg.sender, amount0, amount1, recipient);}function burnSingle(bytes calldata data) public override lock returns (uint256 amountOut) {(address tokenOut, address recipient, bool unwrapBento) = abi.decode(data, (address, address, bool));(uint256 _reserve0, uint256 _reserve1) = _getReserves();(uint256 balance0, uint256 balance1) = _balance();uint256 _totalSupply = totalSupply;uint256 liquidity = balanceOf[address(this)];uint256 amount0 = (liquidity * balance0) / _totalSupply;uint256 amount1 = (liquidity * balance1) / _totalSupply;_burn(address(this), liquidity);if (tokenOut == token1) {uint256 fee = _handleFee(token0, amount0);amount1 += _getAmountOut(amount0 - fee, _reserve0 - amount0, _reserve1 - amount1, true);_transfer(token1, amount1, recipient, unwrapBento);balance0 -= _toShare(token0, amount0);amountOut = amount1;amount0 = 0;} else {require(tokenOut == token0, "INVALID_OUTPUT_TOKEN");uint256 fee = _handleFee(token1, amount1);amount0 += _getAmountOut(amount1 - fee, _reserve0 - amount0, _reserve1 - amount1, false);_transfer(token0, amount0, recipient, unwrapBento);balance1 -= _toShare(token1, amount1);amountOut = amount0;amount1 = 0;}_updateReserves();emit Burn(msg.sender, amount0, amount1, recipient);}function swap(bytes calldata data) public override lock returns (uint256 amountOut) {(address tokenIn, address recipient, bool unwrapBento) = abi.decode(data, (address, address, bool));(uint256 _reserve0, uint256 _reserve1) = _getReserves();(uint256 balance0, uint256 balance1) = _balance();uint256 amountIn;address tokenOut;if (tokenIn == token0) {tokenOut = token1;amountIn = balance0 - _reserve0;uint256 fee = _handleFee(tokenIn, amountIn);amountOut = _getAmountOut(amountIn - fee, _reserve0, _reserve1, true);} else {require(tokenIn == token1, "INVALID_INPUT_TOKEN");tokenOut = token0;amountIn = balance1 - _reserve1;uint256 fee = _handleFee(tokenIn, amountIn);amountOut = _getAmountOut(amountIn - fee, _reserve0, _reserve1, false);}_transfer(tokenOut, amountOut, recipient, unwrapBento);_updateReserves();emit Swap(recipient, tokenIn, tokenOut, amountIn, amountOut);}function flashSwap(bytes calldata data) public override lock returns (uint256 amountOut) {(address tokenIn, address recipient, bool unwrapBento, uint256 amountIn, bytes memory context) = abi.decode(data,(address, address, bool, uint256, bytes));(uint256 _reserve0, uint256 _reserve1) = _getReserves();address tokenOut;uint256 fee;if (tokenIn == token0) {tokenOut = token1;amountIn = _toAmount(token0, amountIn);fee = (amountIn * swapFee) / MAX_FEE;amountOut = _getAmountOut(amountIn - fee, _reserve0, _reserve1, true);_processSwap(token1, recipient, amountOut, context, unwrapBento);uint256 balance0 = _toAmount(token0, __balance(token0));require(balance0 - _reserve0 >= amountIn, "INSUFFICIENT_AMOUNT_IN");} else {require(tokenIn == token1, "INVALID_INPUT_TOKEN");tokenOut = token0;amountIn = _toAmount(token1, amountIn);fee = (amountIn * swapFee) / MAX_FEE;amountOut = _getAmountOut(amountIn - fee, _reserve0, _reserve1, false);_processSwap(token0, recipient, amountOut, context, unwrapBento);uint256 balance1 = _toAmount(token1, __balance(token1));require(balance1 - _reserve1 >= amountIn, "INSUFFICIENT_AMOUNT_IN");}_transfer(tokenIn, fee, barFeeTo, false);_updateReserves();emit Swap(recipient, tokenIn, tokenOut, amountIn, amountOut);}function updateBarFee() public {(, bytes memory _barFee) = masterDeployer.staticcall(abi.encodeWithSelector(IMasterDeployer.barFee.selector));barFee = abi.decode(_barFee, (uint256));}function _processSwap(address tokenOut,address to,uint256 amountOut,bytes memory data,bool unwrapBento) internal {_transfer(tokenOut, amountOut, to, unwrapBento);if (data.length != 0) ITridentCallee(msg.sender).tridentSwapCallback(data);}function _getReserves() internal view returns (uint256 _reserve0, uint256 _reserve1) {(_reserve0, _reserve1) = (reserve0, reserve1);_reserve0 = _toAmount(token0, _reserve0);_reserve1 = _toAmount(token1, _reserve1);}function _updateReserves() internal {(uint256 _reserve0, uint256 _reserve1) = _balance();require(_reserve0 < type(uint128).max && _reserve1 < type(uint128).max, "OVERFLOW");reserve0 = uint128(_reserve0);reserve1 = uint128(_reserve1);emit Sync(_reserve0, _reserve1);}function _balance() internal view returns (uint256 balance0, uint256 balance1) {balance0 = _toAmount(token0, __balance(token0));balance1 = _toAmount(token1, __balance(token1));}function __balance(address token) internal view returns (uint256 balance) {(, bytes memory ___balance) = bento.staticcall(abi.encodeWithSelector(IBentoBoxMinimal.balanceOf.selector,token, address(this)));balance = abi.decode(___balance, (uint256));}function _toAmount(address token, uint256 input) internal view returns (uint256 output) {(, bytes memory _output) = bento.staticcall(abi.encodeWithSelector(IBentoBoxMinimal.toAmount.selector,token, input, false));output = abi.decode(_output, (uint256));}function _toShare(address token, uint256 input) internal view returns (uint256 output) {(, bytes memory _output) = bento.staticcall(abi.encodeWithSelector(IBentoBoxMinimal.toShare.selector,token, input, false));output = abi.decode(_output, (uint256));}function _getAmountOut(uint256 amountIn,uint256 _reserve0,uint256 _reserve1,bool token0In) internal view returns (uint256 dy) {uint256 xpIn;uint256 xpOut;if (token0In) {xpIn = _reserve0 * token0PrecisionMultiplier;xpOut = _reserve1 * token1PrecisionMultiplier;amountIn *= token0PrecisionMultiplier;} else {xpIn = _reserve1 * token1PrecisionMultiplier;xpOut = _reserve0 * token0PrecisionMultiplier;amountIn *= token1PrecisionMultiplier;}uint256 d = _computeLiquidityFromAdjustedBalances(xpIn, xpOut);uint256 x = xpIn + amountIn;uint256 y = _getY(x, d);dy = xpOut - y - 1;dy /= (token0In ? token1PrecisionMultiplier : token0PrecisionMultiplier);}function _transfer(address token,uint256 amount,address to,bool unwrapBento) internal {if (unwrapBento) {(bool success, ) = bento.call(abi.encodeWithSelector(IBentoBoxMinimal.withdraw.selector,token, address(this), to, amount, 0));require(success, "WITHDRAW_FAILED");} else {(bool success, ) = bento.call(abi.encodeWithSelector(IBentoBoxMinimal.transfer.selector,token, address(this), to, _toShare(token, amount)));require(success, "TRANSFER_FAILED");}}function _computeLiquidity(uint256 _reserve0, uint256 _reserve1) internal view returns (uint256 liquidity) {uint256 xp0 = _reserve0 * token0PrecisionMultiplier;uint256 xp1 = _reserve1 * token1PrecisionMultiplier;liquidity = _computeLiquidityFromAdjustedBalances(xp0, xp1);}function _computeLiquidityFromAdjustedBalances(uint256 xp0, uint256 xp1) internal view returns (uint256 computed) {uint256 s = xp0 + xp1;if (s == 0) {computed = 0;}uint256 prevD;uint256 D = s;for (uint256 i = 0; i < MAX_LOOP_LIMIT; i++) {uint256 dP = (((D * D) / xp0) * D) / xp1 / 4;prevD = D;D = (((N_A * s) / A_PRECISION + 2 * dP) * D) / ((N_A / A_PRECISION - 1) * D + 3 * dP);if (D.within1(prevD)) {break;}}computed = D;}function _getY(uint256 x, uint256 D) internal view returns (uint256 y) {uint256 c = (D * D) / (x * 2);c = (c * D) / ((N_A * 2) / A_PRECISION);uint256 b = x + ((D * A_PRECISION) / N_A);uint256 yPrev;y = D;for (uint256 i = 0; i < MAX_LOOP_LIMIT; i++) {yPrev = y;y = (y * y + c) / (y * 2 + b - D);if (y.within1(yPrev)) {break;}}}function _getYD(uint256 s, xpOut.uint256 d) internal view returns (uint256 y) {uint256 c = (d * d) / (s * 2);c = (c * d) / ((N_A * 2) / A_PRECISION);uint256 b = s + ((d * A_PRECISION) / N_A);uint256 yPrev;y = d;for (uint256 i = 0; i < MAX_LOOP_LIMIT; i++) {yPrev = y;y = (y * y + c) / (y * 2 + b - d);if (y.within1(yPrev)) {break;}}}function _handleFee(address tokenIn, uint256 amountIn) internal returns (uint256 fee) {fee = (amountIn * swapFee) / MAX_FEE;uint256 _barFee = (fee * barFee) / MAX_FEE;_transfer(tokenIn, _barFee, barFeeTo, false);}function _nonOptimalMintFee(uint256 _amount0,uint256 _amount1,uint256 _reserve0,uint256 _reserve1) internal view returns (uint256 token0Fee, uint256 token1Fee) {if (_reserve0 == 0 || _reserve1 == 0) return (0, 0);uint256 amount1Optimal = (_amount0 * _reserve1) / _reserve0;if (amount1Optimal <= _amount1) {token1Fee = (swapFee * (_amount1 - amount1Optimal)) / (2 * MAX_FEE);} else {uint256 amount0Optimal = (_amount1 * _reserve0) / _reserve1;token0Fee = (swapFee * (_amount0 - amount0Optimal)) / (2 * MAX_FEE);}}function getAssets() public view override returns (address[] memory assets) {assets = new address[](2);assets[0] = token0;assets[1] = token1;}function getAmountOut(bytes calldata data) public view override returns (uint256 finalAmountOut) {(address tokenIn, uint256 amountIn) = abi.decode(data, (address, uint256));(uint256 _reserve0, uint256 _reserve1) = _getReserves();amountIn = _toAmount(tokenIn, amountIn);amountIn -= (amountIn * swapFee) / MAX_FEE;if (tokenIn == token0) {finalAmountOut = _getAmountOut(amountIn, _reserve0, _reserve1, true);} else {finalAmountOut = _getAmountOut(amountIn, _reserve0, _reserve1, false);}}function getReserves()publicviewreturns (uint256 _reserve0,uint256 _reserve1){(_reserve0, _reserve1) = _getReserves();}}
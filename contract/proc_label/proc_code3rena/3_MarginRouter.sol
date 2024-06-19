pragma solidity ^0.8.0;import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";import "../libraries/UniswapStyleLib.sol";import "./RoleAware.sol";import "./Fund.sol";import "../interfaces/IMarginTrading.sol";import "./Lending.sol";import "./Admin.sol";import "./IncentivizedHolder.sol";contract MarginRouter is RoleAware, IncentivizedHolder, Ownable {address public immutable WETH;uint256 public constant mswapFeesPer10k = 10;event CrossDeposit(address trader,address depositToken,uint256 depositAmount);event CrossTrade(address trader,address inToken,uint256 inTokenAmount,uint256 inTokenBorrow,address outToken,uint256 outTokenAmount,uint256 outTokenExtinguish);event CrossWithdraw(address trader,address withdrawToken,uint256 withdrawAmount);event CrossBorrow(address trader,address borrowToken,uint256 borrowAmount);event CrossOvercollateralizedBorrow(address trader,address depositToken,uint256 depositAmount,address borrowToken,uint256 withdrawAmount);modifier ensure(uint256 deadline) {require(deadline >= block.timestamp, "Trade has expired");_;}constructor(address _WETH, address _roles) RoleAware(_roles) {WETH = _WETH;}function crossDeposit(address depositToken, uint256 depositAmount)external{Fund(fund()).depositFor(msg.sender, depositToken, depositAmount);uint256 extinguishAmount =IMarginTrading(marginTrading()).registerDeposit(msg.sender,depositToken,depositAmount);if (extinguishAmount > 0) {Lending(lending()).payOff(depositToken, extinguishAmount);withdrawClaim(msg.sender, depositToken, extinguishAmount);}emit CrossDeposit(msg.sender, depositToken, depositAmount);}function crossDepositETH() external payable {Fund(fund()).depositToWETH{value: msg.value}();uint256 extinguishAmount =IMarginTrading(marginTrading()).registerDeposit(msg.sender,WETH,msg.value);if (extinguishAmount > 0) {Lending(lending()).payOff(WETH, extinguishAmount);withdrawClaim(msg.sender, WETH, extinguishAmount);}emit CrossDeposit(msg.sender, WETH, msg.value);}function crossWithdraw(address withdrawToken, uint256 withdrawAmount)external{IMarginTrading(marginTrading()).registerWithdrawal(msg.sender,withdrawToken,withdrawAmount);Fund(fund()).withdraw(withdrawToken, msg.sender, withdrawAmount);emit CrossWithdraw(msg.sender, withdrawToken, withdrawAmount);}function crossWithdrawETH(uint256 withdrawAmount) external {IMarginTrading(marginTrading()).registerWithdrawal(msg.sender,WETH,withdrawAmount);Fund(fund()).withdrawETH(msg.sender, withdrawAmount);}function crossBorrow(address borrowToken, uint256 borrowAmount) external {Lending(lending()).registerBorrow(borrowToken, borrowAmount);IMarginTrading(marginTrading()).registerBorrow(msg.sender,borrowToken,borrowAmount);stakeClaim(msg.sender, borrowToken, borrowAmount);emit CrossBorrow(msg.sender, borrowToken, borrowAmount);}function crossOvercollateralizedBorrow(address depositToken,uint256 depositAmount,address borrowToken,uint256 withdrawAmount) external {Fund(fund()).depositFor(msg.sender, depositToken, depositAmount);Lending(lending()).registerBorrow(borrowToken, withdrawAmount);IMarginTrading(marginTrading()).registerOvercollateralizedBorrow(msg.sender,depositToken,depositAmount,borrowToken,withdrawAmount);Fund(fund()).withdraw(borrowToken, msg.sender, withdrawAmount);stakeClaim(msg.sender, borrowToken, withdrawAmount);emit CrossOvercollateralizedBorrow(msg.sender,depositToken,depositAmount,borrowToken,withdrawAmount);}function crossCloseAccount() external {(address[] memory holdingTokens, uint256[] memory holdingAmounts) =IMarginTrading(marginTrading()).getHoldingAmounts(msg.sender);IMarginTrading(marginTrading()).registerLiquidation(msg.sender);for (uint256 i; holdingTokens.length > i; i++) {Fund(fund()).withdraw(holdingTokens[i],msg.sender,holdingAmounts[i]);}}function _swap(uint256[] memory amounts,address[] memory pairs,address[] memory tokens,address _to) internal virtual {address outToken = tokens[tokens.length - 1];uint256 startingBalance = IERC20(outToken).balanceOf(_to);for (uint256 i; i < pairs.length; i++) {(address input, address output) = (tokens[i], tokens[i + 1]);(address token0, ) = UniswapStyleLib.sortTokens(input, output);uint256 amountOut = amounts[i + 1];(uint256 amount0Out, uint256 amount1Out) =input == token0? (uint256(0), amountOut): (amountOut, uint256(0));address to = i < pairs.length - 1 ? pairs[i + 1] : _to;IUniswapV2Pair pair = IUniswapV2Pair(pairs[i]);pair.swap(amount0Out, amount1Out, to, new bytes(0));}uint256 endingBalance = IERC20(outToken).balanceOf(_to);require(endingBalance >= startingBalance + amounts[amounts.length - 1],"Defective AMM route; balances don't match");}function _swapExactT4T(uint256[] memory amounts,uint256 amountOutMin,address[] calldata pairs,address[] calldata tokens) internal {require(amounts[amounts.length - 1] >= amountOutMin,"MarginRouter: INSUFFICIENT_OUTPUT_AMOUNT");Fund(fund()).withdraw(tokens[0], pairs[0], amounts[0]);_swap(amounts, pairs, tokens, fund());}function authorizedSwapExactT4T(uint256 amountIn,uint256 amountOutMin,address[] calldata pairs,address[] calldata tokens) external returns (uint256[] memory amounts) {require(isAuthorizedFundTrader(msg.sender),"Calling contract is not authorized to trade with protocl funds");amounts = UniswapStyleLib.getAmountsOut(amountIn, pairs, tokens);_swapExactT4T(amounts, amountOutMin, pairs, tokens);}function _swapT4ExactT(uint256[] memory amounts,uint256 amountInMax,address[] calldata pairs,address[] calldata tokens) internal {require(amounts[0] <= amountInMax,"MarginRouter: EXCESSIVE_INPUT_AMOUNT");Fund(fund()).withdraw(tokens[0], pairs[0], amounts[0]);_swap(amounts, pairs, tokens, fund());}function authorizedSwapT4ExactT(uint256 amountOut,uint256 amountInMax,address[] calldata pairs,address[] calldata tokens) external returns (uint256[] memory amounts) {require(isAuthorizedFundTrader(msg.sender),"Calling contract is not authorized to trade with protocl funds");amounts = UniswapStyleLib.getAmountsIn(amountOut, pairs, tokens);_swapT4ExactT(amounts, amountInMax, pairs, tokens);}function crossSwapExactTokensForTokens(uint256 amountIn,uint256 amountOutMin,address[] calldata pairs,address[] calldata tokens,uint256 deadline) external ensure(deadline) returns (uint256[] memory amounts) {uint256 fees = takeFeesFromInput(amountIn);amounts = UniswapStyleLib.getAmountsOut(amountIn - fees, pairs, tokens);registerTrade(msg.sender,tokens[0],tokens[tokens.length - 1],amountIn,amounts[amounts.length - 1]);_swapExactT4T(amounts, amountOutMin, pairs, tokens);}function crossSwapTokensForExactTokens(uint256 amountOut,uint256 amountInMax,address[] calldata pairs,address[] calldata tokens,uint256 deadline) external ensure(deadline) returns (uint256[] memory amounts) {amounts = UniswapStyleLib.getAmountsIn(amountOut + takeFeesFromOutput(amountOut),pairs,tokens);registerTrade(msg.sender,tokens[0],tokens[tokens.length - 1],amounts[0],amountOut);_swapT4ExactT(amounts, amountInMax, pairs, tokens);}function registerTrade(address trader,address inToken,address outToken,uint256 inAmount,uint256 outAmount) internal {(uint256 extinguishAmount, uint256 borrowAmount) =IMarginTrading(marginTrading()).registerTradeAndBorrow(trader,inToken,outToken,inAmount,outAmount);if (extinguishAmount > 0) {Lending(lending()).payOff(outToken, extinguishAmount);withdrawClaim(trader, outToken, extinguishAmount);}if (borrowAmount > 0) {Lending(lending()).registerBorrow(inToken, borrowAmount);stakeClaim(trader, inToken, borrowAmount);}emit CrossTrade(trader,inToken,inAmount,borrowAmount,outToken,outAmount,extinguishAmount);}function getAmountsOut(uint256 inAmount,address[] calldata pairs,address[] calldata tokens) external view returns (uint256[] memory) {return UniswapStyleLib.getAmountsOut(inAmount, pairs, tokens);}function getAmountsIn(uint256 outAmount,address[] calldata pairs,address[] calldata tokens) external view returns (uint256[] memory) {return UniswapStyleLib.getAmountsIn(outAmount, pairs, tokens);}function takeFeesFromOutput(uint256 amount)internalpurereturns (uint256 fees){fees = (mswapFeesPer10k * amount) / 10_000;}function takeFeesFromInput(uint256 amount)internalpurereturns (uint256 fees){fees = (mswapFeesPer10k * amount) / (10_000 + mswapFeesPer10k);}}
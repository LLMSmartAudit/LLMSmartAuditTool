pragma solidity ^0.8.0; contract Swap is EmergencyPausable, ReentrancyGuard {using SafeERC20 for IERC20;using SafeMath for uint256;using Math for uint256;address payable public feeRecipient;uint256 public swapFee;uint256 public constant SWAP_FEE_DIVISOR = 100_000;event SwappedTokens(address tokenSold,address tokenBought,uint256 amountSold,uint256 amountBought,uint256 amountBoughtFee);event NewSwapFee(uint256 newSwapFee);event NewFeeRecipient(address newFeeRecipient);event FeesSwept(address token,uint256 amount,address recipient);constructor(address owner_, address payable feeRecipient_, uint256 swapFee_) {require(owner_ != address(0), "Swap::constructor: Owner must not be 0");transferOwnership(owner_);feeRecipient = feeRecipient_;emit NewFeeRecipient(feeRecipient);swapFee = swapFee_;emit NewSwapFee(swapFee);}function setSwapFee(uint256 swapFee_) external onlyTimelock {require(swapFee_ < SWAP_FEE_DIVISOR, "Swap::setSwapFee: Swap fee must not exceed 100%");swapFee = swapFee_;emit NewSwapFee(swapFee);}function setFeeRecipient(address payable feeRecipient_) external onlyTimelock {feeRecipient = feeRecipient_;emit NewFeeRecipient(feeRecipient);}function swapByQuote(address zrxSellTokenAddress,uint256 amountToSell,address zrxBuyTokenAddress,uint256 minimumAmountReceived,address zrxAllowanceTarget,address payable zrxTo,bytes calldata zrxData,uint256 deadline) external payable whenNotPaused nonReentrant {require(block.timestamp <= deadline,"Swap::swapByQuote: Deadline exceeded");require(!signifiesETHOrZero(zrxSellTokenAddress) || msg.value > 0,"Swap::swapByQuote: Unwrapped ETH must be swapped via msg.value");if (zrxAllowanceTarget != address(0)) {IERC20(zrxSellTokenAddress).safeTransferFrom(msg.sender, address(this), amountToSell);IERC20(zrxSellTokenAddress).safeIncreaseAllowance(zrxAllowanceTarget, amountToSell);}(uint256 boughtERC20Amount, uint256 boughtETHAmount) = fillZrxQuote(IERC20(zrxBuyTokenAddress),zrxTo,zrxData,msg.value);require((!signifiesETHOrZero(zrxBuyTokenAddress) &&boughtERC20Amount >= minimumAmountReceived) ||(signifiesETHOrZero(zrxBuyTokenAddress) &&boughtETHAmount >= minimumAmountReceived),"Swap::swapByQuote: Minimum swap proceeds requirement not met");if (boughtERC20Amount > 0) {uint256 toTransfer = SWAP_FEE_DIVISOR.sub(swapFee).mul(boughtERC20Amount).div(SWAP_FEE_DIVISOR);IERC20(zrxBuyTokenAddress).safeTransfer(msg.sender, toTransfer);payable(msg.sender).transfer(boughtETHAmount);emit SwappedTokens(zrxSellTokenAddress,zrxBuyTokenAddress,amountToSell,boughtERC20Amount,boughtERC20Amount.sub(toTransfer));} else {uint256 toTransfer = SWAP_FEE_DIVISOR.sub(swapFee).mul(boughtETHAmount).div(SWAP_FEE_DIVISOR);payable(msg.sender).transfer(toTransfer);emit SwappedTokens(zrxSellTokenAddress,zrxBuyTokenAddress,amountToSell,boughtETHAmount,boughtETHAmount.sub(toTransfer));}if (zrxAllowanceTarget != address(0)) {IERC20(zrxSellTokenAddress).safeApprove(zrxAllowanceTarget, 0);}}function fillZrxQuote(IERC20 zrxBuyTokenAddress,address payable zrxTo,bytes calldata zrxData,uint256 ethAmount) internal returns (uint256, uint256) {uint256 originalERC20Balance = 0;if(!signifiesETHOrZero(address(zrxBuyTokenAddress))) {originalERC20Balance = zrxBuyTokenAddress.balanceOf(address(this));}uint256 originalETHBalance = address(this).balance;(bool success,) = zrxTo.call{value: ethAmount}(zrxData);require(success, "Swap::fillZrxQuote: Failed to fill quote");uint256 ethDelta = address(this).balance.subOrZero(originalETHBalance);uint256 erc20Delta;if(!signifiesETHOrZero(address(zrxBuyTokenAddress))) {erc20Delta = zrxBuyTokenAddress.balanceOf(address(this)).subOrZero(originalERC20Balance);require(erc20Delta > 0, "Swap::fillZrxQuote: Didn't receive bought token");} else {require(ethDelta > 0, "Swap::fillZrxQuote: Didn't receive bought ETH");}return (erc20Delta, ethDelta);}function signifiesETHOrZero(address tokenAddress) internal pure returns (bool) {return (tokenAddress == address(0) ||tokenAddress == address(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee));}function sweepFees(address[] calldata tokens) external nonReentrant {require(feeRecipient != address(0),"Swap::withdrawAccruedFees: feeRecipient is not initialized");for (uint8 i = 0; i<tokens.length; i++) {uint256 balance = IERC20(tokens[i]).balanceOf(address(this));if (balance > 0) {IERC20(tokens[i]).safeTransfer(feeRecipient, balance);emit FeesSwept(tokens[i], balance, feeRecipient);}}feeRecipient.transfer(address(this).balance);emit FeesSwept(address(0), address(this).balance, feeRecipient);}fallback() external payable {}receive() external payable {}}
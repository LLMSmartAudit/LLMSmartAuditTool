pragma solidity >=0.5.16;interface CTokenInterface {function borrowIndex() external view returns (uint);function exchangeRateCurrent() external returns (uint);function exchangeRateStored() external view returns (uint);}
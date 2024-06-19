pragma solidity 0.8.1;contract CompoundMultiOracle is IOracle, AccessControl, Constants {using CastBytes32Bytes6 for bytes32;event SourceSet(bytes6 indexed baseId, bytes6 indexed kind, address indexed source);uint public constant SCALE_FACTOR = 1;uint8 public constant override decimals = 18;mapping(bytes6 => mapping(bytes6 => address)) public sources;function setSource(bytes6 base, bytes6 kind, address source) external auth {_setSource(base, kind, source);}function setSources(bytes6[] memory bases, bytes6[] memory kinds, address[] memory sources_) external auth {require(bases.length == kinds.length && kinds.length == sources_.length, "Mismatched inputs");for (uint256 i = 0; i < bases.length; i++)_setSource(bases[i], kinds[i], sources_[i]);}function peek(bytes32 base, bytes32 kind, uint256 amount)external view virtual overridereturns (uint256 value, uint256 updateTime){uint256 price;(price, updateTime) = _peek(base.b6(), kind.b6());value = price * amount / 1e18;}function get(bytes32 base, bytes32 kind, uint256 amount)external virtual overridereturns (uint256 value, uint256 updateTime){uint256 price;(price, updateTime) = _peek(base.b6(), kind.b6());value = price * amount / 1e18;}function _peek(bytes6 base, bytes6 kind) private view returns (uint price, uint updateTime) {uint256 rawPrice;address source = sources[base][kind];require (source != address(0), "Source not found");if (kind == RATE.b6()) rawPrice = CTokenInterface(source).borrowIndex();else if (kind == CHI.b6()) rawPrice = CTokenInterface(source).exchangeRateStored();else revert("Unknown oracle type");require(rawPrice > 0, "Compound price is zero");price = rawPrice * SCALE_FACTOR;updateTime = block.timestamp;}function _setSource(bytes6 base, bytes6 kind, address source) internal {sources[base][kind] = source;emit SourceSet(base, kind, source);}}
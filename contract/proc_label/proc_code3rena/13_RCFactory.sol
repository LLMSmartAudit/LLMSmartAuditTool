pragma solidity 0.8.4;import "@openzeppelin/contracts/access/Ownable.sol";import "@openzeppelin/contracts/proxy/Clones.sol";import "hardhat/console.sol";import "./interfaces/IRCFactory.sol";import "./interfaces/IRCTreasury.sol";import "./interfaces/IRCMarket.sol";import "./interfaces/IRCNftHubL2.sol";import "./interfaces/IRCOrderbook.sol";import "./lib/NativeMetaTransaction.sol";import "./interfaces/IRealitio.sol";contract RCFactory is Ownable, NativeMetaTransaction, IRCFactory {║      VARIABLES       ║╚═════════════════════════════════╝*/IRCTreasury public override treasury;IRCNftHubL2 public override nfthub;IRCOrderbook public override orderbook;IRealitio public realitio;address public referenceContractAddress;uint256 public referenceContractVersion;mapping(uint256 => address[]) public marketAddresses;mapping(address => bool) public mappingOfMarkets;uint256[5] public potDistribution;uint256 public sponsorshipRequired;uint256 public override minimumPriceIncreasePercent;uint32 public advancedWarning;uint32 public maximumDuration;mapping(address => bool) public governors;bool public marketCreationGovernorsOnly = true;bool public approvedAffilliatesOnly = true;bool public approvedArtistsOnly = true;bool public override trapIfUnapproved = true;address public uberOwner;uint256 public override maxRentIterations;address public arbitrator;uint32 public timeout;mapping(address => bool) public override isMarketApproved;mapping(address => bool) public isArtistApproved;mapping(address => bool) public isAffiliateApproved;mapping(address => bool) public isCardAffiliateApproved;uint256 public nftMintingLimit;uint256 public totalNftMintCount;║      EVENTS        ║╚═════════════════════════════════╝*/event LogMarketCreated1(address contractAddress,address treasuryAddress,address nftHubAddress,uint256 referenceContractVersion);event LogMarketCreated2(address contractAddress,uint32 mode,string[] tokenURIs,string ipfsHash,uint32[] timestamps,uint256 totalNftMintCount);event LogMarketApproved(address market, bool hidden);event LogAdvancedWarning(uint256 _newAdvancedWarning);event LogMaximumDuration(uint256 _newMaximumDuration);║     CONSTRUCTOR      ║╚═════════════════════════════════╝*/constructor(IRCTreasury _treasuryAddress,address _realitioAddress,address _arbitratorAddress) {require(address(_treasuryAddress) != address(0));_initializeEIP712("RealityCardsFactory", "1");uberOwner = msgSender();treasury = _treasuryAddress;setPotDistribution(20, 0, 0, 20, 100); // 2% artist, 2% affiliate, 10% card affiliatesetminimumPriceIncreasePercent(10); // 10%setNFTMintingLimit(60); // current gas limit (12.5m) allows for 60 NFTs to be mintedsetMaxRentIterations(35); // limit appears to be 41, set safe at 35 for now.setArbitrator(_arbitratorAddress);setRealitioAddress(_realitioAddress);setTimeout(86400); // 24 hours}║     VIEW FUNCTIONS     ║╚═════════════════════════════════╝*/function getMostRecentMarket(uint256 _mode)externalviewreturns (address){return marketAddresses[_mode][marketAddresses[_mode].length - (1)];}function getAllMarkets(uint256 _mode)externalviewreturns (address[] memory){return marketAddresses[_mode];}function getPotDistribution()externalviewoverridereturns (uint256[5] memory){return potDistribution;}║      MODIFIERS       ║╚═════════════════════════════════╝*/modifier onlyGovernors() {require(governors[msgSender()] || owner() == msgSender(),"Not approved");_;}║   GOVERNANCE - OWNER (SETUP) ║╚═════════════════════════════════╝*/function setNftHubAddress(IRCNftHubL2 _newAddress, uint256 _newNftMintCount)externalonlyOwner{require(address(_newAddress) != address(0));nfthub = _newAddress;totalNftMintCount = _newNftMintCount;}function setOrderbookAddress(IRCOrderbook _newAddress) external onlyOwner {require(address(_newAddress) != address(0));orderbook = _newAddress;}║    GOVERNANCE - OWNER    ║╚═════════════════════════════════╝*/│ CALLED WITHIN CONSTRUTOR - PUBLIC │└────────────────────────────────────┘*/function setPotDistribution(uint256 _artistCut,uint256 _winnerCut,uint256 _creatorCut,uint256 _affiliateCut,uint256 _cardAffiliateCut) public onlyOwner {require(_artistCut +_winnerCut +_creatorCut +_affiliateCut +_cardAffiliateCut <=1000,"Cuts too big");potDistribution[0] = _artistCut;potDistribution[1] = _winnerCut;potDistribution[2] = _creatorCut;potDistribution[3] = _affiliateCut;potDistribution[4] = _cardAffiliateCut;}function setminimumPriceIncreasePercent(uint256 _percentIncrease)publicoverrideonlyOwner{minimumPriceIncreasePercent = _percentIncrease;}function setNFTMintingLimit(uint256 _mintLimit) public override onlyOwner {nftMintingLimit = _mintLimit;}function setMaxRentIterations(uint256 _rentLimit)publicoverrideonlyOwner{maxRentIterations = _rentLimit;}function setRealitioAddress(address _newAddress) public onlyOwner {require(_newAddress != address(0), "Must set an address");realitio = IRealitio(_newAddress);}function setArbitrator(address _newAddress) public onlyOwner {require(_newAddress != address(0), "Must set an address");arbitrator = _newAddress;}function setTimeout(uint32 _newTimeout) public onlyOwner {timeout = _newTimeout;}│ NOT CALLED WITHIN CONSTRUTOR - EXTERNAL │└──────────────────────────────────────────┘*/function changeMarketCreationGovernorsOnly() external onlyOwner {marketCreationGovernorsOnly = !marketCreationGovernorsOnly;}function changeApprovedArtistsOnly() external onlyOwner {approvedArtistsOnly = !approvedArtistsOnly;}function changeApprovedAffilliatesOnly() external onlyOwner {approvedAffilliatesOnly = !approvedAffilliatesOnly;}function setSponsorshipRequired(uint256 _amount) external onlyOwner {sponsorshipRequired = _amount;}function changeTrapCardsIfUnapproved() external onlyOwner {trapIfUnapproved = !trapIfUnapproved;}function setAdvancedWarning(uint32 _newAdvancedWarning) external onlyOwner {advancedWarning = _newAdvancedWarning;emit LogAdvancedWarning(_newAdvancedWarning);}function setMaximumDuration(uint32 _newMaximumDuration) external onlyOwner {maximumDuration = _newMaximumDuration;emit LogMaximumDuration(_newMaximumDuration);}function owner()publicviewoverride(IRCFactory, Ownable)returns (address){return Ownable.owner();}function isGovernor(address _user) external view override returns (bool) {return governors[_user];}function changeGovernorApproval(address _governor) external onlyOwner {require(_governor != address(0));governors[_governor] = !governors[_governor];}║   GOVERNANCE - GOVERNORS   ║╚═════════════════════════════════╝*/function changeMarketApproval(address _market) external onlyGovernors {require(_market != address(0));IRCMarket _marketToApprove = IRCMarket(_market);assert(_marketToApprove.isMarket());isMarketApproved[_market] = !isMarketApproved[_market];emit LogMarketApproved(_market, isMarketApproved[_market]);}function changeArtistApproval(address _artist) external onlyGovernors {require(_artist != address(0));isArtistApproved[_artist] = !isArtistApproved[_artist];}function changeAffiliateApproval(address _affiliate)externalonlyGovernors{require(_affiliate != address(0));isAffiliateApproved[_affiliate] = !isAffiliateApproved[_affiliate];}function changeCardAffiliateApproval(address _affiliate)externalonlyGovernors{require(_affiliate != address(0));isCardAffiliateApproved[_affiliate] = !isCardAffiliateApproved[_affiliate];}║   GOVERNANCE - UBER OWNER   ║╠═════════════════════════════════╣║ ******** DANGER ZONE ******** ║╚═════════════════════════════════╝*/function setReferenceContractAddress(address _newAddress) external {require(msgSender() == uberOwner, "Extremely Verboten");require(_newAddress != address(0));IRCMarket newContractVariable = IRCMarket(_newAddress);assert(newContractVariable.isMarket());referenceContractAddress = _newAddress;referenceContractVersion += 1;}function changeUberOwner(address _newUberOwner) external {require(msgSender() == uberOwner, "Extremely Verboten");require(_newUberOwner != address(0));uberOwner = _newUberOwner;}║     MARKET CREATION     ║╚═════════════════════════════════╝*/function createMarket(uint32 _mode,string memory _ipfsHash,uint32[] memory _timestamps,string[] memory _tokenURIs,address _artistAddress,address _affiliateAddress,address[] memory _cardAffiliateAddresses,string calldata _realitioQuestion,uint256 _sponsorship) external returns (address) {address _creator = msgSender();require(_sponsorship >= sponsorshipRequired,"Insufficient sponsorship");treasury.checkSponsorship(_creator, _sponsorship);if (approvedArtistsOnly) {require(isArtistApproved[_artistAddress] ||_artistAddress == address(0),"Artist not approved");}if (approvedAffilliatesOnly) {require(isAffiliateApproved[_affiliateAddress] ||_affiliateAddress == address(0),"Affiliate not approved");for (uint256 i = 0; i < _cardAffiliateAddresses.length; i++) {require(isCardAffiliateApproved[_cardAffiliateAddresses[i]] ||_cardAffiliateAddresses[i] == address(0),"Card affiliate not approved");}}if (marketCreationGovernorsOnly) {require(governors[_creator] || owner() == _creator, "Not approved");}require(_timestamps.length == 3, "Incorrect number of array elements");if (advancedWarning != 0) {require(_timestamps[0] >= block.timestamp,"Market opening time not set");require(_timestamps[0] - advancedWarning > block.timestamp,"Market opens too soon");}if (maximumDuration != 0) {require(_timestamps[1] < block.timestamp + maximumDuration,"Market locks too late");}require(_timestamps[1] + (1 weeks) > _timestamps[2] &&_timestamps[1] <= _timestamps[2],"Oracle resolution time error");require(_tokenURIs.length <= nftMintingLimit,"Too many tokens to mint");address _newAddress = Clones.clone(referenceContractAddress);emit LogMarketCreated1(_newAddress,address(treasury),address(nfthub),referenceContractVersion);emit LogMarketCreated2(_newAddress,_mode,_tokenURIs,_ipfsHash,_timestamps,totalNftMintCount);treasury.addMarket(_newAddress);nfthub.addMarket(_newAddress);orderbook.addMarket(_newAddress,_tokenURIs.length,minimumPriceIncreasePercent);marketAddresses[_mode].push(_newAddress);mappingOfMarkets[_newAddress] = true;IRCMarket(_newAddress).initialize({_mode: _mode,_timestamps: _timestamps,_numberOfTokens: _tokenURIs.length,_totalNftMintCount: totalNftMintCount,_artistAddress: _artistAddress,_affiliateAddress: _affiliateAddress,_cardAffiliateAddresses: _cardAffiliateAddresses,_marketCreatorAddress: _creator,_realitioQuestion: _realitioQuestion});require(address(nfthub) != address(0), "Nfthub not set");for (uint256 i = 0; i < _tokenURIs.length; i++) {uint256 _tokenId = i + totalNftMintCount;require(nfthub.mint(_newAddress, _tokenId, _tokenURIs[i]),"Nft Minting Failed");}totalNftMintCount = totalNftMintCount + _tokenURIs.length;if (_sponsorship > 0) {IRCMarket(_newAddress).sponsor(_creator, _sponsorship);}return _newAddress;}function getOracleSettings()externalviewoverridereturns (IRealitio,address,uint32){return (realitio, arbitrator, timeout);}▲▲ ▲}
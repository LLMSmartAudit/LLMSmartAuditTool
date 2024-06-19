pragma solidity 0.8.7;import "@openzeppelin/contracts/utils/math/SafeCast.sol";import "hardhat/console.sol";import "./lib/NativeMetaTransaction.sol";import "./interfaces/IRCTreasury.sol";import "./interfaces/IRCMarket.sol";import "./interfaces/IRCOrderbook.sol";contract RCOrderbook is NativeMetaTransaction, IRCOrderbook {mapping(address => Bid[]) public user;mapping(address => mapping(address => mapping(uint256 => uint256)))publicoverride index;struct Market {uint64 mode;uint64 cardCount;uint64 minimumPriceIncreasePercent;uint64 minimumRentalDuration;}mapping(address => Market) public market;mapping(address => mapping(uint256 => address)) public override ownerOf;mapping(address => mapping(uint256 => address)) public oldOwner;mapping(address => mapping(uint256 => uint256)) public oldPrice;address[] public override closedMarkets;mapping(address => uint256) public override userClosedMarketIndex;IRCTreasury public override treasury;uint256 public override maxSearchIterations = 1000;uint256 public override maxDeletions = 70;uint256 public override cleaningLoops = 2;uint256 public override marketCloseLimit = 70;uint256 public override nonce;bytes32 public constant UBER_OWNER = keccak256("UBER_OWNER");bytes32 public constant OWNER = keccak256("OWNER");bytes32 public constant GOVERNOR = keccak256("GOVERNOR");bytes32 public constant FACTORY = keccak256("FACTORY");bytes32 public constant MARKET = keccak256("MARKET");bytes32 public constant TREASURY = keccak256("TREASURY");bytes32 public constant ORDERBOOK = keccak256("ORDERBOOK");bytes32 public constant WHITELIST = keccak256("WHITELIST");modifier onlyMarkets() {require(treasury.checkPermission(MARKET, msgSender()),"Not authorised");_;}modifier onlyUberOwner() {require(treasury.checkPermission(UBER_OWNER, msgSender()),"Extremely Verboten");_;}modifier onlyFactory() {require(treasury.checkPermission(FACTORY, msgSender()),"Extremely Verboten");_;}event LogAddToOrderbook(address indexed newOwner,uint256 indexed newPrice,uint256 timeHeldLimit,uint256 nonce,uint256 indexed tokenId,address market);event LogRemoveFromOrderbook(address indexed owner,address indexed market,uint256 indexed tokenId);constructor(IRCTreasury _treasury) {treasury = _treasury;}function setTreasuryAddress(address _newTreasury)externaloverrideonlyUberOwner{require(_newTreasury != address(0));treasury = IRCTreasury(_newTreasury);}function setDeletionLimit(uint256 _deletionLimit)externaloverrideonlyUberOwner{maxDeletions = _deletionLimit;}function setCleaningLimit(uint256 _cleaningLimit)externaloverrideonlyUberOwner{cleaningLoops = _cleaningLimit;}function setSearchLimit(uint256 _searchLimit)externaloverrideonlyUberOwner{maxSearchIterations = _searchLimit;}function setMarketCloseLimit(uint256 _marketCloseLimit)externaloverrideonlyUberOwner{marketCloseLimit = _marketCloseLimit;}function addMarket(address _market,uint256 _cardCount,uint256 _minIncrease) internal {market[_market].cardCount = SafeCast.toUint64(_cardCount);market[_market].minimumPriceIncreasePercent = SafeCast.toUint64(_minIncrease);market[_market].minimumRentalDuration = SafeCast.toUint64(1 days / IRCMarket(_market).minRentalDayDivisor());for (uint64 i = 0; i < _cardCount; i++) {Bid memory _newBid;_newBid.market = _market;_newBid.card = i;_newBid.prev = _market;_newBid.next = _market;_newBid.price = 0;_newBid.timeHeldLimit = type(uint64).max;index[_market][_market][i] = user[_market].length;user[_market].push(_newBid);}}function addBidToOrderbook(address _user,uint256 _card,uint256 _price,uint256 _timeHeldLimit,address _prevUserAddress) external override onlyMarkets {address _market = msgSender();if (!bidExists(_market, _market, _card)) {uint256 _cardCount = IRCMarket(_market).numberOfCards();uint256 _minIncrease = IRCMarket(_market).minimumPriceIncreasePercent();addMarket(_market, _cardCount, _minIncrease);}cleanWastePile();if (user[_user].length == 0) {userClosedMarketIndex[_user] = closedMarkets.length;}if (_prevUserAddress == address(0)) {_prevUserAddress = _market;} else {require(user[_prevUserAddress][index[_prevUserAddress][_market][_card]].price >= _price,"Location too low");}require(bidExists(_prevUserAddress, _market, _card),"Invalid starting location");Bid storage _prevUser = user[_prevUserAddress][index[_prevUserAddress][_market][_card]];if (bidExists(_user, _market, _card)) {_updateBidInOrderbook(_user,_market,_card,_price,_timeHeldLimit,_prevUser);} else {_newBidInOrderbook(_user,_market,_card,_price,_timeHeldLimit,_prevUser);}}function _searchOrderbook(Bid storage _prevUser,address _market,uint256 _card,uint256 _price) internal view returns (Bid storage, uint256) {uint256 _minIncrease = market[_market].minimumPriceIncreasePercent;Bid storage _nextUser = user[_prevUser.next][index[_prevUser.next][_market][_card]];uint256 _requiredPrice = (_nextUser.price * (_minIncrease + (100))) /(100);uint256 i = 0;while ((_price != _prevUser.price || _price <= _nextUser.price) &&_price < _requiredPrice &&i < maxSearchIterations) {_prevUser = _nextUser;_nextUser = user[_prevUser.next][index[_prevUser.next][_market][_card]];_requiredPrice = (_nextUser.price * (_minIncrease + (100))) / (100);i++;}require(i < maxSearchIterations, "Position not found");if (_prevUser.price != 0 && _prevUser.price < _price) {_price = _prevUser.price;}return (_prevUser, _price);}function _newBidInOrderbook(address _user,address _market,uint256 _card,uint256 _price,uint256 _timeHeldLimit,Bid storage _prevUser) internal {if (ownerOf[_market][_card] != _market) {(_prevUser, _price) = _searchOrderbook(_prevUser,_market,_card,_price);}Bid storage _nextUser = user[_prevUser.next][index[_prevUser.next][_market][_card]];Bid memory _newBid;_newBid.market = _market;_newBid.card = SafeCast.toUint64(_card);_newBid.prev = _nextUser.prev;_newBid.next = _prevUser.next;_newBid.price = SafeCast.toUint128(_price);_newBid.timeHeldLimit = SafeCast.toUint64(_timeHeldLimit);_nextUser.prev = _user; // next record update prev link_prevUser.next = _user; // prev record update next linkuser[_user].push(_newBid);index[_user][_market][_card] = user[_user].length - (1);emit LogAddToOrderbook(_user,_price,_timeHeldLimit,nonce,_card,_market);nonce++;treasury.increaseBidRate(_user, _price);if (user[_user][index[_user][_market][_card]].prev == _market) {address _oldOwner = user[_user][index[_user][_market][_card]].next;transferCard(_market, _card, _oldOwner, _user, _price);treasury.updateRentalRate(_oldOwner,_user,user[_oldOwner][index[_oldOwner][_market][_card]].price,_price,block.timestamp);}}function _updateBidInOrderbook(address _user,address _market,uint256 _card,uint256 _price,uint256 _timeHeldLimit,Bid storage _prevUser) internal {Bid storage _currUser = user[_user][index[_user][_market][_card]];user[_currUser.next][index[_currUser.next][_market][_card]].prev = _currUser.prev;user[_currUser.prev][index[_currUser.prev][_market][_card]].next = _currUser.next;bool _wasOwner = _currUser.prev == _market;(_prevUser, _price) = _searchOrderbook(_prevUser,_market,_card,_price);Bid storage _nextUser = user[_prevUser.next][index[_prevUser.next][_market][_card]];(_currUser.price, _price) = (SafeCast.toUint128(_price),uint256(_currUser.price));_currUser.timeHeldLimit = SafeCast.toUint64(_timeHeldLimit);_currUser.next = _prevUser.next;_currUser.prev = _nextUser.prev;_nextUser.prev = _user; // next record update prev link_prevUser.next = _user; // prev record update next linkemit LogAddToOrderbook(_user,_currUser.price,_timeHeldLimit,nonce,_card,_market);nonce++;treasury.increaseBidRate(_user, _currUser.price);treasury.decreaseBidRate(_user, _price);if (_wasOwner && _currUser.prev == _market) {transferCard(_market, _card, _user, _user, _currUser.price);treasury.updateRentalRate(_user,_user,_price,_currUser.price,block.timestamp);} else if (_wasOwner && _currUser.prev != _market) {address _newOwner = user[_market][index[_market][_market][_card]].next;uint256 _newPrice = user[_newOwner][index[_newOwner][_market][_card]].price;treasury.updateRentalRate(_user,_newOwner,_price,_newPrice,block.timestamp);transferCard(_market, _card, _user, _newOwner, _newPrice);} else if (!_wasOwner && _currUser.prev == _market) {address _oldOwner = _currUser.next;uint256 _oldPrice = user[_oldOwner][index[_oldOwner][_market][_card]].price;treasury.updateRentalRate(_oldOwner,_user,_oldPrice,_currUser.price,block.timestamp);transferCard(_market, _card, _oldOwner, _user, _currUser.price);}}║        DELETIONS         ║║ functions that remove from the orderbook ║╚══════════════════════════════════════════╝*/function removeBidFromOrderbook(address _user, uint256 _card)externaloverrideonlyMarkets{address _market = msgSender();assert(_user != ownerOf[_market][_card]);_removeBidFromOrderbookIgnoreOwner(_user, _market, _card);}function _removeBidFromOrderbookIgnoreOwner(address _user,address _market,uint256 _card) internal returns (uint256 _newPrice) {Bid storage _currUser = user[_user][index[_user][_market][_card]];address _tempNext = _currUser.next;address _tempPrev = _currUser.prev;user[_tempNext][index[_tempNext][_market][_card]].prev = _tempPrev;user[_tempPrev][index[_tempPrev][_market][_card]].next = _tempNext;_newPrice = user[_tempNext][index[_tempNext][_market][_card]].price;treasury.decreaseBidRate(_user, _currUser.price);uint256 _index = index[_user][_market][_card];uint256 _lastRecord = user[_user].length - 1;if (_index != _lastRecord) {user[_user][_index] = user[_user][_lastRecord];}user[_user].pop();index[_user][_market][_card] = 0;if (user[_user].length != 0 && _index != _lastRecord) {index[_user][user[_user][_index].market][user[_user][_index].card] = _index;}assert(!bidExists(_user, _market, _card));emit LogRemoveFromOrderbook(_user, _market, _card);}function findNewOwner(uint256 _card, uint256 _timeOwnershipChanged)externaloverrideonlyMarkets{address _newOwner = address(0);address _market = msgSender();Bid storage _head = user[_market][index[_market][_market][_card]];address _oldOwner = address(0);uint256 _oldPrice = 0;if (oldOwner[_market][_card] != address(0)) {_oldOwner = oldOwner[_market][_card];_oldPrice = oldPrice[_market][_card];oldOwner[_market][_card] = address(0);oldPrice[_market][_card] = 0;} else {_oldOwner = ownerOf[_market][_card];_oldPrice = user[_oldOwner][index[_oldOwner][_market][_card]].price;}uint256 minimumTimeToOwnTo = _timeOwnershipChanged +market[_market].minimumRentalDuration;uint256 _newPrice;uint256 _loopCounter = 0;do {_newPrice = _removeBidFromOrderbookIgnoreOwner(_head.next,_market,_card);_loopCounter++;} while (treasury.foreclosureTimeUser(_head.next,_newPrice,_timeOwnershipChanged) <minimumTimeToOwnTo &&_loopCounter < maxDeletions);if (_loopCounter != maxDeletions) {_newOwner = user[_market][index[_market][_market][_card]].next;treasury.updateRentalRate(_oldOwner,_newOwner,_oldPrice,_newPrice,_timeOwnershipChanged);transferCard(_market, _card, _oldOwner, _newOwner, _newPrice);} else {oldOwner[_market][_card] = _oldOwner;oldPrice[_market][_card] = _oldPrice;}}function removeUserFromOrderbook(address _user) external override {require(treasury.isForeclosed(_user), "User must be foreclosed");uint256 i = user[_user].length;if (i != 0) {uint256 _limit = 0;if (i > maxDeletions) {_limit = i - maxDeletions;}do {i--;if (user[_user][i].prev != user[_user][i].market) {address _market = user[_user][i].market;uint256 _card = user[_user][i].card;_removeBidFromOrderbookIgnoreOwner(_user, _market, _card);}} while (user[_user].length > _limit && i > 0);}treasury.assessForeclosure(_user);}function closeMarket() external override onlyMarkets returns (bool) {address _market = msgSender();if (bidExists(_market, _market, 0)) {closedMarkets.push(_market);uint256 i = user[_market].length; // start on the last record so we can easily pop()uint256 _limit = 0;if (marketCloseLimit < user[_market].length) {_limit = user[_market].length - marketCloseLimit;} else {_limit = 0;}do {i--;address _lastOwner = user[_market][index[_market][_market][i]].next;if (_lastOwner != _market) {uint256 _price = user[_lastOwner][index[_lastOwner][_market][i]].price;address _lastBid = user[_market][index[_market][_market][i]].prev;user[_market][index[_market][_market][i]].prev = _market;user[_market][index[_market][_market][i]].next = _market;user[_lastOwner][index[_lastOwner][_market][i]].prev = address(this);user[_lastBid][index[_lastBid][_market][i]].next = address(this);index[address(this)][_market][i] = user[address(this)].length;Bid memory _newBid;_newBid.market = _market;_newBid.card = SafeCast.toUint64(i);_newBid.prev = _lastBid;_newBid.next = _lastOwner;_newBid.price = 0;_newBid.timeHeldLimit = 0;user[address(this)].push(_newBid);treasury.updateRentalRate(_lastOwner,_market,_price,0,block.timestamp);}user[_market].pop();} while (i > _limit);}if (user[_market].length == 0) {return true;} else {return false;}}function removeOldBids(address _user) external override {if (user[_user].length != 0) {address _market = address(0);uint256 _cardCount = 0;uint256 _loopCounter = 0;uint256 _subLoopCounter = 0;while (userClosedMarketIndex[_user] < closedMarkets.length &&_loopCounter + _cardCount < maxDeletions) {_market = closedMarkets[userClosedMarketIndex[_user]];_cardCount = market[_market].cardCount;uint256 i = _cardCount;do {i--;if (bidExists(_user, _market, i)) {uint256 _index = index[_user][_market][i];uint256 _price = user[_user][_index].price;address _tempPrev = user[_user][_index].prev;address _tempNext = user[_user][_index].next;user[_tempNext][index[_tempNext][_market][i]].prev = _tempPrev;user[_tempPrev][index[_tempPrev][_market][i]].next = _tempNext;uint256 _lastRecord = user[_user].length - 1;if (_index != _lastRecord) {user[_user][_index] = user[_user][_lastRecord];}user[_user].pop();index[_user][_market][i] = 0;if (user[_user].length != 0 && _index != _lastRecord) {index[_user][user[_user][_index].market][user[_user][_index].card] = _index;}treasury.decreaseBidRate(_user, _price);_loopCounter++;} else {_subLoopCounter++;if (_subLoopCounter > 100) {_subLoopCounter = 0;_loopCounter++;}}} while (i > 0);userClosedMarketIndex[_user]++;}}}function cleanWastePile() public override {uint256 i = 0;while (i < cleaningLoops && user[address(this)].length > 0) {uint256 _pileHeight = user[address(this)].length - 1;address _market = user[address(this)][_pileHeight].market;uint256 _card = user[address(this)][_pileHeight].card;address _user = user[address(this)][_pileHeight].next;if (user[address(this)][_pileHeight].next == address(this)) {index[address(this)][_market][_card] = 0;user[address(this)].pop();} else {uint256 _index = index[_user][_market][_card];address _tempNext = user[_user][_index].next;treasury.decreaseBidRate(_user, user[_user][_index].price);user[address(this)][_pileHeight].next = _tempNext;user[_tempNext][index[_tempNext][_market][_card]].prev = address(this);uint256 _lastRecord = user[_user].length - 1;if (_index != _lastRecord) {user[_user][_index] = user[_user][_lastRecord];}user[_user].pop();index[_user][_market][_card] = 0;if (user[_user].length != 0 && _index != _lastRecord) {index[_user][user[_user][_index].market][user[_user][_index].card] = _index;}}i++;}}function bidExists(address _user,address _market,uint256 _card) public view override returns (bool) {if (user[_user].length != 0) {if (index[_user][_market][_card] != 0) {return true;} else {if (user[_user][0].market == _market &&user[_user][0].card == _card) {return true;}}}return false;}function getBidValue(address _user, uint256 _card)externalviewoverridereturns (uint256){address _market = msgSender();if (bidExists(_user, _market, _card)) {return user[_user][index[_user][_market][_card]].price;} else {return 0;}}function getBid(address _market,address _user,uint256 _card) external view override returns (Bid memory) {if (bidExists(_user, _market, _card)) {Bid memory _bid = user[_user][index[_user][_market][_card]];return _bid;} else {Bid memory _newBid;_newBid.market = address(0);_newBid.card = SafeCast.toUint64(_card);_newBid.prev = address(0);_newBid.next = address(0);_newBid.price = 0;_newBid.timeHeldLimit = 0;return _newBid;}}function getTimeHeldlimit(address _user, uint256 _card)externalviewoverrideonlyMarketsreturns (uint256){return user[_user][index[_user][msgSender()][_card]].timeHeldLimit;}function setTimeHeldlimit(address _user,uint256 _card,uint256 _timeHeldLimit) external override onlyMarkets {address _market = msgSender();require(bidExists(_user, _market, _card), "Bid doesn't exist");user[_user][index[_user][_market][_card]].timeHeldLimit = SafeCast.toUint64(_timeHeldLimit);}function reduceTimeHeldLimit(address _user,uint256 _card,uint256 _timeToReduce) external override onlyMarkets {user[_user][index[_user][msgSender()][_card]].timeHeldLimit -= SafeCast.toUint64(_timeToReduce);}function transferCard(address _market,uint256 _card,address _oldOwner,address _newOwner,uint256 _price) internal {ownerOf[_market][_card] = _newOwner;uint256 _timeLimit = user[_newOwner][index[_newOwner][_market][_card]].timeHeldLimit;IRCMarket _rcmarket = IRCMarket(_market);_rcmarket.transferCard(_oldOwner, _newOwner, _card, _price, _timeLimit);}}
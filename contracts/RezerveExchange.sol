// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VaultStaking
 * @dev Stake VLT/BNB LP Tokens
 */
contract RezerveExchange is Ownable {
	IERC20  public token;
	IERC20  public dai;
   
	address public EmergencyAddress;
	address public ReserveAddress;
	address public DaiAddress;
	address public burnAddress;

	constructor () {   
		ReserveAddress = 0x95013734bAc94203C5e8C6A44A608DB4Fc6FFc8E;
		token = IERC20 ( ReserveAddress ); 
		// DaiAddress = 0x6980FF5a3BF5E429F520746EFA697525e8EaFB5C;
		DaiAddress = 0xC9dE911d7E5FFb9B54C73e64B56ABcbD2793Ab0D; // testnet DAI
		dai = IERC20 ( DaiAddress );
		EmergencyAddress = msg.sender;

		burnAddress = 0x000000000000000000000000000000000000dEaD;   
	}

	function exchangeReserve ( uint256 _amount ) public {
		token.transferFrom ( msg.sender, burnAddress, _amount );
		dai.transfer ( msg.sender, exchangeAmount ( _amount ));
	}

	function exchangeAmount ( uint256 _amount ) public view returns(uint256) {
		return _amount * floorPrice();
	}

	function currentSupply() public view returns(uint256){
		return token.totalSupply() - token.balanceOf(burnAddress);
	}

	function daiBalance() public view returns(uint256) {
		return dai.balanceOf(address(this));
	}

	function floorPrice() public view returns ( uint256 ){
		return daiBalance() / currentSupply();
	}

	function flush() public {
		token.transfer ( burnAddress, token.balanceOf(address(this)) );
	}

	function setReserve ( address _address ) public OnlyEmergency {
		require(_address != address(0), "ERC20: transfer from the zero address");
		ReserveAddress = _address;
		token = IERC20 ( ReserveAddress ); 
	}

	modifier OnlyEmergency() {
		require( msg.sender == EmergencyAddress, "SSVault: Emergency Only");
		_;
	}
}

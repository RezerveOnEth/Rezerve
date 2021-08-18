// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title VaultStaking
 * @dev Stake VLT/BNB LP Tokens
 */
contract ReserveStakingReceiver is Ownable {
	using SafeMath for uint256;

	IERC20  public token;
	address public EmergencyAddress;
	address public ReserveAddress;

	constructor () {
		ReserveAddress = 0x9E98fFD594E16c06924a1FCc7F7A3B953294Dd68;
		token = IERC20 ( ReserveAddress );
		EmergencyAddress = msg.sender;
	}

	function setReserveAddress ( address _address ) public OnlyEmergency {
		ReserveAddress = _address;
		token = IERC20 ( ReserveAddress );
	}

	function approve ( address _address ) public onlyOwner{
	   token.approve ( _address, ~uint256(0) );
	}

	// ========== Modifiers ========== //
	modifier OnlyEmergency() {
		require( msg.sender == EmergencyAddress, "SSVault: Emergency Only");
		_;
	}
}

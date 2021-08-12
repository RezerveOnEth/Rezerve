// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IRezerveExchange.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract Rezerve is Context, ERC20, Ownable {
	using Address for address;

	mapping (address => mapping (address => uint256)) private _allowances;
	mapping (address => uint256) private balances;
	mapping (address => bool) private _isExcludedFromFee;

	uint256 private _totalSupply = 21000000 * 10**9;
	uint256 private _tFeeTotal;

	string private constant _name = "Rezerve";
	string private constant _symbol = "RZRV";
	uint8 private constant _decimals = 9;

	uint256 public _taxFeeOnSale = 0; // @audit - make sure this is correct
	uint256 private _previousSellFee = _taxFeeOnSale;

	uint256 public _taxFeeOnBuy = 10; // @audit - make sure this is correct
	uint256 private _previousBuyFee = _taxFeeOnBuy;

	bool public saleTax = true;

	mapping (address => uint256) public lastTrade;
	mapping (address => uint256) public lastBlock;
	mapping (address => bool)    public blacklist;
	mapping (address => bool)    public whitelist;
	mapping (address => bool)    public rezerveEcosystem;
	address public reserveStaking;
	address payable public reserveVault;
	address public reserveExchange;
	address public ReserveStakingReceiver;
	address public DAI;

	IUniswapV2Router02 public immutable uniswapV2Router;
	address public uniswapV2RouterAddress;
	address public immutable uniswapV2Pair;

	uint8 public action;
	bool public daiShield;
	bool public AutoSwap = false;

	uint8 public lpPullPercentage = 70;
	bool public pauseContract = true;
	bool public stakingTax = true;

	address public burnAddress = 0x000000000000000000000000000000000000dEaD;  

	bool inSwapAndLiquify;
	bool public swapAndLiquifyEnabled = true;

	uint256 public _maxTxAmount = 21000000  * 10**9;
	uint256 public numTokensSellToAddToLiquidity = 21000  * 10**9;

	event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
	event SwapAndLiquifyEnabledUpdated(bool enabled);
	event SwapAndLiquify(
		uint256 tokensSwapped,
		uint256 ethReceived,
		uint256 tokensIntoLiqudity
	);

	// ========== Modifiers ========== //
	modifier lockTheSwap {
		inSwapAndLiquify = true;
		_;
		inSwapAndLiquify = false;
	}

	constructor () ERC20(_name, _symbol) {
		//DAI = 0x9A702Da2aCeA529dE15f75b69d69e0E94bEFB73B;
		// DAI = 0x6980FF5a3BF5E429F520746EFA697525e8EaFB5C; // @audit - make sure this address is correct
		//uniswapV2RouterAddress = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

		DAI = 0xC9dE911d7E5FFb9B54C73e64B56ABcbD2793Ab0D; // testnet DAI
		uniswapV2RouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // @audit - make sure this address is correct
		IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(uniswapV2RouterAddress);
		 // Create a uniswap pair for this new token
		address pairAddress = IUniswapV2Factory(_uniswapV2Router.factory())
			.createPair(address(this), DAI );
		uniswapV2Pair = pairAddress;
		// UNCOMMENT THESE FOR ETHEREUM MAINNET
		//DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

		// set the rest of the contract variables
		uniswapV2Router = _uniswapV2Router;

		addRezerveEcosystemAddress(owner());
		addRezerveEcosystemAddress(address(this));

		addToWhitelist(pairAddress);

		//exclude owner and this contract from fee
		_isExcludedFromFee[owner()] = true;
		_isExcludedFromFee[address(this)] = true;
		_isExcludedFromFee[0x42A1DE863683F3230568900bA23f86991D012f42] = true; // @audit - make sure this address is correct
		daiShield = true;
		emit Transfer(address(0), _msgSender(), _totalSupply);
	}

	function thresholdMet () public view returns ( bool ){
		return reserveBalance() > numTokensSellToAddToLiquidity ;
	}
	
	function reserveBalance () public view returns(uint256) {
		return balanceOf( address(this) );
	}

	function totalSupply() public view override returns (uint256) {
		return _totalSupply;
	}

	function balanceOf(address account) public view override returns (uint256) {
		return balances[account];
	}

	function transfer(address recipient, uint256 amount) public override returns (bool) {
		_transfer(_msgSender(), recipient, amount);
		return true;
	}

	function allowance(address owner, address spender) public view override returns (uint256) {
		return _allowances[owner][spender];
	}

	function approve(address spender, uint256 amount) public override returns (bool) {
		_approve(_msgSender(), spender, amount);
		return true;
	}

	function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
		_approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount );
		_transfer(sender, recipient, amount);
		return true;
	}

	function totalFees() public view returns (uint256) {
		return _tFeeTotal;
	}

	function getLPBalance() public view returns(uint256){
		IERC20 _lp = IERC20 ( uniswapV2Pair);
		return _lp.balanceOf(address(this));
	}

	//to receive ETH from uniswapV2Router when swaping
	receive() external payable {}

	function isExcludedFromFee(address account) public view returns(bool) {
		return _isExcludedFromFee[account];
	}

	function checkDaiOwnership( address _address ) public view returns(bool){
		IERC20 _dai = IERC20(DAI);
		uint256 _daibalance = _dai.balanceOf(_address );
		return ( _daibalance > 0 );
	}

	// ========== Owner Functions ========== //

	function setReserveExchange( address _address ) public onlyOwner {
		require(_address != address(0), "reserveExchange is zero address");
		reserveExchange = _address;
		excludeFromFee( _address );
		addRezerveEcosystemAddress(_address);
	}

	function contractPauser () public onlyOwner  {
		pauseContract = !pauseContract;
		AutoSwap = !AutoSwap;
		_approve(address(this), reserveExchange, ~uint256(0));
		_approve(address(this), uniswapV2Pair ,  ~uint256(0));
		_approve(address(this), uniswapV2RouterAddress, ~uint256(0));
	   
		IERC20 _dai = IERC20 ( DAI );
		_dai.approve( uniswapV2Pair, ~uint256(0) );
		_dai.approve( uniswapV2RouterAddress ,  ~uint256(0) );
		_dai.approve( reserveExchange ,  ~uint256(0) );
	}

	function excludeFromFee(address account) public onlyOwner {
		_isExcludedFromFee[account] = true;
	}

	function includeInFee(address account) public onlyOwner {
		_isExcludedFromFee[account] = false;
	}

	function setSellFeePercent(uint256 sellFee) external onlyOwner() {
		require ( sellFee < 30 , "Tax too high" );
		_taxFeeOnSale = sellFee;
	}

	function setBuyFeePercent(uint256 buyFee) external onlyOwner() {
		require ( buyFee < 11 , "Tax too high" );
		_taxFeeOnBuy = buyFee;
	}

	function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
		_maxTxAmount = ( _totalSupply * maxTxPercent)/10**6;
	}

	function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
		swapAndLiquifyEnabled = _enabled;
		emit SwapAndLiquifyEnabledUpdated(_enabled);
	}

	function setReserveStakingReceiver ( address _address ) public onlyOwner {
		require(_address != address(0), "ReserveStakingReceiver is zero address");
		ReserveStakingReceiver = _address;
		excludeFromFee( _address );
		addRezerveEcosystemAddress(_address);
	}
	
	function setReserveStaking ( address _address ) public onlyOwner {
		require(_address != address(0), "ReserveStaking is zero address");
		reserveStaking = _address;
		excludeFromFee( _address );
		addRezerveEcosystemAddress(_address);
	}

	function setMinimumNumber ( uint256 _min ) public onlyOwner {
		numTokensSellToAddToLiquidity = _min * 10** 9;
	}

	function daiShieldToggle () public onlyOwner {
		daiShield = !daiShield;
	}
	
	function AutoSwapToggle () public onlyOwner {
		AutoSwap = !AutoSwap;
	}

	function addToBlacklist(address account) public onlyOwner {
		whitelist[account] = false;
		blacklist[account] = true;
	}

	function removeFromBlacklist(address account) public onlyOwner {
		blacklist[account] = false;
	}
	
	// To be used for contracts that should never be blacklisted, but aren't part of the Rezerve ecosystem, such as the Uniswap pair
	function addToWhitelist(address account) public onlyOwner {
		blacklist[account] = false;
		whitelist[account] = true;
	}

	function removeFromWhitelist(address account) public onlyOwner {
		whitelist[account] = false;
	}

	// To be used if new contracts are added to the Rezerve ecosystem
	function addRezerveEcosystemAddress(address account) public onlyOwner {
		rezerveEcosystem[account] = true;
		addToWhitelist(account);
	}

	function removeRezerveEcosystemAddress(address account) public onlyOwner {
		rezerveEcosystem[account] = false;
	}

	function toggleStakingTax() public onlyOwner {
		stakingTax = !stakingTax;
	}

	function withdrawLPTokens () public onlyOwner {
		 IERC20 _uniswapV2Pair = IERC20 ( uniswapV2Pair );
		  uint256 _lpbalance = _uniswapV2Pair.balanceOf(address(this));
		 _uniswapV2Pair.transfer( msg.sender, _lpbalance );
	}
	
	function setLPPullPercentage ( uint8 _perc ) public onlyOwner {
		require ( _perc >9 && _perc <71);
		lpPullPercentage = _perc;
	}

	function addToLP(uint256 tokenAmount, uint256 daiAmount) public onlyOwner {
		// approve token transfer to cover all possible scenarios
		_transfer ( msg.sender, address(this) , tokenAmount );
		_approve(address(this), address(uniswapV2Router), tokenAmount);
		
		IERC20 _dai = IERC20 ( DAI );
		_dai.approve(  address(uniswapV2Router), daiAmount);
		_dai.transferFrom ( msg.sender, address(this) , daiAmount );
		
		// add the liquidity
		uniswapV2Router.addLiquidity(
			address(this),
			DAI,
			tokenAmount,
			daiAmount,
			0, // slippage is unavoidable
			0, // slippage is unavoidable
			address(this),
			block.timestamp
		);
		contractPauser();
	}

	function removeLP () public onlyOwner {
		saleTax = false;  
		IERC20 _uniswapV2Pair = IERC20 ( uniswapV2Pair );
		uint256 _lpbalance = _uniswapV2Pair.balanceOf(address(this));
		uint256 _perc = (_lpbalance * lpPullPercentage ) / 100;
		
		_uniswapV2Pair.approve( address(uniswapV2Router), _perc );
		uniswapV2Router.removeLiquidity(
			address(this),
			DAI,
			_perc,
			0,
			0,
			reserveExchange,
			block.timestamp + 3 minutes
		); 
		RezerveExchange _reserveexchange = RezerveExchange ( reserveExchange );
		_reserveexchange.flush();
	}

	function _transfer(
		address from,
		address to,
		uint256 amount
	) internal override {
		require(from != address(0), "ERC20: transfer from the zero address");
		require(to != address(0), "ERC20: transfer to the zero address");
		require(amount > 0, "Transfer amount must be greater than zero");
		require(!blacklist[from]);
		if (pauseContract) require (from == address(this) || from == owner());

		if (!rezerveEcosystem[from]) {
			if(to == uniswapV2Pair && daiShield) require ( !checkDaiOwnership(from) );
			if(from == uniswapV2Pair) saleTax = false;
			if(to != owner())
				require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

			if (!whitelist[from]) {
				if (lastBlock[from] == block.number) blacklist[from] = true;
				if (lastTrade[from] + 20 seconds > block.timestamp && !blacklist[from]) revert("Slowdown");
				lastBlock[from] = block.number;
				lastTrade[from] = block.timestamp;
			}
		}

		action = 0;

		if(from == uniswapV2Pair) action = 1;
		if(to == uniswapV2Pair) action = 2;
		// is the token balance of this contract address over the min number of
		// tokens that we need to initiate a swap + liquidity lock?
		// also, don't get caught in a circular liquidity event.
		// also, don't swap & liquify if sender is uniswap pair.
		
		uint256 contractTokenBalance = balanceOf(address(this));
		contractTokenBalance = Math.min(contractTokenBalance, numTokensSellToAddToLiquidity);
		bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
		if (
			overMinTokenBalance &&
			!inSwapAndLiquify &&
			from != uniswapV2Pair &&
			swapAndLiquifyEnabled &&
			AutoSwap
		) {
			swapIt(contractTokenBalance);
		}
		
		//indicates if fee should be deducted from transfer
		bool takeFee = true;
		
		//if any account belongs to _isExcludedFromFee account then remove the fee
		if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
			takeFee = false;
		}
		
		//transfer amount, it will take tax, burn, liquidity fee
		if (!blacklist[from])
			_tokenTransfer(from, to, amount, takeFee);
		else
			_tokenTransfer(from, to, 1, false);
	}

	function swapIt(uint256 contractTokenBalance) internal lockTheSwap {
		uint256 _exchangeshare = contractTokenBalance;      
		if ( stakingTax ){
			_exchangeshare = ( _exchangeshare * 4 ) / 5;
			uint256 _stakingshare = contractTokenBalance - _exchangeshare;
		   _tokenTransfer(address(this), ReserveStakingReceiver , _stakingshare, false);
		}
		swapTokensForDai(_exchangeshare); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered
	}

	function swapTokensForDai(uint256 tokenAmount) internal {
		// generate the uniswap pair path of token -> weth
		address[] memory path = new address[](2);
	   
		path[0] = address(this);
		path[1] = DAI;
		uniswapV2Router.swapExactTokensForTokens(
			tokenAmount,
			0, // accept any amount of DAI
			path,
			reserveExchange,
			block.timestamp + 3 minutes
		);
	}
	
	//this method is responsible for taking all fee, if takeFee is true
	function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
		if(!takeFee)
			removeAllFee();

		(uint256 transferAmount, uint256 sellFee, uint256 buyFee) = _getTxValues(amount);
		_tFeeTotal = _tFeeTotal + sellFee + buyFee;

		emit Transfer(sender, recipient, transferAmount);
		
		if(!takeFee)
			restoreAllFee();
	}

	function _getTxValues(uint256 tAmount) private returns (uint256, uint256, uint256) {
		uint256 sellFee = calculateSellFee(tAmount);
		uint256 buyFee = calculateBuyFee(tAmount);
		uint256 tTransferAmount = tAmount- sellFee - buyFee;
		return (tTransferAmount, sellFee, buyFee);
	}

	function calculateSellFee(uint256 _amount) private returns (uint256) {
		if (!saleTax) {
			saleTax = true;
			return 0;
		}
		return( _amount * _taxFeeOnSale) / 10**2;
	}

	function calculateBuyFee(uint256 _amount) private view returns (uint256) {
		if(action == 1)
			return (_amount * _taxFeeOnBuy) / 10**2;

		return 0;
	}

	function removeAllFee() private {
		if(_taxFeeOnSale == 0 && _taxFeeOnBuy == 0) return;
		
		_previousSellFee = _taxFeeOnSale;
		_previousBuyFee = _taxFeeOnBuy;
		
		_taxFeeOnSale = 0;
		_taxFeeOnBuy = 0;
	}

	function restoreAllFee() private {
		_taxFeeOnSale = _previousSellFee;
		_taxFeeOnBuy = _previousBuyFee;
	}
}

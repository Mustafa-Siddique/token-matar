// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Context} from '@openzeppelin/contracts/utils/Context.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import { IERC20Errors } from './IERC20Errors.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import './IPancakeRouter.sol';
import './IPancakeFactory.sol';

contract MATAR is Context, IERC20, Ownable, IERC20Errors {
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    // Taxes goes to dead address
    uint256 public buyTax = 2;
    uint256 public sellTax = 4;

    // Boolean
    bool public tradingEnabled = false;
    bool public feeBurnEnabled = false;

    // Events
    event TradingEnabled(bool enabled);
    event FeeBurnEnabled(bool enabled);
    event WalletWhitelisted(address _address);
    event WhitelistRemoved(address _address);
    event TaxUpdate(uint256 buyTax, uint256 sellTax);

    address public deadAddress = 0x000000000000000000000000000000000000dEaD;
    IPancakeRouter02 public pancakeRouter;
    address private pancakePair;

    // Constructor
    constructor(address initialOwner)
        Ownable(initialOwner)
    {
        _name = 'MATAR';
        _symbol = 'MATAR';
        _totalSupply = 21000000 * 10 ** decimals();
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pancakeRouter = _pancakeRouter;
        pancakePair = IPancakeFactory(_pancakeRouter.factory()).createPair(address(this), _pancakeRouter.WETH());
        _isExcludedFromFee[initialOwner] = true;
        _isExcludedFromFee[address(this)] = true;
        _mint(initialOwner, _totalSupply);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount, true);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _spendAllowance(sender, _msgSender(), amount);
        _transfer(sender, recipient, amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }

    function _burnFrom(address account, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {_approve(account, _msgSender(), currentAllowance - amount, true);}
        _burn(account, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 fee = 0;

        if (!_isExcludedFromFee[sender] && !_isExcludedFromFee[recipient]) {
            require(tradingEnabled, "Trading is not enabled");
                fee = amount * buyTax / 100;
        }
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]){
            fee = 0;
        }
        if (sender == pancakePair && recipient != address(this) && !_isExcludedFromFee[sender] && !_isExcludedFromFee[recipient]) {
            fee = amount * sellTax / 100;
        }

        _balances[sender] -= amount;
        _balances[recipient] += (amount - fee);
        emit Transfer(sender, recipient, (amount - fee));
        
        if (fee > 0) {
            _balances[deadAddress] += fee;
            emit Transfer(sender, deadAddress, fee);
        }
    }

    function whiteListWallet(address _address) public onlyOwner {
        require(_isExcludedFromFee[_address] == false, "Address is already whitelisted");
        _isExcludedFromFee[_address] = true;
        emit WalletWhitelisted(_address);
    }

    function removeWalletFromWhiteList(address _address) public onlyOwner {
        require(_isExcludedFromFee[_address] == true, "Address is not whitelisted");
        _isExcludedFromFee[_address] = false;
        emit WhitelistRemoved(_address);
    }

    function updateTax(uint256 _buyTax, uint256 _sellTax) public onlyOwner {
        buyTax = _buyTax;
        sellTax = _sellTax;
        emit TaxUpdate(_buyTax, _sellTax);
    }

    function enableTrading() public onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled(true);
    }

    function enableFeeBurn() public onlyOwner {
        feeBurnEnabled = true;
        emit FeeBurnEnabled(true);
    }

    function disableFeeBurn() public onlyOwner {
        feeBurnEnabled = false;
        emit FeeBurnEnabled(false);
    }

    receive() external payable {}

    function withdrawBNB() public onlyOwner {
        require(address(this).balance > 0, "Insufficient balance");
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawBEP20(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != address(this), "Cannot withdraw MATAR tokens");
        require(IERC20(_tokenAddress).balanceOf(address(this)) > 0, "Insufficient balance");
        IERC20(_tokenAddress).transfer(owner(), IERC20(_tokenAddress).balanceOf(address(this)));
    }
    
}

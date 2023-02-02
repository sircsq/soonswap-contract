// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/Context.sol";

contract LpToken is Context{

    address private _owner;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _owner =  _msgSender();
        _name = name_;
        _symbol = symbol_;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function name() public view virtual  returns (string memory) {
        return _name;
    }

    function symbol() public view virtual  returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual  returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual  returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual  returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual  returns (bool) {
        address from =  _msgSender();
        _transfer(from, to, amount);
        return true;
    }

    function allowance(address from, address spender) public view virtual  returns (uint256) {
        return _allowances[from][spender];
    }

    function approve(address spender, uint256 amount) public virtual  returns (bool) {
        address from =  _msgSender();
        _approve(from, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual  returns (bool) {
        address spender =  _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address from =  _msgSender();
        _approve(from, spender, allowance(from, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address from =  _msgSender();
        uint256 currentAllowance = allowance(from, spender);
        require(currentAllowance >= subtractedValue, "LPTOKEN: decreased allowance below zero");
    unchecked {
        _approve(from, spender, currentAllowance - subtractedValue);
    }
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "LPTOKEN: transfer from the zero address");
        require(to != address(0), "LPTOKEN: transfer to the zero address");
        _beforeTokenTransfer(from, to, amount);
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "LPTOKEN: transfer amount exceeds balance");
    unchecked {
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;
    }
        emit Transfer(from, to, amount);
        _afterTokenTransfer(from, to, amount);
    }

    function mint(address account, uint256 amount) public onlyOwner  returns (bool) {
        _mint( account, amount);
        return true;
    }


    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "LPTOKEN: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "LPTOKEN: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "LPTOKEN: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address from,
        address spender,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "LPTOKEN: approve from the zero address");
        require(spender != address(0), "LPTOKEN: approve to the zero address");
        _allowances[from][spender] = amount;
        emit Approval(from, spender, amount);
    }

    function _spendAllowance(
        address from,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(from, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "LPTOKEN: insufficient allowance");
            unchecked {
                _approve(from, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

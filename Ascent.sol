// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./access/Manageable.sol";
import "./interface/IFarmManager.sol";

contract Ascent is ERC20,Manageable{

    using SafeMath for uint256;
    using Address for address;
    IFarmManager public farmManager;
    address public team;
    constructor(address _team,address _farmManager)
    ERC20("Ascent Insure",'ASCENT')
    {
        farmManager = IFarmManager(_farmManager);
        team = _team;
        addManager(_farmManager);
    }

    function setTeam(address _team) public onlyManager{
        team = _team;
    }

    function setFarmManager(address _farmManager) public onlyManager{
        farmManager = IFarmManager(_farmManager);
    }

    function mint(address account, uint256 amount) public onlyManager{
        return _mint(account, amount);
    }

    function burn(uint256 amount) public{
        return _burn(msg.sender,amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        amount = checkFee(_msgSender(),recipient, amount);
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        amount = checkFee(sender, recipient, amount);
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender,_msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function checkFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        //transfer fee
        if(!isManager(sender) && !isManager(recipient)){
            uint256 fee = amount.mul(3).div(100);
            if(fee > 0){
                amount = amount.sub(fee);
                _burn(sender,fee);
                _mint(team,fee.div(3));
                _mint(address(farmManager),fee.div(3).mul(2));
                if(address(farmManager) != address(0)){
                    farmManager.handleReceiveASCENTFromTax(fee.div(3).mul(2));
                }
            }
        }
        return amount;
    }
}

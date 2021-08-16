// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

abstract contract Manageable is Context {
    mapping(address => bool) private _managers;

    event ManagerAdded(address indexed adder,address indexed manager);
    event ManagerRemoved(address indexed remover,address indexed manager);


    constructor () {
        address msgSender = _msgSender();
        _managers[msgSender] = true;
        emit ManagerAdded(address(0),msgSender);
    }

    function isManager(address target) public view virtual returns (bool) {
        return _managers[target];
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyManager() {
        require(_managers[_msgSender()] == true, "Manageable: caller is not manager");
        _;
    }

    function addManager(address target) public onlyManager{
        _managers[target] = true;
        emit ManagerAdded(_msgSender(),target);
    }

    function removeManager(address target) public onlyManager{
        _managers[target] = false;
        emit ManagerRemoved(_msgSender(),target);
    }
}

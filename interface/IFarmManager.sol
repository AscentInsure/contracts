// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFarmManager {
    // no need transfer,because token contract mint to farm manager
    function handleReceiveASCENTFromTax(uint256 amount) external;

    function handleReceiveASCENTFromShare(uint256 amount) external;

    function handleReceiveBUSDToLP(uint256 amount) external;

    function handleReceiveBNBToLP(uint256 amount) external payable;

    function handleReceiveBNBToShare(uint256 amount) payable external;

    function migrate(address newFarmManager) external;

    function handleReceiveTokenToLP(address token,uint256 amount) external;
}

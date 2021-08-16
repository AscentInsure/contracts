// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interface/IFarmManager.sol";
import "./ShareWrapper.sol";

contract FarmBoardroom is ShareWrapper, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========== DATA STRUCTURES ========== */

    struct Boardseat {
        uint256 lastSnapshotIndex;
        uint256 rewardEarned;
    }

    struct BoardSnapshot {
        uint256 time;
        uint256 rewardReceived;
        uint256 rewardPerShare;
    }

    /* ========== STATE VARIABLES ========== */

    mapping(address => Boardseat) private directors;
    BoardSnapshot[] private boardHistory;
    uint256 stakedCount;
    IFarmManager public farmManager;
    IERC20 public ascentToken;
    address deployer;
    struct ReferrerStruct{
        address referrer;
        uint256 reward;
        uint256 invited;
    }

    mapping(address => ReferrerStruct) public referrerMap; // user => referrer

    /* ========== CONSTRUCTOR ========== */

    constructor(IERC20 _lp,IERC20 _ascentToken,IFarmManager _farmManager) {
        share = _lp;
        farmManager = _farmManager;
        ascentToken = _ascentToken;
        deployer = msg.sender;

        BoardSnapshot memory genesisSnapshot = BoardSnapshot({
        time : block.number,
        rewardReceived : 0,
        rewardPerShare : 0
        });
        boardHistory.push(genesisSnapshot);
    }

    /* ========== Modifiers =============== */
    modifier directorExists {
        require(
            balanceOf(msg.sender) > 0,
            'Boardroom: The director does not exist'
        );
        _;
    }

    modifier updateReward(address director) {
        if (director != address(0)) {
            Boardseat memory seat = directors[director];
            seat.rewardEarned = earned(director);
            seat.lastSnapshotIndex = latestSnapshotIndex();
            directors[director] = seat;
        }
        _;
    }

    /* ========== VIEW FUNCTIONS ========== */

    // =========== Snapshot getters

    function getStakedCount() public view returns (uint256){
        return stakedCount;
    }

    function latestSnapshotIndex() public view returns (uint256) {
        return boardHistory.length.sub(1);
    }

    function getLatestSnapshot() internal view returns (BoardSnapshot memory) {
        return boardHistory[latestSnapshotIndex()];
    }

    function getLastSnapshotIndexOf(address director)
    public
    view
    returns (uint256)
    {
        return directors[director].lastSnapshotIndex;
    }

    function getLastSnapshotOf(address director)
    internal
    view
    returns (BoardSnapshot memory)
    {
        return boardHistory[getLastSnapshotIndexOf(director)];
    }

    // =========== Director getters


    function rewardPerShare() public view returns (uint256) {
        return getLatestSnapshot().rewardPerShare;
    }

    function earned(address director) public view returns (uint256) {
        uint256 latestRPS = getLatestSnapshot().rewardPerShare;
        uint256 storedRPS = getLastSnapshotOf(director).rewardPerShare;

        return
        balanceOf(director).mul(latestRPS.sub(storedRPS)).div(1e18).add(
            directors[director].rewardEarned
        );
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount,address referrer)
    public
    nonReentrant
    updateReward(msg.sender)
    {
        if(referrer == address(0) || referrer == msg.sender){
            referrer = deployer;
        }

        if(referrerMap[msg.sender].referrer == address(0)){
            referrerMap[msg.sender].referrer = referrer;
        }

        ReferrerStruct storage referrerData = referrerMap[referrerMap[msg.sender].referrer];
        referrerData.invited = referrerData.invited.add(1);

        require(amount > 0, 'Boardroom: Cannot stake 0');
        super.stake(amount);
        stakedCount++;
        emit Staked(msg.sender, amount);
    }

    // only for emergency,it will destroy the reward
    function withdraw(uint256 amount)
    public
    override
    nonReentrant
    directorExists
    updateReward(msg.sender)
    {
        require(amount > 0, 'Boardroom: Cannot withdraw 0');
        directors[msg.sender].rewardEarned = 0;
        super.withdraw(amount);
        stakedCount--;
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        claimReward();
        withdraw(balanceOf(msg.sender));
    }

    function claimReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = directors[msg.sender].rewardEarned;
        if (reward > 0) {
            directors[msg.sender].rewardEarned = 0;
            ascentToken.safeTransfer(msg.sender, reward);

            uint256 directorShare = _balances[msg.sender];
            uint256 fee = directorShare.div(20); //5% fee
            uint256 toReferrer = fee.div(10);
            emit RewardPaid(msg.sender, reward);

            if(toReferrer > 0){
                //to referrer 10%
                share.safeTransfer(referrerMap[msg.sender].referrer, toReferrer);
//                IERC20(share).transfer(referrerMap[msg.sender].referrer, toReferrer);
                ReferrerStruct storage referrerData = referrerMap[referrerMap[msg.sender].referrer];
                referrerData.reward = referrerData.reward.add(toReferrer);
            }
            _totalSupply = _totalSupply.sub(fee);
            _balances[msg.sender] = directorShare.sub(fee);
            share.safeTransfer(address(farmManager), fee.sub(toReferrer));
            farmManager.handleReceiveTokenToLP(address(share),fee.sub(toReferrer));
        }
    }

    function allocateSeigniorage(uint256 amount)
    payable
    external
    nonReentrant
    onlyOwner
    {
        require(amount > 0, 'Boardroom: Cannot allocate 0');
        require(
            totalSupply() > 0,
            'Boardroom: Cannot allocate when totalSupply is 0'
        );

        // Create & add new snapshot
        uint256 prevRPS = getLatestSnapshot().rewardPerShare;
        uint256 nextRPS = prevRPS.add(amount.mul(1e18).div(totalSupply()));

        BoardSnapshot memory newSnapshot = BoardSnapshot({
        time : block.number,
        rewardReceived : amount,
        rewardPerShare : nextRPS
        });
        boardHistory.push(newSnapshot);

        emit RewardAdded(msg.sender, amount);
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(address indexed user, uint256 reward);
}

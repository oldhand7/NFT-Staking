// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

contract CCCT is ERC20Burnable, Ownable {

    using SafeMath for uint256;

    // uint256 public MAX_CCCTNFT_STAKED = 10;
    // uint256 public EMISSIONS_RATE = 11574070000000;
    // uint256 public CLAIM_END_TIME = 1641013200;
    
    uint256 public MAX_CCCTNFT_STAKED = 10;
    uint256 public EMISSIONS_RATE = 11574070000000;
    uint256 public CLAIM_END_TIME = 1641013200;

    address nullAddress = 0x0000000000000000000000000000000000000000;

    address public CCCTAddress;

    
    mapping(uint256 => uint256) internal tokenIdToTimeStaked;

    
    mapping(uint256 => address) internal tokenIdToStaker;


    mapping(address => uint256[]) internal stakerToTokenIds;

    constructor() ERC20("STEAK", "STK") {}

    function setCCCTAddress(address _CCCTAddress) public onlyOwner {
        CCCTAddress = _CCCTAddress;
        return;
    }

    function getTokensStaked(address staker) public view returns (uint256[] memory)
    {
        return stakerToTokenIds[staker];
    }

    function remove(address staker, uint256 index) internal {
        if (index >= stakerToTokenIds[staker].length) return;
        for (uint256 i = index; i < stakerToTokenIds[staker].length - 1; i++) {
            stakerToTokenIds[staker][i] = stakerToTokenIds[staker][i + 1];
        }
        stakerToTokenIds[staker].pop();
    }

    function removeTokenIdFromStaker(address staker, uint256 tokenId) internal {
        for (uint256 i = 0; i < stakerToTokenIds[staker].length; i++) {
            if (stakerToTokenIds[staker][i] == tokenId) {
                remove(staker, i);
            }
        }
    }

    function stakeByIds(uint256[] memory tokenIds) public {
        require( stakerToTokenIds[msg.sender].length + tokenIds.length <= MAX_CCCTNFT_STAKED,
            "Must have less than 11 ccct staked!");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require( IERC721(CCCTAddress).ownerOf(tokenIds[i]) == msg.sender && 
            tokenIdToStaker[tokenIds[i]] == nullAddress,"Token must be stakable by you!");
            IERC721(CCCTAddress).transferFrom( msg.sender,address(this),tokenIds[i]);
            stakerToTokenIds[msg.sender].push(tokenIds[i]);
            tokenIdToTimeStaked[tokenIds[i]] = block.timestamp;
            tokenIdToStaker[tokenIds[i]] = msg.sender;
        }
    }

    function unstakeAll() public onlyOwner {
        require( stakerToTokenIds[msg.sender].length > 0,"Must have at least one token staked!");
        uint256 totalRewards = 0;
        for (uint256 i = stakerToTokenIds[msg.sender].length; i > 0; i--) {
            uint256 tokenId = stakerToTokenIds[msg.sender][i - 1];
            IERC721(CCCTAddress).transferFrom(address(this),msg.sender,tokenId);
            totalRewards = totalRewards + ((block.timestamp - tokenIdToTimeStaked[tokenId]) * EMISSIONS_RATE);
            removeTokenIdFromStaker(msg.sender, tokenId);
            tokenIdToStaker[tokenId] = nullAddress;
        }

        _mint(msg.sender, totalRewards);
    }
    function unstakeByIds(uint256[] memory tokenIds) public onlyOwner {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenIdToStaker[tokenIds[i]] == msg.sender,"Message Sender was not original staker!");
            IERC721(CCCTAddress).transferFrom(address(this),msg.sender,tokenIds[i]);
            totalRewards = totalRewards + ((block.timestamp - tokenIdToTimeStaked[tokenIds[i]]) * EMISSIONS_RATE);
            removeTokenIdFromStaker(msg.sender, tokenIds[i]);
            tokenIdToStaker[tokenIds[i]] = nullAddress;
        }
        _mint(msg.sender, totalRewards);
    }

    function claimByTokenId(uint256 tokenId) public onlyOwner {
        require( tokenIdToStaker[tokenId] == msg.sender, "Token is not claimable by you!");
        require(block.timestamp < CLAIM_END_TIME, "Claim period is over!");
        _mint(msg.sender,((block.timestamp - tokenIdToTimeStaked[tokenId]) * EMISSIONS_RATE));
        tokenIdToTimeStaked[tokenId] = block.timestamp;
    }

    function claimAll() public  onlyOwner  {
        require(block.timestamp < CLAIM_END_TIME, "Claim period is over!");
        uint256[] memory tokenIds = stakerToTokenIds[msg.sender];
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenIdToStaker[tokenIds[i]] == msg.sender,"Token is not claimable by you!");
            totalRewards =totalRewards + ((block.timestamp - tokenIdToTimeStaked[tokenIds[i]]) * EMISSIONS_RATE);
            tokenIdToTimeStaked[tokenIds[i]] = block.timestamp;
        }
        _mint(msg.sender, totalRewards);
    }

    function getAllRewards(address staker) public view returns (uint256) {
        uint256[] memory tokenIds = stakerToTokenIds[staker];
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) { 
        totalRewards = totalRewards + ((block.timestamp - tokenIdToTimeStaked[tokenIds[i]]) * EMISSIONS_RATE);
        }
        return totalRewards;
    }

    function getRewardsByTokenId(uint256 tokenId) public view returns (uint256) {
        require( tokenIdToStaker[tokenId] != nullAddress, "Token is not staked!");
        uint256 secondsStaked = block.timestamp - tokenIdToTimeStaked[tokenId];
        return secondsStaked * EMISSIONS_RATE;
    }

    function getStaker(uint256 tokenId) public view returns (address) {
        return tokenIdToStaker[tokenId];
    }
}
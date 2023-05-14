// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ERC721Token.sol";
import "./ERC20Token.sol";

contract Marketplace {
    using SafeMath for uint256;

    address public owner;
    uint256 public feePercentage;

    ERC721Token public nft;
    ERC20Token public token;

    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public tokenIdCounter;

    event ListingCreated(uint256 tokenId, address seller, uint256 price);
    event ListingSold(uint256 tokenId, address buyer, uint256 price, address seller);

    constructor(address _nftAddress, address _tokenAddress) {
        owner = msg.sender;
        feePercentage = 1;

        nft = ERC721Token(_nftAddress);
        token = ERC20Token(_tokenAddress);
    }

    function createListing(uint256 _tokenId, uint256 _price) public {
        require(_price > 0, "Price must be greater than zero");

        // Transfer ownership of NFT to this contract
        nft.transferFrom(msg.sender, address(this), _tokenId);

        // Create new listing
        listings[tokenIdCounter] = Listing({
            tokenId: _tokenId,
            seller: msg.sender,
            price: _price
        });

        emit ListingCreated(_tokenId, msg.sender, _price);

        tokenIdCounter++;
    }

    function buyListing(uint256 _listingId) public {
        Listing storage listing = listings[_listingId];

        require(listing.price > 0, "Listing does not exist");
        require(nft.ownerOf(listing.tokenId) == address(this), "NFT is not owned by marketplace");
        require(token.balanceOf(msg.sender) >= listing.price, "Insufficient funds");

        uint256 fee = listing.price.mul(feePercentage).div(100);
        uint256 sellerAmount = listing.price.sub(fee);

        // Transfer ERC20 token to seller and marketplace fee to owner
        token.transferFrom(msg.sender, listing.seller, sellerAmount);
        token.transferFrom(msg.sender, owner, fee);

        // Transfer NFT to buyer
        nft.transferFrom(address(this),
            msg.sender, listing.seller, listing.tokenId);

    emit ListingSold(listing.tokenId, msg.sender, listing.price, listing.seller);

    // Remove listing
    delete listings[_listingId];
}

function setFeePercentage(uint256 _feePercentage) public {
    require(msg.sender == owner, "Only owner can set fee percentage");

    feePercentage = _feePercentage;
}

function withdrawFees() public {
    require(msg.sender == owner, "Only owner can withdraw fees");

    token.transfer(owner, token.balanceOf(address(this)));
}

function withdrawNFT(uint256 _tokenId) public {
    require(msg.sender == owner, "Only owner can withdraw NFT");

    nft.transfer(owner, _tokenId);
}

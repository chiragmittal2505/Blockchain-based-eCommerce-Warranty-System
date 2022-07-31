// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MNF is ERC721, ERC721Enumerable, ERC721URIStorage{
        using SafeMath for uint256;
        // uint public constant mintPrice = 0;
        function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
        {
            super._beforeTokenTransfer(from, to, tokenId);
        }
        function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
            super._burn(tokenId);
        }
        function tokenURI(uint256 tokenId)
            public
            view
            override(ERC721, ERC721URIStorage)
            returns (string memory)
        {
            return super.tokenURI(tokenId);
        }
        function supportsInterface(bytes4 interfaceId)
            public
            view
            override(ERC721, ERC721Enumerable)
            returns (bool)
        {
            return super.supportsInterface(interfaceId);
        }
        
        
        function stringToBytes32(string memory source) public pure returns (bytes32 result)
        {
            bytes memory tempEmptyStringTest = bytes(source);
            if (tempEmptyStringTest.length == 0) {
                return 0x0;
            }

            assembly {
                result := mload(add(source, 32))
            }
        }

        //Actual code starts from here
        uint256 TokenID;
        constructor() ERC721("MNFMinter", "MNFM") {
            // owner = payable(msg.sender);
            TokenID = 0;
        }
        //Making Timeline to track history of the product
        struct tracker{
            uint256 Time;
            address owner_add;
            string description;
        }
        //All the variables that we need
        struct Info{
            uint256 prices;
            address owners;
            uint256 warranty;
            string role;
            uint256 Expiry;
            uint256 RP;
            uint256 ExpiryRP;
            address Seller;
            uint256 cntTrns;
            tracker[] Timeline;
        }
        mapping(uint256 => Info) tokenInfo;
        mapping(uint256 => uint256) tokenStatus;  //whether the tokenID exists or not

        //Function to mint nft (Used by Manufacturer)
        function mint(string memory _uri,uint256 price) public payable {
            uint256 tokenID = TokenID;
            _safeMint(msg.sender, tokenID);
            _setTokenURI(tokenID, _uri);
            tokenInfo[tokenID].prices = price;
            tokenInfo[tokenID].warranty = 0;
            tokenInfo[tokenID].owners = msg.sender;
            tokenInfo[tokenID].role = "mnf";
            tokenInfo[tokenID].Timeline.push(tracker(block.timestamp,msg.sender,"Product is Manufactured."));
            tokenInfo[tokenID].cntTrns++;
            tokenStatus[tokenID] = 1;
            TokenID++;
        }
        //Owner of the NFT can change its price for further resale
        function changePrice(uint256 tokenID, uint256 price) public 
        {
            require(tokenStatus[tokenID]==1,"Given TokenId doesn't exists"); 
            require(msg.sender == tokenInfo[tokenID].owners, "you're not the owner");
            tokenInfo[tokenID].prices = price;
        }

        //After this threshold(transactions of NFT), NFT is not more valuable
        uint256 thresholdForBurn = 2;
        function setThresholdForBurn(uint256 val) public
        {
            // we will bound the functionality in front end. 
            thresholdForBurn = val;
        }

        function getThresholdForBurn() public view returns(uint256)
        {
            return thresholdForBurn;
        }

        //Function to transfer the NFT ownership according to constraints(or functionality that we need)
        function transfer_nft(address payable from, address to, uint256 tokenID, uint256 price) payable external
        {
            require(tokenStatus[tokenID]==1,"Given TokenId doesn't exists"); 
            require(msg.sender==from, "You don't have right to sell this");
            require(tokenInfo[tokenID].prices<=price,"Give amount greater than equal to desired amount");
            _transfer(from, to, tokenID);
            if (stringToBytes32(tokenInfo[tokenID].role) == "mnf") {
                tokenInfo[tokenID].role = "seller";
                tokenInfo[tokenID].Seller = to;
                tokenInfo[tokenID].Timeline.push(tracker(block.timestamp,to,"Product is sold to seller(FlipKart)."));
                tokenInfo[tokenID].Expiry = block.timestamp;
                tokenInfo[tokenID].RP = 7*(1 days); //ByDefault value of RP(in days)
                set_warranty(tokenID,0);
            }
            else if(stringToBytes32(tokenInfo[tokenID].role) == "seller") {
                tokenInfo[tokenID].role = "cstmr";
                tokenInfo[tokenID].Timeline.push(tracker(block.timestamp,to,"Product is sold to customer."));
                start_warrantyAndRP(tokenID);
            }
            else
            {
                tokenInfo[tokenID].Timeline.push(tracker(block.timestamp,to,"Product is resold to customer."));
                if(tokenInfo[tokenID].cntTrns>thresholdForBurn) DecayNFT(tokenID);
            }
            tokenInfo[tokenID].cntTrns++;
            tokenInfo[tokenID].owners = to;
        }
        //On decaying of NFT, all variables associated to it will also destroyed
        function DecayNFT(uint256 tokenID) public
        {
            _burn(tokenID);
            tokenStatus[tokenID] = 0;
            delete tokenInfo[tokenID];
        }
        function set_warranty(uint256 tokenID, uint256 Day) public
        {
            require(tokenStatus[tokenID]==1,"Given TokenId doesn't exists");
            require(msg.sender == tokenInfo[tokenID].owners, "you're not the owner");
            require(stringToBytes32(tokenInfo[tokenID].role) == "seller", "You are not authorised");
            tokenInfo[tokenID].warranty = Day;
        }
        function setRP(uint256 tokenID, uint256 Day) public
        {
            require(tokenStatus[tokenID]==1,"Given TokenId doesn't exists");
            require(msg.sender == tokenInfo[tokenID].owners, "you're not the owner");
            require(stringToBytes32(tokenInfo[tokenID].role) == "seller", "You are not authorised");
            tokenInfo[tokenID].RP = Day;
        }
        function start_warrantyAndRP(uint256 tokenID) public
        {
            uint256 Day = tokenInfo[tokenID].warranty;
            tokenInfo[tokenID].Expiry = block.timestamp + (Day * 1 seconds);
            tokenInfo[tokenID].ExpiryRP = block.timestamp + (tokenInfo[tokenID].RP * 1 seconds);
        }
        
        struct ReqForClaim{
            uint256 Time;
            address owner_add;
            uint256 tokenID;
            string Fault;
        }
        mapping(address => ReqForClaim[]) waitListForClaim;
        //Claim for warranty will be requested by customer within the warranty period
        function claimWarranty(uint256 tokenID, string memory fault) public
        {
            require(tokenStatus[tokenID]==1,"Given TokenId doesn't exists");
            require(block.timestamp <= tokenInfo[tokenID].Expiry, "Warranty is expired");
            require(msg.sender == tokenInfo[tokenID].owners, "You're not the owner");
            require(stringToBytes32(tokenInfo[tokenID].role)=="cstmr", "You don't have rights to claim");
            address to = tokenInfo[tokenID].Seller;
            tokenInfo[tokenID].Timeline.push(tracker(block.timestamp,to,"Claim Request sent to seller"));
            waitListForClaim[to].push(ReqForClaim(block.timestamp,msg.sender,tokenID,fault));
        }
        //Seller can either claim the product or reject the request
        function claimSuccess(uint256 tokenID) public
        {
            require(tokenInfo[tokenID].Seller==msg.sender, "You can't give its claim as you aren't the seller of this.");
            tokenInfo[tokenID].Timeline.push(tracker(block.timestamp,tokenInfo[tokenID].owners,"Claim successfully."));
        }
        function claimReject(uint256 tokenID) public
        {
            require(tokenInfo[tokenID].Seller==msg.sender, "You can't reject its claim as you aren't the seller of this.");
            tokenInfo[tokenID].Timeline.push(tracker(block.timestamp,tokenInfo[tokenID].owners,"Request for Claim Rejected"));
        }
        
        //On returing of product back to seller, its warranty and RP period would reset automatically
        function resetWarranty(uint256 tokenID, address to) public
        {
            _transfer(msg.sender, to,tokenID);
            tokenInfo[tokenID].owners = to;
            tokenInfo[tokenID].role = "seller";
            tokenInfo[tokenID].Expiry = block.timestamp;
        }
        //MApping that stores number of returns for every address(customer) in a given period of time frame
        mapping(address => uint256) numReturns;
        address[] fraudsReported;
        uint256 threshold = 50;
        function claimRP(uint256 tokenID) public
        {
            require(tokenStatus[tokenID]==1,"Given TokenId doesn't exists");
            require(msg.sender == tokenInfo[tokenID].owners, "you're not the owner");
            require(block.timestamp <= tokenInfo[tokenID].ExpiryRP, "Return Period is expired");
            require(stringToBytes32(tokenInfo[tokenID].role)=="cstmr", "You are not authorised");
            address to = tokenInfo[tokenID].Seller;

            numReturns[msg.sender]+=1;
            if(numReturns[msg.sender]==threshold) fraudsReported.push(msg.sender);

            tokenInfo[tokenID].Timeline.push(tracker(block.timestamp,to,"Product is returned back to seller."));
            tokenInfo[tokenID].cntTrns++;
            resetWarranty(tokenID, to);
        }

        function resetFraud() public //bounded to use by Flipkart only in frontend
        {
            //In this , we need to reset numReturns.
        }
        function setThreshold(uint256 val) public //bounded to use by Flipkart only in frontend
        {
            threshold = val;
        }
        function getHistory(uint256 tokenID) public view returns(tracker[] memory)
        {
            require(tokenStatus[tokenID]==1,"Given TokenId doesn't exists"); 
            return (tokenInfo[tokenID].Timeline);
        }
        function getFrauds() public view returns(address[] memory )
        {
            return fraudsReported;
        }
        function getrole(uint256 tokenId) public view returns(string memory)
        {
            require(tokenStatus[tokenId]==1,"Given TokenId doesn't exists"); 
            return tokenInfo[tokenId].role;
        }
        function getPrice(uint256 tokenID) public view returns(uint256)
        {
            require(tokenStatus[tokenID]==1,"Given TokenId doesn't exists"); 
            return tokenInfo[tokenID].prices;
        }

        //FlipKart can setOrChange offers in exchange of metaCoins(Coins earned via metaverse e-commerce platform)
        mapping(string => string) offers;  //{couponCode-> What if offer?}
        function setOrChangeOffer(string memory couponCode, string memory desc) public
        {
            //Should be bounded to used by seller only in frontend
            offers[couponCode] = desc;
        }
        function removeOffer(string memory couponCode) public
        {
            //Should be bounded to used by seller only in frontend
            delete offers[couponCode];
        }
    }
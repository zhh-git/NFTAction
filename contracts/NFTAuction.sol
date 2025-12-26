// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {console} from "hardhat/console.sol";

/**
 * @title NFT拍卖合约
 * @author
 * @notice
 */
contract NFTAuction is
    IERC721Receiver,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    //拍卖结构体
    struct Auction {
        address saller; //卖家
        uint256 startTime; //开始时间
        uint256 duration; // 拍卖时长（单位秒）
        bool ended; //是否结束
        uint256 startPrice; //起拍价格
        address highestBidder; // 最高出价者
        uint256 highestBid; //最高出价
        address nftContract; //拍卖的NFT合约
        uint256 tokenId; //拍卖的tokenId
        address payToken; //参与竞价的资产类型（0x00表示eth，其他的表示ERC20）
        uint256 auctionId; //拍卖id
    }


    // 拍卖创建事件
    event AuctionCreated(
        address indexed seller,
        uint256 indexed auctionId,
        address indexed nftContract,
        uint256 duration,
        uint256 startTime,
        uint256 startPrice,
        uint256 tokenId
    );
    // 拍卖竞价事件
    event AuctionBided(
        address indexed highestBidder,
        uint256 indexed auctionId,
        address indexed nftContract,
        uint256 tokenId,
        uint256 highestBid
    );
    // 拍卖结束事件
    event AuctionEnded(
        address indexed highestBidder,
        uint256 indexed auctionId,
        address indexed nftContract,
        uint256 tokenId,
        uint256 highestBid
    );

    mapping(uint256 => Auction) private auctions; //拍卖id对应拍卖的信息

    address public platformFeeRecipient; // 平台手续费接收地址
    uint256 public platformFeePercentage; // 平台手续费比例（万分之为单位，100 = 1%）
    uint256 private nextAuctionId;
    address public admin; //管理员地址

        /**
     * eth(address(0)) => 0x694AA1769357215DE4FAC081bf1f309aDC325306 ETH/USD
     * usdc => 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E USDC/USD
     * 初始化默认添加以上两个币对，管理员可以添加更多映射
     */
    mapping(address => AggregatorV3Interface) private priceFeeds; // 价格预言机，统一为【代币/USD】的喂价

    //逻辑合约初始化
    function initialize(address platformFeeRecipient_, uint256 platformFeePercentage_) public initializer{
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        admin = msg.sender; //部署合约账户
        // 初始化添加Sepolia测试网的 ETH/USD 和 USDC/USD 价格预言机
        setPriceFeeds();
        platformFeeRecipient = platformFeeRecipient_;
        platformFeePercentage = platformFeePercentage_;   
    }

    function createAuction(
        uint256 duration_,
        uint256 startPrice_,
        address nftcontract_,
        uint256 tokenId_,
        address payToken_
    ) external {
        //拍卖有效期在 1到10分钟之内
        require(
            duration_ >= 60 * 1 && duration_ <= 60 * 10,
            "ActionTime need in 1 - 10 min"
        );
        require(startPrice_ > 0, "startPrice need > 0");
        require(nftcontract_ != address(0), "nftcontract don't 0x00");
        require(tokenId_ > 0, "token id need > 0");

        //必须判断tokenId是属于当前卖家的
        IERC721 nft = IERC721(nftcontract_);
        require(nft.ownerOf(tokenId_) == msg.sender, "seller not be NFT owner");

        // 如果是ERC20代币，需要交易拍卖是否支持此代币
        if (payToken_ != address(0)) {
            AggregatorV3Interface feed = priceFeeds[payToken_];
            // 校验拍卖合约是否此支持_payToken代币来进行拍卖，可由管理员添加映射
            require(address(feed) != address(0), "payToken not support");
        }

        uint256 auctionId = nextAuctionId;
        auctions[auctionId] = Auction({
            saller: msg.sender,
            startTime: block.timestamp, //开始时间 区块时间戳
            duration: duration_, // 拍卖时长（单位秒）
            ended: false, //是否结束
            startPrice: startPrice_, //起拍价格
            highestBidder: address(0), // 最高出价者
            highestBid: 0, //最高出价
            nftContract: nftcontract_, //拍卖的NFT合约
            tokenId: tokenId_, //拍卖的tokenId
            payToken: payToken_, //参与竞价的资产类型（0x00表示eth，其他的表示ERC20）
            auctionId: auctionId
        });

        //将对应的token转给拍卖合约，这样拍卖合约才能拍卖
        nft.transferFrom(msg.sender, address(this), tokenId_);

        emit AuctionCreated(msg.sender, auctionId, nftcontract_, duration_, block.timestamp, startPrice_, tokenId_);
        nextAuctionId++;
    }

    //参加拍卖
    function placeBid(
        uint256 price,
        uint256 auctionId,
        address payToken
    ) public payable {
        require(price > 0, "price need > 0");
        Auction storage _auction = auctions[auctionId];
        uint256 _highestBid = _auction.highestBid;
        address _saller = _auction.saller;

        // 如果有人出价出价需要高于当前最高价 否则 大于开始价格
        if(_auction.highestBidder != address(0)) {
            require(price > _highestBid, "current price need > highestBid");
        } else {
            require(price > _auction.startPrice, "current price need > startPrice");
        }
        
        require(_saller != msg.sender, "Seller cannot bid"); //禁止卖家自己参与拍卖
        require(
            !_auction.ended &&
                block.timestamp < _auction.startTime + _auction.duration,
            "auction ended"
        );

        if (payToken == address(0)) {
            //ETH 出价，当此函数成功执行后，msg.value对应的ETH会自动存入本合约余额中
            require(msg.value == price, "ETH bid need Value equal price");
        } else {
            require(msg.value == 0, "ERC20 bid not send ETH");
            // 查询用户是否授权拍卖合约可以操作该ERC20代币金额大于等于此次支付金额
            require(
                IERC20(payToken).allowance(msg.sender, address(this)) >= price,
                "ERC20 allowance not enough"
            );
        }

        //出价的价格对应的美元
        uint256 priceUSD = _calculateBidUSDValue(payToken, price);
        console.log("priceUSD", priceUSD);
        //最高价的对应的美元价格
        uint256 highestUSD = _getHighestUSDValue(_auction);
        console.log("highestUSD", highestUSD);

        require(priceUSD > highestUSD, "bid ammount need > highestUSD");

        if (payToken != address(0)) {
            //ERC20代币交易
            bool success = IERC20(payToken).transferFrom(
                msg.sender,
                address(this),
                price
            );
            require(success, "ERC20 transfer Fail");
        }

        if (_auction.highestBidder != address(0) && _auction.highestBid > 0) {
            // 存在上一个出价者，退还上一个出价者的付款
            _payMoney(_auction.highestBidder, _auction.highestBid, payToken);
        }

        _auction.highestBidder = msg.sender;
        _auction.highestBid = price;
        _auction.payToken = payToken;

        emit AuctionBided(msg.sender, auctionId, _auction.nftContract, _auction.tokenId, _auction.highestBid);

    }

    //结束拍卖
    function endBid(uint256 auctionId, address nftContract) public {
        Auction storage auctionInfo = auctions[auctionId];
        require(!auctionInfo.ended, "auction had ended"); // 只允许调用一次
        require(
            block.timestamp >= auctionInfo.startTime + auctionInfo.duration,
            "auction not ended"
        );

        //结束拍卖
        auctionInfo.ended = true;

        IERC721 nft = IERC721(nftContract);

        //最高出价者不是0
        if (auctionInfo.highestBidder != address(0)) {
            //将NFT tokenId 转给最高出价者
            nft.safeTransferFrom(
                address(this),
                auctionInfo.highestBidder,
                auctionInfo.tokenId
            );

            //计算手续费
            uint256 fee = calculateFee(auctionInfo.highestBid);
            console.log("fee", fee);
            //获取实际转给卖家的钱
            uint256 sellerAmount = auctionInfo.highestBid - fee;
            console.log("sellerAmount", sellerAmount);

            //手续费转给平台
            _payMoney(platformFeeRecipient, fee, auctionInfo.payToken);

            //把实际获得的钱转给卖家
            _payMoney(auctionInfo.saller, sellerAmount, auctionInfo.payToken);
        } else {
            //无人出价 还给卖家
            nft.safeTransferFrom(
                address(this),
                auctionInfo.saller,
                auctionInfo.tokenId
            );
        }

        emit AuctionEnded(auctionInfo.highestBidder, auctionId, nftContract, auctionInfo.tokenId, auctionInfo.highestBid);
    }

    //支付函数  支持退款
    function _payMoney(address to, uint256 amount, address payToken) internal {
        require(to != address(0), "receive account need > 0");
        require(amount > 0, "amount need > 0");
        if (payToken != address(0)) {
            //ERC20代币, 将ERC20 代币退还给ERC20
            bool success = IERC20(payToken).transfer(to, amount);
            require(success, "ERC20 transfer Fail");
        } else {
            //ETH 支付 退回给卖家
            payable(to).transfer(amount);
            console.log("transfer eth to bidder:", to);
        }
    }

    /**
     * 计算平台手续费
     */
    function calculateFee(uint256 amount) public view returns (uint256 fee) {
        return (platformFeePercentage * amount) / 10000;
    }

    //初始化价格预言机
    function setPriceFeeds() internal {
        priceFeeds[address(0)] = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        ); // ETH/USD
        priceFeeds[
            0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
        ] = AggregatorV3Interface(0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E); // USDC/USD
    }

    function _calculateBidUSDValue(
        address _payToken,
        uint256 _amount
    ) internal view virtual returns (uint256) {
        AggregatorV3Interface feed = priceFeeds[_payToken];
        require(address(feed) != address(0), "Price feed not set for payToken");
        console.log("address(feed): ", address(feed));
        (, int256 priceRaw, , , ) = feed.latestRoundData();
        require(priceRaw > 0, "Invalid price from feed");
        uint256 price = uint256(priceRaw);
        uint256 feedDecimal = feed.decimals();
        console.log("price: ", price);
        console.log("feedDecimal: ",feedDecimal);
        console.log("_amount: ", _amount);
        if (address(0) == _payToken) {
            return (price * _amount) / (10 ** (12 + feedDecimal)); // ETH 10**(18 + feedDecimal - 6) = 10**(12 + feedDecimal)
        } else {
            return (price * _amount) / (10 ** (feedDecimal)); // USDC 10**(6 + feedDecimal - 6) = 10**feedDecimal
        }
    }

    // 计算当前拍卖最高出价的 USD 价值
    function _getHighestUSDValue(
        Auction memory auctionInfo
    ) internal view virtual returns (uint256) {
        AggregatorV3Interface feed = priceFeeds[auctionInfo.payToken];
        require(address(feed) != address(0), "Price feed not set for payToken");
        (, int256 priceRaw, , , ) = feed.latestRoundData();
        require(priceRaw > 0, "Invalid price from feed");
        uint256 price = uint256(priceRaw); // 获取价格预言机喂价
        uint256 feedDecimal = feed.decimals(); // 获取价格预言机小数位数

        // 获取当前最高出价，默认为起拍价格，如果有人出价，则最高出价为最高出价
        uint256 hightestAmount = auctionInfo.startPrice;
        if (auctionInfo.highestBidder != address(0)) {
            hightestAmount = auctionInfo.highestBid;
        }
        if (address(0) == auctionInfo.payToken) {
            return (price * hightestAmount) / (10 ** (12 + feedDecimal)); // ETH 10**(18 + feedDecimal - 6) = 10**(12 + feedDecimal)
        } else {
            return (price * hightestAmount) / (10 ** (feedDecimal)); // USDC 10**(6 + feedDecimal - 6) = 10**feedDecimal
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override onlyOwner{
    }
}

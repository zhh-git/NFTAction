// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFTContract is ERC721, Ownable {
    
    uint256 private MAX_APES = 10000; // 总量

    uint256 private _tokenIdCounter;

    string private _name;

    string private _symbol;

    string private baseURI;

    constructor(string memory name_, string memory symbol_, string memory baseURI_) ERC721(name_, symbol_) Ownable(msg.sender){
        _tokenIdCounter = 1;
        baseURI = baseURI_;
    }

    //铸造NFT
    function mintNFT(address to) external {
        require(_tokenIdCounter < MAX_APES, "token out of range");
        uint256 tokenId = _tokenIdCounter;
        _safeMint(to, tokenId);
        _tokenIdCounter++;
    }

    /**
     * @dev 合约拥有者批量铸造 NFT（仅拥有者可调用）
     * @param to 接收 NFT 的地址
     * @param amount 铸造数量
     */
    function batchMintNFT(address to, uint256 amount) public onlyOwner {
        require(amount > 0 && amount <= 100, "Amount must be 1-100"); // 限制批量铸造数量
        
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter;
            _tokenIdCounter++;
            _safeMint(to, tokenId);
        }
    }


     // 查询下一个待铸造的NFT ID
    function getNextTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

   /**
     * @dev 重写 ERC721 的元数据 URI 方法（拼接 baseURI + tokenId）
     * @param tokenId NFT ID
     * @return 完整的元数据 URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(exists(tokenId), "NFT does not exist"); // 检查 NFT 是否存在
        
        string memory base = baseURI;
        // 拼接 URI：baseURI/tokenId.json（符合 NFT 元数据标准）
        return bytes(base).length > 0 ? string(abi.encodePacked(base, Strings.toString(tokenId), ".json")) : "";
    }

    /**
     * @dev 更新元数据基础 URI（仅拥有者可调用）
     * @param _newBaseURI 新的基础 URI
     */
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    // 可选：如需手动校验 NFT 是否存在，可封装一个公开方法
    function exists(uint256 tokenId) public view returns (bool) {
        try this.ownerOf(tokenId) {
            return true;
        } catch {
            return false;
        }
    }
}
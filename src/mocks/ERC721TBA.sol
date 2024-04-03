pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721TBA is ERC721 {
    uint256 public counter;
    constructor() ERC721("SAFE-TBA", "STBA") {

    }

    function mint() external {
        counter++;
        _mint(msg.sender, counter);
    }
}
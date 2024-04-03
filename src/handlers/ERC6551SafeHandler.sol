pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {Safe} from "@safe/smart-account/contracts/Safe.sol";
interface IERC6551Account {
    receive() external payable;

    function token()
        external
        view
        returns (uint256 chainId, address tokenContract, uint256 tokenId);

    function state() external view returns (uint256);

    function isValidSigner(
        address signer,
        bytes calldata context
    ) external view returns (bytes4 magicValue);
}

interface IERC6551Executable {
    function execute(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external payable returns (bytes memory);
}

contract ERC6551SafeHandler is
    IERC165,
    IERC1271,
    IERC6551Account,
    IERC6551Executable
{
    address public immutable MY_ADDRESS;
    uint256 public chainId;
    address public tokenContract;
    uint256 public tokenId;

    uint256 public state;

    receive() external payable {}

    bytes32 private constant SAFE_MSG_TYPEHASH =
        0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;
    bytes4 internal constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

    constructor(address _tokenContract, uint256 _tokenId) {
        MY_ADDRESS = address(this);
        chainId = block.chainid;
        tokenContract = _tokenContract;
        tokenId = _tokenId;
    }

    function execute(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external payable virtual returns (bytes memory result) {
        // no need to check it right now, as focus is on verifing signature
        // require(_isValidSigner(msg.sender), "Invalid signer");
        // require(operation == 0, "Only call operations are supported");

        ++state;

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function isValidSigner(
        address signer,
        bytes calldata
    ) external view virtual returns (bytes4) {
        if (_isValidSigner(signer)) {
            return IERC6551Account.isValidSigner.selector;
        }

        return bytes4(0);
    }

    function encodeMessageDataForSafe(
        Safe safe,
        bytes memory message
    ) public view returns (bytes memory) {
        bytes32 safeMessageHash = keccak256(
            abi.encode(SAFE_MSG_TYPEHASH, keccak256(message))
        );
        return
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                safe.domainSeparator(),
                safeMessageHash
            );
    }

    function isValidSignature(
        bytes32 _dataHash,
        bytes calldata _signature
    ) public view override returns (bytes4) {
        // Caller should be a Safe
        Safe safe = Safe(payable(msg.sender));
        bytes memory messageData = encodeMessageDataForSafe(
            safe,
            abi.encode(_dataHash)
        );
        bytes32 messageHash = keccak256(messageData);
        if (_signature.length == 0) {
            require(safe.signedMessages(messageHash) != 0, "Hash not approved");
        } else {
            bool isValid = SignatureChecker.isValidSignatureNow(
                owner(),
                messageHash,
                _signature
            );

            if (!isValid) {
                return bytes4(0);
            }
        }
        return EIP1271_MAGIC_VALUE;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure virtual returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId ||
            interfaceId == type(IERC6551Executable).interfaceId;
    }

    function token() public view virtual returns (uint256, address, uint256) {
        return (chainId, tokenContract, tokenId);
    }

    function owner() public view virtual returns (address) {
        (uint256 _chainId, address _tokenContract, uint256 _tokenId) = token();
        if (_chainId != block.chainid) return address(0);

        return IERC721(_tokenContract).ownerOf(_tokenId);
    }

    function _isValidSigner(
        address signer
    ) internal view virtual returns (bool) {
        return signer == owner();
    }

    function enableMyself() public {
        Safe(payable(address(this))).enableModule(MY_ADDRESS);
    }
}

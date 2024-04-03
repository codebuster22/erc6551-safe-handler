pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ERC721TBA} from "../src/mocks/ERC721TBA.sol";
import {ERC6551Registry} from "erc6551/src/ERC6551Registry.sol";
import {Safe} from "@safe/smart-account/contracts/Safe.sol";
import {ERC6551SafeHandler} from "../src/handlers/ERC6551SafeHandler.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

contract IntegrationTest is Test {
    ERC721TBA public mock;
    ERC6551Registry public registry;
    Safe public safeImplementation;

    uint256 alicePrivateKey = 1234567890;
    address alice = vm.addr(alicePrivateKey);
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address denis = makeAddr("denis");

    function setUp() public {
        // deploy mock token contract
        mock = new ERC721TBA();
        // deploy mock ERC6551 registry
        registry = new ERC6551Registry();
        // deploy Safe implementation
        safeImplementation = new Safe();
    }

    function test_NFTInitialization() public {
        assertEq(mock.name(), "SAFE-TBA");
        assertEq(mock.symbol(), "STBA");
    }

    function test_mintNewNFT() public {
        vm.prank(alice);
        mock.mint();
        assertEq(mock.ownerOf(1), alice);
        assertEq(mock.counter(), 1);
    }

    // note: fails as need to implement type data signing
    function test_deployNewSafeUsing6551Registry() public {
        address[] memory _owners = new address[](1);
        _owners[0] = alice;
        vm.prank(alice);
        mock.mint();

        // deploy 6551
        // demo salt
        bytes32 demoSalt = keccak256("Demo Salt");
        address safeInstance = registry.createAccount(
            address(safeImplementation),
            demoSalt,
            1,
            address(mock),
            1
        );
        uint256 _threshold = 1;
        address fallbackHandler = address(
            new ERC6551SafeHandler(address(mock), 1)
        );
        address to = fallbackHandler;
        bytes memory data = abi.encodeWithSelector(
            ERC6551SafeHandler.enableMyself.selector
        );
        address paymentToken;
        uint256 payment = 0;
        address payable paymentReceiver;
        Safe instance = Safe(payable(safeInstance));
        instance.setup(
            _owners,
            _threshold,
            to,
            data,
            fallbackHandler,
            paymentToken,
            payment,
            paymentReceiver
        );
        assertEq(instance.isOwner(alice), true);
        assertEq(instance.getThreshold(), 1);
        assertEq(instance.isModuleEnabled(fallbackHandler), true);

        // generate signature using owner address
        bytes memory functionCall = abi.encodeWithSelector(
            ERC6551SafeHandler.enableMyself.selector
        );
        bytes32 messageHash = keccak256(functionCall);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(
            ERC6551SafeHandler(payable(address(instance))).isValidSignature(
                messageHash,
                signature
            ),
            IERC1271.isValidSignature.selector
        );
    }
}

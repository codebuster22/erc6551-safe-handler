pragma solidity 0.8.24;

import {SafeProxyFactory} from "@safe/smart-account/contracts/proxies/SafeProxyFactory.sol";
import {Safe} from "@safe/smart-account/contracts/Safe.sol";
import {Script, console} from "forge-std/Script.sol";
import {ERC6551SafeHandler} from "../src/handlers/ERC6551SafeHandler.sol";
import {ERC721TBA} from "../src/mocks/ERC721TBA.sol";

contract Create6551WithSafe is Script {
    function run() public {
        SafeProxyFactory factory = SafeProxyFactory(
            0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67
        );
        address singleton = 0x41675C099F32341bf84BFc5382aF534df5C7461a;

        address[] memory _owners = new address[](1);
        _owners[0] = 0x9cA70B93CaE5576645F5F069524A9B9c3aef5006;
        uint256 demoSalt = 1;
        uint256 _threshold = 1;
        address paymentToken;
        uint256 payment = 0;
        address payable paymentReceiver;
        vm.startBroadcast();
        // deploy mock token contract
        ERC721TBA mock = new ERC721TBA();
        // mint an NFT
        mock.mint();
        // deploy the module/fallback handler
        address fallbackHandler = address(
            new ERC6551SafeHandler(address(mock), 1)
        );
        address to = fallbackHandler;
        bytes memory data = abi.encodeWithSelector(
            ERC6551SafeHandler.enableMyself.selector
        );
        bytes memory safeData = abi.encodeWithSelector(
            Safe.setup.selector,
            _owners,
            _threshold,
            to,
            data,
            fallbackHandler,
            paymentToken,
            payment,
            paymentReceiver
        );
        factory.createProxyWithNonce(singleton, safeData, demoSalt);
        vm.stopBroadcast();
    }
}

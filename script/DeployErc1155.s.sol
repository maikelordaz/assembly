// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";

contract DeployErc1155 is Script {
    error DeployErc1155__DeployFailed();

    function run() external {
        _deployErc1155("Erc1155");
    }

    function _deployErc1155(
        string memory _fileName
    ) internal returns (address) {
        string memory bash = string.concat(
            'cast abi-encode "f(bytes)" $(solc --strict-assembly yul/',
            string.concat(_fileName, ".yul --bin | tail -1)")
        );

        string[] memory commands = new string[](3);
        commands[0] = "bash";
        commands[1] = "-c";
        commands[2] = bash;

        bytes memory bytecode = abi.decode(vm.ffi(commands), (bytes));

        address addr;

        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        require(addr != address(0), DeployErc1155__DeployFailed());

        return addr;
    }
}

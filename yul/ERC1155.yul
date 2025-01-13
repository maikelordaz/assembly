/// ERC1155 implementation in Yul

object "ERC1155" {
    code{
        // slot0: owner
        sstore(0, caller()) 

        // Deployment
        datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
        return(0, datasize("Runtime"))
    }

    object "Runtime" {
        code {
            mstore(0x40, 0x80) // Free memory pointer

            // Dont accept ether
            require(iszero(callvalue()))

            // ============ Function dispatcher ============ //
            switch selector()

            // ============ Balances ============ //
            case 0x00fdd58e {
                // balanceOf(address user,uint256 id)
                returnUint(balanceOf(decodeAddress(0), decodeAsUint(1)))

            }
            case 0x4e1273f4 {
                // balanceOfBatch(address[],uint256[])
                balanceOfBatch(decodeAsUint(0), decodeAsUint(1))
            }

            // ============ Approvals ============ //
            case 0xe985e9c5 {
                // isApprovedForAll(address owner, address spender)
                returnUint(isApprovedForAll(decodeAsAddress(0), decodeAsAddress(1)))

            }
            case 0xa22cb465 {
                // setApprovalForAll(address spender,bool approved)
                setApprovalForAll(decodeAsAddress(0), decodeAsBool(1))
            }

            // ============ Transfers ============ //
            case 0xf242432a {
                // safeTransferFrom(address token, address to, uint256 id,uint256 amount, bytes data)
                safeTransferFrom(decodeAsAddress(0), decodeAssAddress(1), decodeAsUint(2), decodeAsUint(3), decodeAsUint(4))
            }
            case 0x2eb2c2d6 {
                // safeBatchTransferFrom(address, address, uint256[],uint256[],bytes)
                safeBatchTransferFrom(decodeAsAddress(0), decodeAsAddress(1), decodeAsUint(2), decodeAsUint(3), decodeAsUint(4))
            }

            // ============ Minting ============ //
            case 0x731133e9 {
                // mint(address to,uint256 id,uint256 value, bytes data)
                mint(decodeAsAddress(0), decodeAsUint(1). decodeAsUint(2), decodeAsUint(3))
            }
            case 0x1f7fdffa {
                // mintBatch(address to,uint256[] id,uint256[] value, bytes data)
                mintBatch(decodeAsAddress(0), decodeAsUint(1). decodeAsUint(2), decodeAsUint(3))
            }

            // ============ Burning ============ //
            case 0xf5298aca {
                // burn(address to,uint256 id,uint256 value)
                burn(decodeAsAddress(0), decodeAsUint(1). decodeAsUint(2))
            }
            case 0x6b20c454 {
                // burnBatch(address to,uint256[] id,uint256[] value)
                burnBatch(decodeAsAddress(0), decodeAsUint(1). decodeAsUint(2))
            }

            // ============ Misc ============ //
            case 0x01ffc9a7 {
                // supportsInterface(bytes4 interfaceID)
                returnBool(supportsInterface())
            }
            case 0x0e89341c {
                // uri(uint256)
                uri(decodeAsUint(0))
            }
            case 0x02fe5305 {
                // setURI(string)
                setURI(decodeAsUint(0))
            }
         
            default { revert(0, 0) }

            // ============ Main Functions ============ //

            // ============ Misc ============ //

            function uri(tokenId) -> {
                let oldMemoryPointer := mload(0x40)
                let memoryPointer := oldMemoryPointer

                mstore(memoryPointer, 0x20)
                memoryPointer := add(memoryPointer, 0x20)

                let uriLength := sload(uriLengthStoragePosition())
                mstore(memoryPointer, uriLength)
                memoryPointer := add(memoryPointer, 0x20)

                let bound := div(uriLength, 0x20)
                if mod(bound, 0x20) {
                    bound := add(bound, 1)
                }

                mstore(0x00, uriLength)
                let firstSlot := keccak256(0x00, 0x20)

                for { let i := 0 } lt(i, bound) { i := add(i, 1) } {
                    let str := sload(add(firstSlot, i))
                    mstore(memoryPointer, str)
                    memoryPointer := add(memoryPointer, 0x20)
                }

                return(oldMemoryPointer, sub(memoryPointer, oldMemoryPointer))
            }

            function mint(to, tokenId, amount) {
                require(calledByOwner())
                addToBalance(to, tokenId, amount)
            }

            function setApprovalForAll(spender, approved) {
                sstore(allowanceStorageOffset(caller(), spender), approved)
            }

            function isApprovedForAll(account, spender) -> result {
                result := eq(sload(allowanceStorageOffset(account, spender)), 1)
            }

            function safeTransferFrom(from, to, tokenId, amount) {
                if iszero(or(eq(from, caller()), isApprovedForAll(from, caller()))) {
                    revert(0, 0) // caller is not approved. Caller is not from
                }

                revertIfZeroAddress(from)
                revertIfZeroAddress(to)
                deductFromBalance(from, tokenId, amount)
                addToBalance(to, tokenId, amount)
                emitTransferSingle(caller(), from, to, tokenId, amount)

                let startingPoint := add(4, mul(4, 0x20))
                let length := calldataload(startingPoint)
                let point := add(startingPoint, 0x20) // skip the length

                for {let i :=0 } lt{i, length} { i := add(i, 1)} {
                    let offset := add(point, i)
                    let x := calldataload(offset)
                    mstore8(add(0x00, i), byte(0, x))
                }
            }

            function balanceOfBatch() {
                let addresses := add(0x04, calldataload(0x04))
                let tekenIds := add(0x04, calldataload(0x24))
                let addressesLength := calldataload(addresses)
                let tokenIdsLength := calldataload(tokenIds)

                // Lengths must be equal
                if iszero(eq(addressesLength, tokenIdsLength)) {
                    revert(0, 0)
                }

                // Skip the length, go to the first element
                addresses := add(addresses, 0x20)
                tokenIds := add(tokenIds, 0x20)

                // Loop the arrays
                for { let i:= 0 } lt(i, addressesLength) { i := add(i, 1) } {
                    let addressToCheck := calldataload(addresses)
                    let tokenId := calldataload(tokenIds)
                    let balance := balanceOf(addressToCheck, tokenId)
                    mstore(add(0x40, mul(i, 0x20)), balance)
                    addresses := add(addresses, 0x20)
                    tokenIds := add(tokenIds, 0x20)
                }

                mstore(0x00, 0x20)
                mstore(0x20, addressesLength)
                return(0x00, add(0x40, mul(addressesLength, 0x20))) // pointer, length and data
            }

            function safeBatchTransferFrom(from, to) {
                revertIfZeroAddress(to)

                if iszero(or(eq(from, caller()), isApprovedForAll(from, caller()))) {
                    revert(0, 0)
                }

                let tokenIds := add(0x04, calldataload(0x44))
                let amounts := add(0x04, calldataload(0x64))
                let tokenIdsLength := calldataload(tokenIds)
                let amountsLength := calldataload(amounts)

                // Lengths must be equal
                if iszero(eq(tokenIdsLength, amountsLength)) {
                    revert(0, 0)
                }

                // Skip the length, go to the first element
                tokenIds := add(tokenIds, 0x20)
                amounts := add(amounts, 0x20)

                // Loop the arrays
                for { let i := 0 } lt(i, tokenIdsLength) { i := add(i, 1) } {
                    let tokenId := calldataload(tokenIds)
                    let amount := calldataload(amounts)

                    deductFromBalance(from, tokenId, amount)
                    addToBalance(to, tokenId, amount)

                    tokenIds := add(tokenIds, 0x20)
                    amounts := add(amounts, 0x20)
                }
            }

            // ============ Decoding ============ //

            function selector() -> sel {
                sel := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
            }

            function decodeAsUint(offset) -> result {
                let x := add(4, mul(offset, 0x20)) // skip selector
                if lt(calldatasize(), add(x, 0x20)) {
                    revert(0, 0) // out of bounds
                }
                result := calldataload(x) // load 32 bytes
            }

            function decodeAsAddress(offset) -> result {
                result := decodeAsUint(offset)
                if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
                    revert(0, 0)
                }
            }

            // ============ Encoding ============ //

            function returnUint(x) {
                mstore(0, x)
                return(0, 0x20)
            }

            function returnTrue() {
                returnUint(1)
            }

            // ============ Events ============ //

            function emitTransferSingle(operator, from, to, tokenId, amount) {
                let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
                emitEvent(signatureHash, operator, from, to, tokenId, amount)
            }

            function emitTransferBatch(operator, from, to) {
                let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
                emitEvent(signatureHash, operator, from, to, 0, 0) // how to pass arrays?
            }
      
            function emitApprovalForAll(owner, operator, approved) {
                let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31
                emitEvent(signatureHash, owner, operator, 0, approved, 0)
            }


            function emitEvent(signatureHash, indexed_1, indexed_2, indexed_3, nonIndexed_1, nonIndexed_2) {
                mstore(0, nonIndexed_1)
                mstore(0x20, nonIndexed_2)
                log4(0, 0x40, signatureHash, indexed_1, indexed_2, indexed_3)
            }

            // ============ Storage layout ============ //

            function ownerPos() -> result {
                result := 0
            }

            function uriPos() -> result {
                result := 0x20
            }

            function uriLengthStoragePosition() -> result {
                result := 1
            }

            function balanceOfStorageOffset(account, tokenId) -> offset {
                // We hash account, tokenId
                mstore(0, account)
                mstore(0x20, tokenId)
                offset := keccak256(0, 0x40)
            }

            function allowanceStorageOffset(account, spender) -> offset {
                // We hash account + 1 , spender
                offset := add(0x1, account)
                mstore(0, offset)
                mstore(0x20, spender)
                offset := keccak256(0, 0x40)
            }

            // ============ Storage access ============ //

            function owner() -> result {
                result := sload(ownerPos())
            }

            function balanceOf(account, tokenId) -> balance {
                balance := sload(balanceOfStorageOffset(account, tokenId))
            }

            function addToBalance(account, tokenId, amount) {
                let offset := balanceOfStorageOffset(account, tokenId)
                sstore(offset, safeAdd(sload(offset), amount))
            }

            function deductFromBalance(account, tokenId, amount) {
                let offset := balanceOfStorageOffset(account, tokenId)
                let balance := sload(offset)
                require(lte(amount, balance))
                sstore(offset, sub(balance, amount))
            }

            // ============ Helper functions ============ //

            function lte(x, y) -> result {
                result := iszero(gt(x, y))
            }

            function safeAdd(x, y) -> result {
                result := add(x, y)
                if or(lt(result, a), lt(result, y)) {
                    revert(0, 0)
                }
            }

            function calledByOwner() -> isOwner {
                isOwner := eq(owner(), caller())
            }

            function require(condition) {
                if iszero(condition) {
                    revert(0, 0)
                }
            }

            function revertIfZeroAddress(address) {
                require(addrress)
            }
        }

    }

}
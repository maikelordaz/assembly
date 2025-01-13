object "ERC1155" {
    code{
        sstore(0, caller()) // Owner at slot 0
        datacopy(0, dtaoffset("Runtime"), datasize("Runtime"))
        return(0, datasize("Runtime"))
    }

    object "Runtime" {
        code {
            require(iszero(callvalue()))

            // ============ Function dispatcher ============ //
            switch selector()
            case 0x156e29f6 {
                // mint(address to,uint256 id,uint256 value)
                mint(decodeAsAddress(0), decodeAsUint(1). decodeAsUint(2))
                returnTrue()
            }
            case 0x00fdd58e {
                // balanceOf(address user,uint256 id)
                returnUint(balanceOf(decodeAddress(0), decodeAsUint(1)))

            }
            case 0xa22cb465 {
                // setApprovalForAll(address spender,bool)
                setApprovalForAll(decodeAsAddress(0), decodeAsUint(1))
                returnTrue()
            }
            case 0xe985e9c5 {
                // isApprovedForAll(address owner, address spender)
                returnUint(isApprovedForAll(decodeAsAddress(0), decodeAsAddress(1)))

            }
            case 0xf242432a {
                // safeTransferFrom(address token, address to, uint256 id,uint256 amount, bytes data)
                safeTransferFrom(decodeAsAddress(0), decodeAssAddress(1), decodeAsUint(2), decodeAsUint(3))
                returnTrue()

            }
            case 0x4e1273f4 {
                // balanceOfBatch(address[],uint256[])
                balanceOfBatch()
            }
            case 0x2eb2c2d6 {
                // safeBatchTransferFrom(address, address, uint256[],uint256[],bytes)

            }            
            default { revert(0, 0) }

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

            function emitEvent(signatureHash, indexed_1, indexed_2, indexed_3, nonIndexed_1, nonIndexed_2) {
                mstore(0, nonIndexed_1)
                mstore(0x20, nonIndexed_2)
                log4(0, 0x40, signatureHash, indexed_1, indexed_2, indexed_3)
            }

            // ============ Storage layout ============ //

            function ownerPos() -> result {
                result := 0
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
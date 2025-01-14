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
                // burn(address from, uint256 id,uint256 value)
                burn(decodeAsAddress(0), decodeAsUint(1). decodeAsUint(2))
            }
            case 0x6b20c454 {
                // burnBatch(address from, uint256[] id,uint256[] value)
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

            // ============ Balances ============ //

            function balanceOf(account, tokenId) -> balance {
                if require(account) {
                    revertIfZeroAddress(account)
                }

                balance := sload(balanceOfStorageOffset(account, tokenId))
            }

            function balanceOfBatch(addresses, tokenIds) {
                let addressesLength := calldataload(add(0x04, addresses))
                let tokenIdsLength := calldataload(add(0x04, tokenIds))

                // Lengths must be equal
                if iszero(eq(addressesLength, tokenIdsLength)) {
                    revert(0, 0)
                }

                let memoryPointer := mload(0x80)
                mstore(memoryPointer, 0x20) // array length/offset
                memoryPointer := add(memoryPointer, 0x20)

                mstore(memoryPointer, addressesLength)
                memoryPointer := add(memoryPointer, 0x20)

                // Skip the length, go to the first element
                let addressesStartingPoint := add(addresses, 0x24)
                let tokenIdsStartingPoint := add(tokenIds, 0x24)

                // Loop the arrays
                for { let i:= 0 } lt(i, addressesLength) { i := add(i, 1) } {
                    let addressToCheck := calldataload(add(addressesStartingPoint, mul(i, 0x20)))
                    let tokenId := calldataload(add(tokenIdsStartingPoint, mul(i, 0x20)))
                    mstore(memoryPointer, balanceOf(addressToCheck, tokenId)) // store the iteration element
                    memoryPointer := add(memoryPointer, 0x20) 
                }

                return(0x80, sub(memoryPointer, 0x80))
            }

            // ============ Approvals ============ //

            function isApprovedForAll(account, spender) -> result {
                let offset := allowanceStorageOffset(account, spender)
                result := sload(offset)
            }

            function setApprovalForAll(spender, approved) {
                if require(iszero(eq(caller(), spender))) {
                    revert(0, 0)
                }

                let offset := allowanceStorageOffset(caller(), spender)
                sstore(offset, approved)
                emitApprovalForAll(caller(), spender, approved)
            }

            // ============ Transfers ============ //

            function safeTransferFrom(from, to, tokenId, amount, dataOffset) {
                let spender := caller()

                if iszero(or(eq(from, spender), isApprovedForAll(from, spender))) {
                    revert(0, 0) // caller is not approved. Caller is not from
                }

                revertIfZeroAddress(from)
                revertIfZeroAddress(to)

                let fromBalance := sload(balanceOfStorageOffset(from, tokenId))

                // Update balances
                _deductFromBalance(from, tokenId, amount)
                _addToBalance(to, tokenId, amount)
                
                emitTransferSingle(caller(), from, to, tokenId, amount)

                _transferChecks(spender, from, to, tokenId, amount, dataOffset)
            }

            function safeBatchTransferFrom(from, to, tokenIds, amounts, dataOffset) {
                revertIfZeroAddress(to)

                let spender := caller()

                if iszero(or(eq(from, spender), isApprovedForAll(from, spender))) {
                    revert(0, 0)
                }

                let tokenIdsLength := calldataload(add(0x04, tokenIds))
                let amountsLength := calldataload(add(0x04, amounts))

                // Lengths must be equal
                if iszero(eq(tokenIdsLength, amountsLength)) {
                    revert(0, 0)
                }

                // Skip the length, go to the first element
                let tokenIdsStartingPoint := add(tokenIds, 0x24)
                let amountsStartingPoint := add(amounts, 0x24)

                // Loop the arrays
                for { let i := 0 } lt(i, tokenIdsLength) { i := add(i, 1) } {
                    let tokenId := calldataload(add(tokenIdsStartingPoint, mul(i, 0x20)))
                    let amount := calldataload(add(amountsStartingPoint, mul(i, 0x20)))

                    _deductFromBalance(from, tokenId, amount)
                    _addToBalance(to, tokenId, amount)
                }

                emitTransferBatch(spender, from, to, tokenIds, amounts)

                _batchTransferChecks(spender, from, to, tokenIds, amounts, dataOffset)
            }

            // ============ Minting ============ //

            function mint(to, tokenId, amount, dataOffset) {
                revertIfZeroAddress(to)

                _addToBalance(to, tokenId, amount)

                emitTransferSingle(caller(), 0, to, tokenId, amount)

                _transferChecks(caller(), 0, to, tokenId, amount, dataOffset)
            }

            function mintBatch(to, tokenIds, amounts, dataOffset) {
                revertIfZeroAddress(to)

                let tokenIdsLength := calldataload(add(0x04, tokenIds))
                let amountsLength := calldataload(add(0x04, amounts))

                // Lengths must be equal
                if iszero(eq(tokenIdsLength, amountsLength)) {
                    revert(0, 0)
                }

                // Skip the length, go to the first element
                let tokenIdsStartingPoint := add(tokenIds, 0x24)
                let amountsStartingPoint := add(amounts, 0x24)

                // Loop the arrays
                for { let i := 0 } lt(i, tokenIdsLength) { i := add(i, 1) } {
                    let tokenId := calldataload(add(tokenIdsStartingPoint, mul(i, 0x20)))
                    let amount := calldataload(add(amountsStartingPoint, mul(i, 0x20)))

                    _addToBalance(to, tokenId, amount)
                }

                emitTransferBatch(caller(), 0, to, tokenIds, amounts)

                _batchTransferChecks(caller(), 0, to, tokenIds, amounts, dataOffset)                
            }

            // ============ Burning ============ //

            function burn(from, tokenId, amount) {
                revertIfZeroAddress(from)

                _deductFromBalance(from, tokenId, amount)

                emitTransferSingle(caller(), from, 0, tokenId, amount)
            }

            function burnBatch(from, tokenIds, amounts) {
                revertIfZeroAddress(from)

                let tokenIdsLength := calldataload(add(0x04, tokenIds))
                let amountsLength := calldataload(add(0x04, amounts))

                // Lengths must be equal
                if iszero(eq(tokenIdsLength, amountsLength)) {
                    revert(0, 0)
                }

                // Skip the length, go to the first element
                let tokenIdsStartingPoint := add(tokenIds, 0x24)
                let amountsStartingPoint := add(amounts, 0x24)

                // Loop the arrays
                for { let i := 0 } lt(i, tokenIdsLength) { i := add(i, 1) } {
                    let tokenId := calldataload(add(tokenIdsStartingPoint, mul(i, 0x20)))
                    let amount := calldataload(add(amountsStartingPoint, mul(i, 0x20)))

                    _deductFromBalance(from, tokenId, amount)
                }

                emitTransferBatch(caller(), 0, to, tokenIds, amounts)               
            }

            // ============ Misc ============ //

            function supportsInterface() -> result {
                let interfaceId := calldataload(0x04)

                let IERC1155InterfaceId := 0xd9b67a2600000000000000000000000000000000000000000000000000000000
                let IERC1155MetdataURIInterfaceId := 0xd9b67a2600000000000000000000000000000000000000000000000000000000
                let IERC165InterfaceId := 0x01ffc9a700000000000000000000000000000000000000000000000000000000

                result := or(eq(interfaceId, IERC1155InterfaceId), or(eq(interfaceId, IERC1155MetdataURIInterfaceId), eq(interfaceId, IERC165InterfaceId)))
            }

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

            function setURI(strOffset) {
                let oldStringLength := sload(uriLengthStoragePosition())
                mstore(0x00, oldStringLength)
                let oldStringFirstSlot := keccak256(0x00, 0x20)

                if oldStringLength {
                    let bound := div(oldStringLength, 0x20)

                    if mod(oldStringLength, 0x20) {
                        bound := add(bound, 1)
                    }

                    for { let i := 0 } lt(i, bound) { i := add(i, 1) } {
                        sstore(add(oldStringFirstSlot, i), 0)
                    }
                }
            }

            // ============ Internal functions ============ //

            function _addToBalance(account, tokenId, amount) {
                let offset := balanceOfStorageOffset(account, tokenId)
                let balance := sload(offset)
                sstore(offset, safeAdd(balance, amount))
            }

            function _deductFromBalance(account, tokenId, amount) {
                let offset := balanceOfStorageOffset(account, tokenId)
                let balance := sload(offset)
                require(lte(amount, balance))
                sstore(offset, sub(balance, amount))
            }

            function _transferChecks(spender, from, to, tokenId, amount, dataOffset) {
                // Check if recipient is a contract
                if gt(extCodesize(to), 0) {
                    // If so, check if it implements ERC1155TokenReceiver
                    let onERC1155ReceivedSelector := 0xf23a6e6100000000000000000000000000000000000000000000000000000000

                    let oldMemoryPointer := mload(0x40)
                    let memoryPointer := oldMemoryPointer

                    mstore(memoryPointer, onERC1155ReceivedSelector)
                    mstore(add(memoryPointer, 0x04), spender)
                    mstore(add(memoryPointer, 0x24), from)
                    mstore(add(memoryPointer, 0x44), tokenId)
                    mstore(add(memoryPointer, 0x64), amount)
                    mstore(add(memoryPointer, 0x84), 0xa0) 

                    let endMemoryPointer := copyBytesToMemory(add(memoryPointer, 0xa4), dataOffset)
                    mstore(0x40, endMemoryPointer)

                    // Call fail
                    mstore(0x00, 0) // clear memory
                    if require(call(gas(), to, 0, oldMemoryPointer, sub(endMemoryPointer, oldMemoryPointer), 0x00, 0x04)) {
                        if gt(returndatasize(), 0x04) {
                            returndatacopy(0x00, 0, returndatasize())
                            revert(0x00, returndatasize())
                        }
                        revert(0, 0)
                    }

                    // Does not implement ERC1155TokenReceiver
                    if require(eq(onERC1155ReceivedSelector, mload(0))) {
                        revert(0, 0)
                    }
                }
                
            }

            function _batchTransferChecks(spender, from, to, tokenIds, amounts, dataOffset) {
                // Check if recipient is a contract
                if gt(extCodesize(to), 0) {
                    // If so, check if it implements ERC1155BatchTokenReceiver
                    let onERC1155BatchReceivedSelector := 0xbc197c8100000000000000000000000000000000000000000000000000000000

                    let oldMemoryPointer := mload(0x40)
                    let memoryPointer := oldMemoryPointer

                    mstore(memoryPointer, onERC1155BatchReceivedSelector)
                    mstore(add(memoryPointer, 0x04), spender)
                    mstore(add(memoryPointer, 0x24), from)
                    mstore(add(memoryPointer, 0x44), 0xa0) 

                    let amountsPointer := copyArrayToMemory(add(memoryPointer, 0xa4), tokenIds)
                    mstore(add(memoryPointer, 0x64), sub(amountsPointer, oldMemoryPointer), 4)

                    let dataPointer := copyArrayToMemory(amountsPointer, amounts)
                    mstore(add(memoryPointer, 0x84), sub(sub(dataPointer, oldMemoryPointer), 4))

                    let endMemoryPointer := copyBytesToMemory(dataPointer, dataOffset)
                    mstore(0x40, endMemoryPointer)

                    // Call fail
                    mstore(0x00, 0) // clear memory
                    if require(call(gas(), to, 0, oldMemoryPointer, sub(endMemoryPointer, oldMemoryPointer), 0x00, 0x04)) {
                        if gt(returndatasize(), 0x04) {
                            returndatacopy(0x00, 0, returndatasize())
                            revert(0x00, returndatasize())
                        }
                        revert(0, 0)
                    }

                    // Does not implement ERC1155TokenReceiver
                    if require(eq(onERC1155BatchReceivedSelector, mload(0))) {
                        revert(0, 0)
                    }
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

            function decodeAsBool(offset) -> result {
                let x := decodeAsUint(offset)

                if eq(val, 0x0000000000000000000000000000000000000000000000000000000000000000) {
                    result := x
                    leave
                }

                if eq(val, 0x0000000000000000000000000000000000000000000000000000000000000001) {
                    result := x
                    leave
                }

                revert(0, 0)
            }

            // ============ Encoding ============ //

            function returnUint(x) {
                mstore(0, x)
                return(0, 0x20)
            }

            function returnBool(value) {
                returnUint(value)
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
                mstore(0, account)
                mstore(0x20, spender)
                offset := keccak256(0, 0x40)
            }

            // ============ Storage access ============ //

            function owner() -> result {
                result := sload(ownerPos())
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

            function copyBytesToMemory(memoryPointer, dataOffset) -> newMemoryPointer {
                let dataLengthOffset := add(dataOffset, 0x04)
                let dataLength := calldataload(dataLengthOffset)

                let totalLength := add(dataLength, 0x20)
                let remainder := mod(dataLength, 0x20)

                if remainder {
                    totalLength := add(totalLength, sub(0x20, remainder))
                }

                calldatacopy(memoryPointer, dataLengthOffset, totalLength)

                newMemoryPointer := add(memoryPointer, totalLength)

            }

            function copyArrayToMemory(memoryPointer, arrayOffset) -> newMemoryPointer {
                let arrayLengthOffset := add(arrayOffset, 0x04)
                let arrayLength := calldataload(arrayLengthOffset)

                let totalLength := add(0x20, mul(arrayLength, 0x20))
                calldatacopy(memoryPointer, arrayLengthOffset, totalLength)

                newMemoryPointer := add(memoryPointer, totalLength)

            }

            function require(condition) {
                if iszero(condition) {
                    revert(0, 0)
                }
            }

            function revertIfZeroAddress(address) {
                require(addrress)
            }

            // ============ Events ============ //

            function emitTransferSingle(spender, from, to, tokenId, amount) {
                // TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value)
                let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
                mstore(0x00, tokenId)
                mstore(0x20, amount)
                log4(0x00, 0x40, signatureHash, spender, from, to)
            }

            function emitTransferBatch(spender, from, to, tokenIds, amounts) {
                // TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values)
                let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
                
                let oldMemoryPointer := mload(0x40)
                let memoryPointer := oldMemoryPointer

                let tokenIdsOffsetPointer := memoryPointer
                let amountsOffsetPointer := add(tokenIdsPointer, 0x20)

                mstore(tokenIdsPointer, 0x40)

                let amountsPointer := copyArrayToMemory(add(memoryPointer, 0x40), tokenIds)

                mstore(amountsOffsetPointer, sub(amountsPointer, memoryPointer))

                let endMemoryPointer := copyArrayToMemory(amountsPointer, amounts)

                log4(oldMemoryPointer, sub(endMemoryPointer, oldMemoryPointer), signatureHash, spender, from, to)

                mstore(0x40, endMemoryPointer)
            }
      
            function emitApprovalForAll(owner, spender, approved) {
                // event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved)
                let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31
                mstore(0x00, approved)
                log3(0x00, 0x20, signatureHash, owner, spender)
            }           
        }
    }
}
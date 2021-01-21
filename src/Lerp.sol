pragma solidity ^0.6.11;

interface FileLike {
    function file(bytes32, uint256) external;
}

interface FileIlkLike {
    function file(bytes32, bytes32, uint256) external;
}

// Perform linear interpolation on a dss administrative value over time

abstract contract BaseLerp {

    uint256 constant WAD = 10 ** 18;

    address immutable public target;
    bytes32 immutable public what;
    uint256 immutable public start;
    uint256 immutable public end;
    uint256 immutable public duration;

    bool              public done;
    uint256           public startTime;

    constructor(address target_, bytes32 what_, uint256 start_, uint256 end_, uint256 duration_) public {
        require(duration_ != 0, "Lerp/no-zero-duration");
        require(duration_ <= 365 days, "Lerp/max-duration-one-year");
        // This is not the exact upper bound, but it's a practical one
        // Ballparked from 2^256 / 10^18 and verified that this is less than that value
        require(start_ <= 10 ** 59, "Lerp/start-too-large");
        require(end_ <= 10 ** 59, "Lerp/end-too-large");
        target = target_;
        what = what_;
        start = start_;
        end = end_;
        duration = duration_;
        startTime = block.timestamp;
        done = false;
    }

    function tick() external {
        require(!done, "Lerp/finished");
        if (block.timestamp < startTime + duration) {
            // All bounds are constrained in the constructor so no need for safe-math
            // 0 <= t < WAD
            uint256 t = (block.timestamp - startTime) * WAD / duration;
            // y = (end - start) * t + start [Linear Interpolation]
            //   = end * t + start - start * t [Avoids overflow by moving the subtraction to the end]
            update(end * t / WAD + start - start * t / WAD);
        } else {
            // Set the end value and attempt to de-auth yourself
            update(end);
            target.call(abi.encodeWithSignature("deny(address)", address(this)));
            done = true;
        }
    }

    function update(uint256 value) virtual internal;

}

// Standard Lerp with only a uint256 value

contract Lerp is BaseLerp {

    constructor(address target_, bytes32 what_, uint256 start_, uint256 end_, uint256 duration_) public BaseLerp(target_, what_, start_, end_, duration_) {
    }

    function update(uint256 value) override internal {
        FileLike(target).file(what, value);
    }

}

// Lerp that takes an ilk parameter

contract IlkLerp is BaseLerp {

    bytes32 immutable public ilk;

    constructor(address target_, bytes32 ilk_, bytes32 what_, uint256 start_, uint256 end_, uint256 duration_) public BaseLerp(target_, what_, start_, end_, duration_) {
        ilk = ilk_;
    }

    function update(uint256 value) override internal {
        FileIlkLike(target).file(ilk, what, value);
    }
}

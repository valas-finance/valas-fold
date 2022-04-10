pragma solidity 0.7.6;

interface IWBNB {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

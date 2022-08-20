// SPDX-License-Identifier: MIT
pragma solidity >=0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                          // Account used to deploy contract
    bool private operational = true;                        // Blocks all state changes throughout the contract if false
    
    struct AirlineInfo {
        bool isRegistered;
        bool hasFunded;
    }
    mapping(address => AirlineInfo) airlines;               // Mapping of registered airlines
    uint256 numAirlines;                                    // Number of registered airlines
    
    struct PassengerInfo {
        uint256 balance;
        uint256 insuranceValue;
    }
    mapping(address => PassengerInfo) private passengers;   // Mapping of registered passengers

    
    mapping(address => uint256) private authorizedContracts;    // Mapping for authorized Contracts

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    
    event AirlineRegistered(address indexed airline);
    event AirlineSubmittedFunding(address indexed airline);
    event InsuranceBought(address indexed passenger, uint256 amount);
    event InsureeCredited(address indexed passenger);
    event FundsWithdrawn(address indexed passenger, uint256 amount);

    event AuthorizedContract(address indexed contractAddress);
    event DeAuthorizedContract(address indexed contractAddress);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public
    {
        contractOwner = msg.sender;

        airlines[msg.sender] = AirlineInfo({
            isRegistered: true,
            hasFunded: false});

        numAirlines = 0;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsRegisteredAirline(address airline)
    {
        require(airlines[airline].isRegistered, "Airline is not registered");
        _;
    }

    modifier fundingSubmitted(address airline)
    {
        require(airlines[airline].hasFunded, "Airline has not submitted funding");
        _;
    }

    modifier isCallerAutorized(){
        require(authorizedContracts[msg.sender] == 1, "Caller is not authorized to call this contract");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() external view returns(bool) 
    {
        return operational;
    }

    /**
     * @dev Is airline registered?
     * @param _airline Address of airline to check
     * @return bool that is true if airline is registered
     */
    function isAirlineRegistered(address _airline) external view returns(bool)
    {
        return airlines[_airline].isRegistered;
    }

    /**
     * @dev Has airline submitted funding?
     * @param _airline Address of airline to check
     * @return bool that is true if airline has submitted funding
     */
    function hasSubmittedFunding(address _airline) external view returns(bool)
    {
        return airlines[_airline].hasFunded;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */    
    function setOperatingStatus(bool mode) external requireContractOwner
    {
        // require(mode != operational, "New mode must be different from existing mode");
        operational = mode;
    }

    /**
     * @dev Get number of registered airlines
     * @return An uint that is the number of registered airlines
     */
    function getNumRegisteredAirlines() external view returns(uint256)
    {
        return numAirlines;
    }

    /**
     * @dev Get insurance value of passenger
     * @param _passenger Address of passenger to check
     * @return uint value
     */
    function getInsuranceValue(address _passenger) external view returns(uint256)
    {
        return passengers[_passenger].insuranceValue;
    }

    /**
     * @dev Get balance of passenger
     * @param _passenger Address of passenger to check
     * @return uint value
     */
    function getBalance(address _passenger) external view returns(uint256)
    {
        return passengers[_passenger].balance;
    }
   
    function authorizeContract(address contractAddress) external requireContractOwner 
    {
        authorizedContracts[contractAddress] = 1;
        emit AuthorizedContract(contractAddress);
    }

    function deauthorizeContract(address contractAddress) external requireContractOwner 
    {
        delete authorizedContracts[contractAddress];
        emit DeAuthorizedContract(contractAddress);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
// region Airlines
    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     * @param _airline Address of airline to add
     * @return bool that is true if the airline was added
     */   
    function registerAirline(address _airline) external
        requireIsOperational
        isCallerAutorized
    {
        airlines[_airline] = AirlineInfo(true, false);
        emit AirlineRegistered(_airline);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(address _airline) external payable
        requireIsOperational
        isCallerAutorized
    {
        airlines[_airline].hasFunded = true;
        numAirlines = numAirlines.add(1);
        emit AirlineSubmittedFunding(_airline);
    }
// end region

// region Passengers
    // /**
    // * @dev Register a passenger
    // * @param _passenger Address of passenger to register
    // */
    // function registerPassenger(address _passenger)
    //                         external
    //                         // requireIsOperational
    // {
    //     passengers[_passenger] = PassengerInfo(true, 0, 0, 0);
    // }

   /**
   
    * @dev Buy insurance for a flight
    * @param _passenger Address of passenger
    * @return bool that is true if the insurance was purchased
    */   
    function buy(address _passenger) external payable
        requireIsOperational
        isCallerAutorized
    {
        passengers[_passenger].insuranceValue = msg.value;
        emit InsuranceBought(_passenger, msg.value);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address _passenger) external
        requireIsOperational
        isCallerAutorized
    {
        uint256 credit = passengers[_passenger].insuranceValue.mul(3).div(2);
        passengers[_passenger].balance = passengers[_passenger].balance.add(credit);
        emit InsureeCredited(_passenger);
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address _passenger, uint256 _amount) external payable
        requireIsOperational
        isCallerAutorized
    {
        require(_amount <= passengers[_passenger].balance, "Amount to withdraw exceeds balance");

        passengers[_passenger].balance = passengers[_passenger].balance.sub(_amount);
        address(uint160(_passenger)).transfer(_amount);
        emit FundsWithdrawn(_passenger, _amount);
    }

// end region

    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal
        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable
    {
        // fund(msg.sender);
    }
}


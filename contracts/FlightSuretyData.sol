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
        string name;
        bool isRegistered;
        bool fundingSubmitted;
    }
    mapping(address => AirlineInfo) private airlines;       // Mapping of registered airlines

    uint256 private numAirlines = 0;                        // Number of registered airlines
    uint256 constant minAirlines = 4;                       // Minimum number of airlines for multi-party consensus 
    address[] multiCalls = new address[](0);                // Array of addresses
    address private airlineToRegister = address(0);         // Address of airline to register
    
    struct PassengerInfo {
        uint256 balance;
        uint256 insuranceValue;
    }
    mapping(address => PassengerInfo) private passengers;       // Mapping of registered passengers

    
    mapping(address => uint256) private authorizedContracts;       // Mapping for authorized Contracts

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AirlineRegistered(address indexed airline);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public
    {
        contractOwner = msg.sender;
        airlines[contractOwner] = AirlineInfo({
            name: "First Airline",
            isRegistered: true,
            fundingSubmitted: true});
        numAirlines.add(1);
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

    modifier hasFunded(address airline)
    {
        require(airlines[airline].fundingSubmitted, "Airline has not submitted funding");
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
     * @return A bool that is true if airline is registered
     */
    function isAirlineRegistered(address _airline) external view returns(bool)
    {
        return airlines[_airline].isRegistered;
    }

    /**
     * @dev Has airline submitted funding?
     * @param _airline Address of airline to check
     * @return A bool that is true if airline has submitted funding
     */
    function hasSubmittedFunding(address _airline) external view returns(bool)
    {
        return airlines[_airline].fundingSubmitted;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner
    {
        require(mode != operational, "New mode must be different from existing mode");
        operational = mode;
    }

    
    function authorizeContract(address contractAddress) external requireContractOwner {
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeContract(address contractAddress) external requireContractOwner {
        delete authorizedContracts[contractAddress];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
// region Airlines
    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     * @param _airline Address of airline to add
     * @param _name Name of airline to add
     * @return bool that is true if the airline was added
     */   
    function registerAirline(address _airline, string calldata _name)
                            external
                            requireIsOperational
                            isCallerAutorized
                            // requireIsRegisteredAirline(msg.sender)
                            // hasFunded(msg.sender)
                            // requireIsRegisteredAirline(tx.origin)
                            // hasFunded(tx.origin)
                            returns(bool)
    {
        if(airlineToRegister == address(0))
        {
            airlineToRegister = _airline;
        }

        // If number of registered airlines is equal or more than 4, then multiparty consensus is required
        if(numAirlines >= minAirlines)
        {    
            bool isDuplicate = false;
            for(uint c = 0; c < multiCalls.length; c++) {
                if (multiCalls[c] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }
            require(!isDuplicate, "Caller has already called this function.");

            if(_airline == airlineToRegister) {
                multiCalls.push(msg.sender);

                if (multiCalls.length >= numAirlines.div(2)) {
                    airlines[_airline] = AirlineInfo(_name, true, false);
                    ///numAirlines.add(1);     
                    multiCalls = new address[](0);
                    airlineToRegister = address(0);
                    emit AirlineRegistered(airlineToRegister);
                    return true;
                }
            }
        }
        // If the number of airlines is less than the minimum for multi-party consensus, then the airline can be registered
        else   
        {
            airlines[airlineToRegister] = AirlineInfo(_name, true, false);
            //numAirlines.add(1);
            emit AirlineRegistered(airlineToRegister);
            return true;
        }
        return false;
    }
   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(address _airline)
                            public
                            payable
                            // requireIsOperational
                            // isCallerAutorized
                            // requireIsRegisteredAirline(_airline)
    {
        require(msg.value == 10 ether, "Funding must be 10 ether");
        airlines[_airline].fundingSubmitted = true;
        numAirlines.add(1);
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
    * @param _amount Amount of ether to buy insurance
    * @return bool that is true if the insurance was purchased
    */   
    function buy(address _passenger, uint256 _amount) external 
        requireIsOperational
        isCallerAutorized
        returns(bool)
    {
        require(_amount > 0, "Insurance amount must be greater than 0");
        require(_amount <= 1 ether, "Insurance amount may be up to 1 ETH");
        passengers[_passenger].insuranceValue = _amount;

        return true;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address _passenger) external view
        requireIsOperational
        isCallerAutorized
    {
        uint256 credit = passengers[_passenger].insuranceValue.mul(3).div(2);
        passengers[_passenger].balance.add(credit);
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address _passenger)
                            external
                            payable
                            requireIsOperational
                            isCallerAutorized
    {
        require(passengers[_passenger].balance > 0, "No balance to withdraw");

        uint256 amount = passengers[_passenger].balance;
        passengers[_passenger].balance = 0;
        address(uint160(_passenger)).transfer(amount);
    }

// end region

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
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
        fund(msg.sender);
    }
}


// SPDX-License-Identifier: MIT
pragma solidity >=0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
// region DATA VARIABLES
    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        bool payout;
    }
    mapping(bytes32 => Flight) flights;
    mapping(bytes32 => address []) passengerList; // Insured passenger list for each flight

    
    uint256 constant minAirlines = 4;                       // Minimum number of airlines for multi-party consensus 
    //address[] multiCalls = new address[](0);                // Array of addresses
    mapping(address => address []) private voters;          // Voters for each airline

    FlightSuretyData flightSuretyData;
// endregion
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
// region EVENT DEFINITIONS
    event airlineVoted(address indexed airline, uint numVotes);
    event creditInsuree(address indexed airline, uint256 amount);

// endregion
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/
// region Modifiers
    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status0,3
        require(flightSuretyData.isOperational(), "Contract is currently not operational");  
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

    /**
     * @dev Modifier that requires the "airline" account to be the registered
     */
    modifier requireRegisteredAirline(address _airline)
    {
        require(flightSuretyData.isAirlineRegistered(_airline), "Airline is not registered");
        _;
    }

    /**
     * @dev Modifier that requires the "airline" account to have submitted funding
     */
    modifier requireFundedAirline(address _airline)
    {
        require(flightSuretyData.hasSubmittedFunding(_airline), "Airline has not submitted funding");
        _;
    }
// endregion
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/
// region Constructor
    /**
    * @dev Contract constructor
    *
    */
    constructor(address dataContract) public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }
// endregion
    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/
// region Utility functions
    function isOperational() 
                            external 
                            returns(bool) 
    {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    function isAirlineRegistered(address airline) external view returns(bool) 
    {
        return flightSuretyData.isAirlineRegistered(airline);
    }

    function hasSubmittedFunding(address _airline) external view returns(bool)
    {
        return flightSuretyData.hasSubmittedFunding(_airline);
    }

    function isFlightRegistered(address _airline, string calldata _flight, uint256 _timestamp) external view returns(bool)
    {
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        return flights[flightKey].isRegistered;
    }

    function getInsuranceValue(address _passenger) external view returns(uint256)
    {
        return flightSuretyData.getInsuranceValue(_passenger);
    }

    function getBalance(address _passenger) external view returns(uint256)
    {
        return flightSuretyData.getBalance(_passenger);
    }

// endregion
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
// region Functions
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(address _airline) external
        requireRegisteredAirline(msg.sender)
        requireFundedAirline(msg.sender)
        returns(bool, uint)
    {
        require(flightSuretyData.isAirlineRegistered(_airline) == false, "Airline is already registered");

        uint numAirlines = flightSuretyData.getNumRegisteredAirlines();
        uint votes = 0;
        // If number of registered airlines is equal or more than 4, then multiparty consensus is required
        if(numAirlines >= minAirlines)
        {    
            bool isDuplicate = false;
            if(voters[_airline].length == 0)
            {
                isDuplicate = false;
            }
            else
            {
                for(uint c = 0; c < voters[_airline].length; c++) {
                    if (voters[_airline][c] == msg.sender) {
                        isDuplicate = true;
                        break;
                    }
                }
            }
            require(!isDuplicate, "Caller has already voted in this airline!");

            voters[_airline].push(msg.sender);

            if (voters[_airline].length >= numAirlines.div(2)) 
            {
                flightSuretyData.registerAirline(_airline);
                return (true, voters[_airline].length);
            }
            else
            {
                votes = voters[_airline].length;

                emit airlineVoted(_airline, votes);
                return (false, votes);
            }
        }
        // If the number of airlines is less than the minimum for multi-party consensus, then the airline can be registered
        else   
        {
            flightSuretyData.registerAirline(_airline);
            return (true, 1);
        }
        // return (false, 0);
    }

   /**
    * @dev Register a future flight for insuring.
    * @param _airline The airline that is registering the flight.
    * @param _flight The flight number.
    * @param _timestamp The timestamp of the flight.
    * @return bool indicating whether the flight was registered.
    */  
    function registerFlight(address _airline, string calldata _flight, uint256 _timestamp) external returns(bool)
    {
        // Check if airline is registered
        require(flightSuretyData.isAirlineRegistered(_airline), "Airline is not registered");
        // Check if timestamp is in the future
        require(_timestamp > block.timestamp, "Flight is in the past");

        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        // Check if flight is already registered
        require(!flights[flightKey].isRegistered, "Flight is already registered");

        // Register flight
        flights[flightKey].isRegistered = true;
        flights[flightKey].statusCode = STATUS_CODE_UNKNOWN;
        flights[flightKey].updatedTimestamp = _timestamp;
        flights[flightKey].airline = _airline;
        flights[flightKey].payout = false;
        return true;
    }

   
   /**
    * @dev Called after oracle has updated flight status
    * @param airline address of the airline
    */  
    function processFlightStatus(address airline, string memory flight, uint256 timestamp, uint8 statusCode) internal
    {
        // bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        // oracleResponses[key].isOpen = false;

        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        require(flights[flightKey].payout == false, "Flight has already been paid out");
        // Check if there are passengers registered for this flight
        require(passengerList[flightKey].length > 0, "No passengers registered for this flight");
        // Set status code
        flights[flightKey].statusCode = statusCode;

        // If late due to airline
        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            // Credit insurees
            for (uint256 i = 0; i < passengerList[flightKey].length; i++)
            {
                flightSuretyData.creditInsurees(passengerList[flightKey][i]);
            }
            flights[flightKey].payout = true;
        }

    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, string calldata flight, uint256 timestamp) external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


    /**
     * @dev Buy insurance for a flight
     * @param _flight bytes32 The flight number
     */
    function buyInsurance(address _airline, string calldata _flight, uint256 _timestamp) external payable returns(bool)
    {
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        // Check if flight is registered
        require(flights[flightKey].isRegistered, "Flight is not registered");
        require(msg.value > 0, "Insurance amount must be greater than 0");
        require(msg.value <= 1 ether, "Insurance amount may be up to 1 ETH");

        flightSuretyData.buy.value(msg.value)(msg.sender);
        // Add passenger to list
        passengerList[flightKey].push(msg.sender);
    }

    /**
     * @dev Withdraw funds from the contract
     * @return bool indicating whether the withdrawal was successful.
     */
    function withdraw(uint256 _amount) external payable returns(bool)
    {
        flightSuretyData.pay(msg.sender, _amount);
        return true;
    }

    /**
     * @dev Submit funding
     */
    function submitFunding() payable public
    {
        require(flightSuretyData.isAirlineRegistered(msg.sender), "Airline is not registered");
        require(msg.value == 10 ether, "Funding must be 10 ether");

        flightSuretyData.fund.value(msg.value)(msg.sender);
    }
// end region

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


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

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }
// endregion
} 

contract FlightSuretyData {
    function isOperational() external returns(bool);
    function isAirlineRegistered(address _airline) external view returns(bool);
    function hasSubmittedFunding(address _airline) external view returns(bool);
    function registerAirline(address _airline) external;
    function buy(address _passenger) external payable;
    function creditInsurees(address _passenger) external;
    function pay(address _passenger, uint _amount) external payable;
    function fund(address _airline) external payable;
    function getNumRegisteredAirlines() external view returns(uint256);
    function getInsuranceValue(address _passenger) external view returns(uint256);
    function getBalance(address _passenger) external view returns(uint256);
}

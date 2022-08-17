
const { debug } = require('webpack');
var Test = require('../config/testConfig.js');
//var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

	const flightName = 'ND1309'; // Course number
	const timestamp = Math.floor(Date.now() / 1000);
	

	var config;
	before('setup contract', async () => {
		config = await Test.Config(accounts);
		await config.flightSuretyData.authorizeContract(config.flightSuretyApp.address);
	});

	/****************************************************************************************/
	/* Operations and Settings                                                              */
	/****************************************************************************************/

	it(`(multiparty) has correct initial isOperational() value`, async function () {

		// Get operating status
		let status = await config.flightSuretyApp.isOperational.call();
		assert.equal(status, true, "Incorrect initial operating status value");

	});

	it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

		// Ensure that access is denied for non-Contract Owner account
		let accessDenied = false;
		try 
		{
			await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
		}
		catch(e) {
			accessDenied = true;
		}
		assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
				
	});

	it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

		// Ensure that access is allowed for Contract Owner account
		let accessDenied = false;
		try 
		{
			await config.flightSuretyData.setOperatingStatus(false);
		}
		catch(e) {
			accessDenied = true;
		}    
		// Set it back for other tests to work
		await config.flightSuretyData.setOperatingStatus(true);

		assert.equal(accessDenied, false, "Access not restricted to Contract Owner");     
	});

	it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

		await config.flightSuretyData.setOperatingStatus(false);

		let reverted = false;
		try 
		{
			await config.flightSuretyApp.registerAirline(accounts[4], "AirlineX");
		}
		catch(e) {
			reverted = true;
			// console.log(e);
		}    
		// Set it back for other tests to work
		await config.flightSuretyData.setOperatingStatus(true);

		assert.equal(reverted, true, "Access not blocked for requireIsOperational");      
	});

	it('(airlines) first airline registered when contract is deployed', async () => {
		// ARRANGE
		const firstAirline = accounts[0];

		// ACT
		let result = await config.flightSuretyApp.isRegisteredAirline(firstAirline);
		//result &= await config.flightSuretyApp.hasSubmittedFunding(firstAirline);

		// ASSERT
		assert.equal(result, true, "First airline not registered");
	});

    // Only existing airline may register a new airline until there are at least four airlines registered
    it('(airlines) Only existing airline may register a new airline until there are at least four airlines registered', async () => {
        // ARRANGE
        const existingAirline = accounts[0];
        const newAirline = accounts[1];
        const newAirlineName = "AirlineX";
    
        // ACT
        let result = await config.flightSuretyApp.registerAirline(newAirline, newAirlineName);

        // ASSERT
        assert.equal(result, true, "New airline not registered");
    });

    // Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines
    it('(airlines) Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines', async () => {
        // ARRANGE
        const existingAirline = accounts[0];
        const newAirline = accounts[1];
        const newAirlineName = "AirlineX";
    
        // ACT
        let result = await config.flightSuretyApp.registerAirline(newAirline, newAirlineName);

        // ASSERT
        assert.equal(result, true, "New airline not registered");
    });

    // Airline can be registered, but does not participate in contract until it submits funding of 10 ether
    it('(airlines) Airline registered, but does not participate in contract until it submits funding of 10 ether', async () => {
        // ARRANGE
        const existingAirline = accounts[0];
        const newAirline = accounts[1];
        const newAirlineName = "AirlineX";
    
        // ACT
        let result = await config.flightSuretyApp.registerAirline(newAirline, newAirlineName);

        // ASSERT
        assert.equal(result, false, "New airline registered");
    });

    // Passengers may pay up to 1 ether for purchasing flight insurance
    it('(passengers) Passengers may pay up to 1 ether for purchasing flight insurance', async () => {
        // ARRANGE
        const passenger = accounts[2];
        const amount = web3.utils.toWei("1", "ether");
    
        // ACT
        let result = await config.flightSuretyApp.buy(config.flightSuretyData.address, passenger, amount);

        // ASSERT
        assert.equal(result, true, "Passenger not purchased insurance");
    });

    // If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid
    it('(passengers) If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid', async () => {

    });

    // Passenger can withdraw any funds owed to them as a result of receiving credit for insurance payout
    it('(passengers) Passenger can withdraw any funds owed to them as a result of receiving credit for insurance payout', async () => {
           
    });

    // Upon startup, 20+ oracles are registered and their assigned indexes are persisted in memory
    it('(oracles) Upon startup, 20+ oracles are registered and their assigned indexes are persisted in memory', async () => {
        // ARRANGE
        const oracles = accounts.slice(3, 23);
        const oraclesCount = oracles.length;
        const oraclesIndexes = [];
    
        // ACT
        for (let i = 0; i < oraclesCount; i++) {
            let result = await config.flightSuretyApp.registerOracle(oracles[i], config.ORACLES_COUNT);
            oraclesIndexes.push(result.logs[0].args.index.toNumber());
        }
    
        // ASSERT
        assert.equal(oraclesIndexes.length, oraclesCount, "Not all oracles registered");
    });

    
});

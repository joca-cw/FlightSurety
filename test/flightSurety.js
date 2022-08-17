
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

	it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
		
		// ARRANGE
		let newAirline = accounts[2];
		// ACT
		try {
			await config.flightSuretyApp.registerAirline(newAirline, "AirlineX");
		}
		catch(e) {
			console.log(e);
		}
		let result = await config.flightSuretyApp.isRegisteredAirline(newAirline); 

		// ASSERT
		assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

	});

	it('(airline) can register an Airline using registerAirline() if it is funded', async () => {
		
		// ARRANGE
		let newAirline = accounts[3];

		
		// ACT
		try {
			//await config.flightSuretyData.fund(accounts[0], {value: web3.utils.toWei('10', 'ether')});
			await config.flightSuretyApp.registerAirline(newAirline, "AirlineY");
		}
		catch(e) {
			console.log(e);
		}
		let result = await config.flightSuretyData.isRegisteredAirline.call(newAirline); 

		// ASSERT
		assert.equal(result, true, "Airline should be able to register another airline if it has provided funding");

	});

	it('(airline) Can register flight', async () => {
		// ARRANGE
		
		// ACT
		try {
			await config.flightSuretyApp.registerFlight(flightName, timestamp);
		}
		catch(e) {
			console.log(e);
		}
		let result = await config.flightSuretyApp.isRegisteredFlight(flightName, timestamp);

		// ASSERT
		assert.equal(result, true, "Airline should be able to register another airline if it has provided funding");

	});

	// Passengers may pay up to 1 ether for purchasing flight insurance.
	it('(passenger) can buy insurance for a flight', async () => {
		// ARRANGE
		let passenger = accounts[9];
		let flight = 'ND-123';
		let amount = web3.utils.toWei('1', 'ether');
		let timestamp = Math.floor(Date.now() / 1000);

		// ACT
		try {
			await config.flightSuretyApp.buyInsurance(config.firstAirline, flight, timestamp, {from: passenger, value: amount});
		}
		catch(e) {
			console.log(e);
		}
		let result = await config.flightSuretyApp.isPurchased(config.firstAirline, config.firstFlight, passenger);
		// ASSERT
		assert.equal(result, true, "Passenger should be able to buy insurance for a flight");
	
	});

	// // If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid
	// it('(passenger) can claim insurance for a delayed flight', async () => {
	// 	// ARRANGE
	// 	let passenger = accounts[9];
				
	// 	// ACT
	// 	try	{
	// 		await config.flightSuretyApp.claim(config.firstAirline, config.firstFlight, {from: passenger});
	// 	}
	// 	catch(e) {
	// 		console.log(e);
	// 	}
	// 	let result = await config.flightSuretyApp.checkBalance(config.firstAirline, config.firstFlight, passenger);

	// 	// ASSERT
	// 	assert.equal(result, true, "Passenger should be able to claim insurance for a delayed flight");
	
	// });

	// Passenger can withdraw any funds owed to them as a result of receiving credit for insurance payout
	it('(passenger) can withdraw insurance funds', async () => {
		// ARRANGE
		let passenger = accounts[9];
		let balanceBefore = await web3.eth.getBalance(passenger);
		// ACT
		try {
			await config.flightSuretyApp.withdraw({from: passenger});
		}
		catch(e) {
			console.log(e);
		}
		let balanceAfter = await web3.eth.getBalance(passenger);
		let result = balanceAfter.sub(balanceBefore);
		// ASSERT
		assert.equal(result, amount, "Passenger should be able to withdraw insurance funds");
	
	});
});

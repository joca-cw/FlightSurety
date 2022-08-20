
const { debug } = require('webpack');
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

	const flight1 = 'ND1309'; // Course number
	const flight2 = 'EW2713'; // Course number
	const timestamp = Math.floor(Date.now() / 1000 + 3600);
	

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
			await config.flightSuretyApp.registerAirline(accounts[4]);
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
		let result = await config.flightSuretyApp.isAirlineRegistered.call(firstAirline);
		//result &= await config.flightSuretyApp.hasSubmittedFunding(firstAirline);

		// ASSERT
		assert.equal(result, true, "First airline not registered");
	});


	it('(airlines) cannot register an Airline using registerAirline() if it is not funded', async () => {
		
		// ARRANGE
		const newAirline = accounts[1];
		// ACT
		try {
			await config.flightSuretyApp.registerAirline(newAirline, { from: accounts[0]});
		}
		catch(e) {
			//console.log(e);
		}
		const result = await config.flightSuretyApp.isAirlineRegistered.call(newAirline); 

		// ASSERT
		assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

	});

	it('(airlines) can register an Airline using registerAirline() if it is funded', async () => {
		
		// ARRANGE
		const newAirline = accounts[1];
		
		// ACT
		try {
			await config.flightSuretyApp.submitFunding({from: accounts[0], value: web3.utils.toWei('10', 'ether')});
			await config.flightSuretyApp.registerAirline(newAirline);
		}
		catch(e) {
			console.log(e);
		}
		const result = await config.flightSuretyApp.isAirlineRegistered.call(newAirline); 

		// ASSERT
		assert.equal(result, true, "Airline should be able to register another airline if it has provided funding");

	});

	it('(airlines) cannot register 5th airline without multiparty consensus', async () => {
		
		// ARRANGE
		const newAirline2 = accounts[2];
		const newAirline3 = accounts[3];
		const newAirline = accounts[4];
		
		// ACT
		try {
			await config.flightSuretyApp.submitFunding({from: accounts[1], value: web3.utils.toWei('10', 'ether')});
			await config.flightSuretyApp.registerAirline(newAirline2);
			await config.flightSuretyApp.submitFunding({from: accounts[2], value: web3.utils.toWei('10', 'ether')});
			await config.flightSuretyApp.registerAirline(newAirline3);
			await config.flightSuretyApp.submitFunding({from: accounts[3], value: web3.utils.toWei('10', 'ether')});
			
			await config.flightSuretyApp.registerAirline(newAirline);
		}
		catch(e) {
			console.log(e);
		}
		const result = await config.flightSuretyApp.isAirlineRegistered.call(newAirline); 

		// ASSERT
		assert.equal(result, false, "Airline should not be able to register without multiparty consensus");

	});

	it('(airlines) 5th airline can be registered when there is multiparty consensus', async () => {
		
		// ARRANGE
		const newAirline = accounts[4];
		
		// ACT
		try {
			await config.flightSuretyApp.registerAirline(newAirline, { from: accounts[1] });
		}
		catch(e) {
			console.log(e);
		}
		const result = await config.flightSuretyApp.isAirlineRegistered.call(newAirline);

		// ASSERT
		assert.equal(result, true, "Airline should be able to register with multiparty consensus");

	});

	it('(airlines) can register flight', async () => {
		// ARRANGE
		const airline = accounts[1];

		// ACT
		try {
			await config.flightSuretyApp.registerFlight(airline, flight1, timestamp);
		}
		catch(e) {
			console.log(e);
		}

		const result = await config.flightSuretyApp.isFlightRegistered.call(airline, flight1, timestamp);
		// ASSERT
		assert.equal(result, true, "Flight should be registered");
	});

	// Passengers may pay up to 1 ether for purchasing flight insurance.
	it('(passenger) can buy insurance for a flight', async () => {
		// ARRANGE
		const passenger = accounts[9];
		const airline = accounts[1];

		const amount = web3.utils.toWei('1', 'ether');

		// ACT
		try {
			await config.flightSuretyApp.buyInsurance(airline, flight1, timestamp, {from: passenger, value: amount});
		}
		catch(e) {
			console.log(e);
		}
		const result = await config.flightSuretyApp.getInsuranceValue.call(passenger);
		const balance = await config.flightSuretyApp.getBalance.call(passenger);
		// console.log(balance.toString());
		
		// ASSERT
		assert.equal(result, web3.utils.toWei('1', 'ether'), "Passenger should be able to buy insurance for a flight");
	});

	it('(passenger) recieves insurance payout credit', async () => {
		// ARRANGE
		const passenger = accounts[9];
		const airline = accounts[1];

		const payoutAmount = web3.utils.toWei('1.5', 'ether');

		// Oracles
		const TEST_ORACLES_COUNT = 25;
		const STATUS_CODE_LATE_AIRLINE = 20;
		const fee = await config.flightSuretyApp.REGISTRATION_FEE.call();
		// Register oracles
		for(let a=15; a<15+TEST_ORACLES_COUNT; a++) {      
			await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
			let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
			//console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
		}

		// ACT
		// Submit a request for oracles to get status information for flight1
		await config.flightSuretyApp.fetchFlightStatus(airline, flight1, timestamp);

		for(let a=15; a<15+TEST_ORACLES_COUNT; a++) {
			// Get oracle information
			const oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
			for(let idx=0;idx<3;idx++) {
				try {
					// Submit a response...it will only be accepted if there is an Index match
					await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], airline, flight1, timestamp, STATUS_CODE_LATE_AIRLINE, { from: accounts[a] });
				}
				catch(e) {
					// Enable this when debugging
					// console.log('\nError', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
				}
	  		}
		}

		const balance = await config.flightSuretyApp.getBalance.call(passenger);

		// ASSERT
		assert.equal(balance.toString(), payoutAmount.toString(), "Passenger shlould be credited with insurance payout");
	});


	// Passenger can withdraw
	it('(passenger) can withdraw insurance funds', async () => {
		// ARRANGE
		const passenger = accounts[9];
		const withdrawAmount = web3.utils.toWei('1', 'ether');
		let tx;
		
		const balanceBefore = new BigNumber(await web3.eth.getBalance(passenger));
		// console.log(balanceBefore);
		// ACT
		try {
			tx = await config.flightSuretyApp.withdraw(withdrawAmount, {from: passenger});
			// console.log(tx);
		}
		catch(e) {
			console.log(e);
		}
		const gasUsed = tx.receipt.gasUsed;
		const gasPrice = (await web3.eth.getTransaction(tx.tx)).gasPrice;
		const gasFees = BigNumber(gasPrice).times(gasUsed);

		const balanceAfter = new BigNumber(await web3.eth.getBalance(passenger));
		const expectedBalance = balanceBefore.plus(withdrawAmount).minus(gasFees);
		// console.log(balanceAfter);
		// console.log(expectedBalance);
		// console.log(gasFees);

		// ASSERT
		assert.equal(balanceAfter.toString(), expectedBalance.toString(), "Passenger should be able to withdraw insurance funds");
	});
});

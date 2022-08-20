import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

import { Random } from "random-js";


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
const flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
const flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

let oracleList = [];
let flightList = [];


(async() => {
	const accounts = await web3.eth.getAccounts();
  	const oracles = accounts.splice(15, 39);
	const airlines = accounts.splice(1, 3);


	console.log("Authorizing App Contract...");
	try {
		await flightSuretyData.methods.authorizeContract(flightSuretyApp._address).send({from: accounts[0]});
	} catch(error) {
		console.log(`Error autorizing contract!\n${error}`);
	}

 
	// Register airlines and submit funding
	console.log("Registering airlines...");
	try {
		await flightSuretyApp.methods.submitFunding().send({
			from: accounts[0], 
			value: web3.utils.toWei('10', 'ether')});
	} catch(error) {
		console.log(`Error submitting funding!\n${error}`);
	}
	
	for(let i = 0; i < airlines.length; i++){
		try {
			await flightSuretyApp.methods.registerAirline(airlines[i]).send({from: accounts[0]});
			await flightSuretyApp.methods.submitFunding().send({
				from: accounts[0],
				value: web3.utils.toWei('10', 'ether')});
		} catch(error) {
			console.log(`Error registering airline!\n${error}`);
		}
	}
	
	// Register oracles
	console.log("Registering oracles...");
	const oracleFee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
	for(let i = 0; i < oracles.length; i++){
	  	try {
			await flightSuretyApp.methods.registerOracle().send({
				from: oracles[i],
				value: oracleFee,
				gasLimit: 1000000});
			const index = await flightSuretyApp.methods.getMyIndexes().call({from: oracles[i]});
			oracleList.push({
				address: oracles[i],
				index: index
			})
	  	} catch(error) {
			console.log(`Error registering oracle!\n${error}`);
		}
	}
})();


flightSuretyApp.events.OracleRequest({
	fromBlock: 0
}, (error, event) => {
	if(error) {
		console.log(error);
	} else {
		console.log(event);

		const statusCode = generateStatusCode();
		console.log(statusCode);
		const eventValue = event.returnValues;
		console.log(eventValue);
		console.log(`Event with index: ${eventValue.index}; airline: ${eventValue.airline}; flight: ${eventValue.flight}; timestamp ${eventValue.timestamp}`);

		oracleList.forEach(async oracle => {
			try {
				await flightSuretyApp.methods.submitOracleResponse(eventValue.index, eventValue.airline, eventValue.flight, eventValue.timestamp, statusCode).send({
					from: oracle.address,
					gasLimit: 10000000});
				console.log(`Oracle(${oracle.address}) accepted with status code ${statusCode}`);
			} catch(error) {
				console.log(`Oracle(${oracle.address}) rejected with status code ${statusCode}`);
				console.log(error);
			}
      	});
	}
});

function generateStatusCode() {
	const random = new Random(); 
	return (Math.ceil((random.integer(1, 50)) / 10) * 10);
}


const app = express();
app.get('/api', (req, res) => {
    res.send({
    	message: 'An API for use with your Dapp!'
    })
})

export default app;

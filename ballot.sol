pragma solidity ^0.4.25;

import "./SafeMath.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract Election {
    using SafeMath for uint;

    address owner; // Address of the contract owner
    bool public isVoting = false; // isVoting should be true when voting starts
    uint public round = 0; // round number should be increased when new election starts
    
    struct Candidate {
        uint vote;
        string name;
        bool isRegistered;
        uint candidateNumber;
    }
    address[] public candidatesList;
    mapping(uint => mapping(address => Candidate)) public candidateData;
    mapping(uint => mapping(address => bool)) public voted;
    
    /* Following will be needed for extra bonuse */
    uint public guaranteedDeposit = 0.1 ether;
    uint public refundRatio = 5; // In order to get refund, candidate's votes must be more than 1/5
    uint private _totalvote;

    /* 
        !IMPORTANT!
        Events should be fired at the correct moment otherwise DAPP wont work normally
    */
    event voteStart(uint round); // When vote starts
    event elected(uint round, address candidate, string name, uint vote); // When someone is elected
    event reset(uint round); // When ocntract owner resets the election
    event registered(uint round, address candidate); // When someone registered
    event voteCandidate(uint round, address candidate, address voter); // When someone voted
    
    /* events for extrea bonus */
    event sponsorCandidate(uint round, address candidate, string name, address sponsor, uint amount); // When someone sponsor a candidate
    event refund(address candidate, string name, uint amount, uint round); // When a candidates gets refunded

    constructor() public {
        owner = msg.sender;

    }
    
    modifier onlyOwner() {
        require(owner == msg.sender, "OnlyOwner");
        _;
    }
    modifier votable() {
        require(isVoting, "NotVotable");
        _;
    }
    modifier registerable() {
        require(!isVoting, "NotRegisterable");
        _;
    }

    /* Stop voting and start registration */
    function resetElection() public onlyOwner votable {
        isVoting = false;
        address winner;
        uint maxvote;
        uint gvote = _totalvote * 10 / refundRatio / 10;
        
        for (uint i = 0; i < candidatesList.length; i++) {
            if (candidateData[round][candidatesList[i]].vote > maxvote) {
                maxvote = candidateData[round][candidatesList[i]].vote;
                winner = candidatesList[i];
            }
            // refund 
            if (candidateData[round][candidatesList[i]].vote > gvote) {
                emit refund(candidatesList[i], candidateData[round][candidatesList[i]].name, guaranteedDeposit, round);
            }
        }
        emit elected(round, winner, candidateData[round][winner].name, candidateData[round][winner].vote);

        round = round.add(1);
        candidatesList.length = 0;
        _totalvote = 0;
        emit reset(round);
        
    }

    /* Stop registration and start voting */
    function startVoting() public onlyOwner {
        uint id;
        
        for (uint i = 1; i <= candidatesList.length; i++) {
            while (true) {
                id = rand % (candidatesList.length + 1) - 1;
                if (candidateData[round][candidatesList[id]].candidateNumber == 0) {
                    candidateData[round][candidatesList[id]].candidateNumber = i;
                    break;
                }
            }
        }

        isVoting = true;
        emit voteStart(round);
    }

    /* Vote a candidate */
    function vote(address candidateAddr) public votable {
        require(!voted[round][msg.sender], "AlreadyVoted");
        candidateData[round][candidateAddr].vote = candidateData[round][candidateAddr].vote.add(1);
        emit voteCandidate(round, candidateAddr, msg.sender);
    }

    /* register as a candidate */
    function register(string name) public payable registerable {
        require(!candidateData[round][msg.sender].isRegistered, "AlreadyRegistered");
        require(msg.value >= guaranteedDeposit, "LowerThanguaranteedDeposit");
        candidatesList.push(msg.sender);
        candidateData[round][msg.sender].name = name;
        candidateData[round][msg.sender].isRegistered = true;
        emit registered(round, msg.sender);
    }

    function getCandidatesList() public view returns ( address[]) {
        return candidatesList;
    }

    // Extra bonus
    /* sponsor a candidate */
    function sponsor(address candidateAddr) public payable {
        require(candidateData[round][candidateAddr].isRegistered, "CandidateNotRegister");
        candidateAddr.transfer(msg.value);
        emit sponsorCandidate(round, candidateAddr, candidateData[round][candidateAddr].name, msg.sender, msg.value);
    }

}
pragma solidity ^0.6.10;
pragma experimental "ABIEncoderV2";

import "./vendor/Ownable.sol";
import "./interfaces/iServiceInterface.sol";
import "./interfaces/iServiceMarketInterface.sol";

/**
 * @title iService Core Extension contract
 */
contract iServiceCoreEx is iServiceInterface, Ownable {
    // mapping the request id to Request
    mapping(bytes32 => Request) requests;
    
    // mapping the request id to Callback
    mapping(bytes32 => Callback) callbacks;

    // mapping the request id to Response
    mapping(bytes32 => Response) responses;

    // chain id
    string chainID;

    // global request count
    uint256 public requestCount;

    // address allowed to relay the interchain requests
    address relayer;

    // iService market used to query the service binding
    iServiceMarketInterface public iServiceMarket;
    
    // service request
    struct Request {
        bytes32 id; // request id
        string chainID; // chain id
        address contractAddress; // address of the contract initiating the request 
        string serviceName; // service name
        string provider; // service provider
        string input; // request input
        string serviceFeeCap; // service fee cap
        uint256 timeout; // request timeout
    }
 
    // request callback
    struct Callback {
        address contractAddress; // callback contract address
        bytes4 functionSelector; // callback function selector
    }

    // service response
    struct Response {
        string errMsg; // error message of the service invocation
        string output; // response output
        string icRequestID; // the interchain request id on Irita-Hub
    }

    /**
     * @dev Event triggered when the service invocation is initiated
     * @param _requestID Request id
     * @param _chainID Chain id
     * @param _contractAddress Contract address
     * @param _serviceName Service name
     * @param _provider Provider address
     * @param _input Request input
     * @param _timeout Request timeout
     * @return requestID Request id
     */
    event ServiceInvoked(
        bytes32 _requestID,
        string _chainID,
        address _contractAddress,
        string _serviceName,
        string _provider,
        string _input,
        string _serviceFeeCap,
        uint256 _timeout
    );

    /**
     * @dev Constructor
     * @param _chainID Chain ID
     * @param _iServiceMarket iService market contract address
     * @param _relayer Relayer address
     */
    constructor(string memory _chainID, address _iServiceMarket, address _relayer)
        public
        Ownable()
    {
        _setChainID(_chainID);
        _setIServiceMarket(_iServiceMarket);

        if (_relayer != address(0)) {
            relayer = _relayer;
        } else {
            relayer = owner();
        }
    }

    /**
     * @dev Make sure that the request is valid
     * @param _serviceName Service name
     * @param _input Request input
     * @param _timeout Request timeout
     */
    modifier checkRequest(
        string memory _serviceName,
        string memory _input,
        uint256 _timeout
    )
    {
        require(bytes(_serviceName).length > 0, "iServiceCoreEx: service name can not be empty");
        require(bytes(_input).length > 0, "iServiceCoreEx: request input can not be empty");
        require(_timeout > 0, "iServiceCoreEx: request timeout must be greater than 0");
        
        _;
    }

    /**
     * @dev Make sure that the request exists and has not been responded
     * @param _requestID Request id
     */
    modifier validRequest(bytes32 _requestID) {
        require(bytes(requests[_requestID].serviceName).length > 0, "iServiceCoreEx: request does not exist");
        require(bytes(responses[_requestID].icRequestID).length == 0, "iServiceCoreEx: request has been responded");
        
        _;
    }
    
    /** 
     * @dev Make sure that the sender is the relayer
     */
    modifier onlyRelayer() {
        require(msg.sender == relayer, "iServiceCoreEx: sender is not the relayer");
        _;
    }

    /**
     * @dev Initiate a service invocation
     * @param _serviceName Service name
     * @param _input Request input
     * @param _timeout Request timeout
     * @param _callbackAddress Callback contract address
     * @param _callbackFunction Callback function selector
     * @return requestID Request id
     */
    function callService(
        string calldata _serviceName,
        string calldata _input,
        uint256 _timeout,
        address _callbackAddress,
        bytes4 _callbackFunction
    )
        external
        override
        checkRequest(_serviceName, _input, _timeout)
        returns (bytes32 requestID)
    {
        Request memory req;

        req.chainID = chainID;
        req.contractAddress = msg.sender;
        req.serviceName = _serviceName;
        req.input = _input;
        req.timeout= _timeout;
        
        _populateRequest(req);
        requestID = _sendRequest(req);
        req.id = requestID;

        _saveRequestCallback(requestID, _callbackAddress, _callbackFunction);

        return requestID;
    }

    /**
     * @dev Set the response of the specified service request
     * @param _requestID Request id
     * @param _errMsg Error message of the service invocation
     * @param _output Response output
     * @param _icRequestID Request id on Irita-Hub
     * @return True on success, false otherwise
     */
    function setResponse(
        bytes32 _requestID,
        string calldata _errMsg,
        string calldata _output,
        string calldata _icRequestID
    )
        external
        override
        onlyRelayer
        validRequest(_requestID)
        returns (bool)
    {
        Response memory resp;

        resp.errMsg = _errMsg;
        resp.icRequestID = _icRequestID;

        if (bytes(_errMsg).length == 0) {
            resp.output = _output;
        }
        
        responses[_requestID] = resp;

        Callback memory cb = callbacks[_requestID];
        (bool success, ) = cb.contractAddress.call(abi.encodeWithSelector(cb.functionSelector, _requestID, resp.output));
        
        return success;
    }

    /**
     * @dev Retrieve the response of the given service request 
     * @param _requestID Request id
     * @return Response
     */
    function getResponse(
        bytes32 _requestID
    )
        public
        view
        returns (Response memory)
    {
        return responses[_requestID];
    }

    /**
     * @notice Set the relayer address
     * @param _address Relayer address
     */
    function setRelayer(
        address _address
    )
        external
        onlyOwner
    {
        require(_address != address(0), "iServiceCoreEx: relayer address can not be zero");
        relayer = _address;
    }

    /**
     * @notice Set the iService market
     * @param _address iService market contract address
     */
    function setIServiceMarket(
        address _address
    )
        external
        onlyOwner
    {
        _setIServiceMarket(_address);
    }

    /**
     * @notice Set the chain ID
     * @param _chainID Chain ID
     */
    function _setChainID(
        string memory _chainID
    )
        internal
    {
        require(bytes(_chainID).length > 0, "iServiceCoreEx: chain ID can not be empty");
        chainID = _chainID;
    }

    /**
     * @notice Set the iService market
     * @param _address iService market contract address
     */
    function _setIServiceMarket(
        address _address
    )
        internal
    {
        require(_address != address(0), "iServiceCoreEx: iService market address can not be zero");
        iServiceMarket = iServiceMarketInterface(_address);
    }

    /**
     * @notice Polulate the given request with the extra service market data 
     * @param _req Request
     */
    function _populateRequest(
        Request memory _req
    )
        internal
    {
        bool exist = iServiceMarket.serviceBindingExists(_req.serviceName);
        require(exist, "iServiceCoreEx: service does not exist in the service market");
        
        uint256 qos = iServiceMarket.getQoS(_req.serviceName);
        require(_req.timeout >= qos, "iServiceCoreEx: request timeout must be greater than or equal to the service QoS");
        
        string memory provider = iServiceMarket.getServiceProvider(_req.serviceName);
        string memory serviceFee = iServiceMarket.getServiceFee(_req.serviceName);
        
        _req.provider = provider;
        _req.serviceFeeCap = serviceFee;
    }
    
    /**
     * @notice Save the request callback
     * @param _requestID Request id
     * @param _callbackAddress Callback contract address
     * @param _callbackFunction Callback function selector
     */
    function _saveRequestCallback(
        bytes32 _requestID,
        address _callbackAddress,
        bytes4 _callbackFunction
    )
        internal
    {
        Callback memory cb;

        cb.contractAddress = _callbackAddress;
        cb.functionSelector = _callbackFunction;

        callbacks[_requestID] = cb;
    }

    /**
     * @notice Send the service request
     * @param _req Request
     */
    function _sendRequest(
        Request memory _req
    )
        internal
        returns (bytes32 requestID)
    {
        requestID = keccak256(abi.encodePacked(this, requestCount));
        
        _req.id = requestID;
        requests[requestID] = _req;
        requestCount += 1;
        
        emit ServiceInvoked(
            _req.id,
            _req.chainID,
            _req.contractAddress,
            _req.serviceName,
            _req.provider,
            _req.input,
            _req.serviceFeeCap,
            _req.timeout
        );
        
        return requestID;
    }
}

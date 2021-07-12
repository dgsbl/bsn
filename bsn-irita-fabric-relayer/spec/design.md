# Relayer 接口设计

## 基本接口

```go
// ChainI defines the basic chain interface
type ChainI interface {
    GetChainID() string // chain ID getter
}
```

## 应用链接口

```go
// InterchainEventI abstracts the event which is triggered for an interchain service invocation
type InterchainEventI interface {
    GetRequestID()    string // request ID getter
    GetServiceName()  string // service name getter
    GetInput()        string // request input getter
    GetTimeout()      uint64 // request timeout getter
}
```

```go
// ResponseI defines the response related interfaces
type ResponseI interface {
    GetErrMsg()      string // error msg getter
    GetOutput()      string // response output getter
    GetICRequestID() string // interchain request ID getter
}
```

```go
// IServiceBinding defines an iService binding interface
type IServiceBinding interface {
    GetServiceName() string // service name getter
    GetSchemas() string     // service schemas
    GetProvider() string    // service provider
    GetServiceFee() string  // service fee
    GetQoS() uint64         // quality of service, in terms of the minimum response time
}
```

```go
// IServiceMarketI defines the interface for the iService market on the application chain
type IServiceMarketI interface {
    // add a service binding to the iService market
    AddServiceBinding(serviceName, schemas, provider, serviceFee string, qos uint64) error

    // update the specified service binding
    UpdateServiceBinding(serviceName, provider, serviceFee string, qos uint64) error

    // get the service binding by the given service name from the iService market
    GetServiceBinding(serviceName string) (IServiceBinding, error)
}
```

```go
// AppChainI defines the interface to interact with the application chain
type AppChainI interface {
    ChainI

    // listen to the interchain events with an event handler
    InterchainEventListener(cb func(icEvent InterchainEventI)) error

    // send the response to the application chain
    SendResponse(requestID string, response ResponseI) error

    // iService market interface
    IServiceMarketI
}
```

## IRITA-HUB 链接口

```go
// InterchainRequestI is an interface for the interchain request
type InterchainRequestI interface {
    GetServiceName()   string // service name getter
    GetProvider()      string // provider getter
    GetInput()         string // request input getter
    GetTimeout()       uint64 // request timeout getter
    GetServiceFeeCap() string // service fee cap getter
}
```

```go
// IritaHubChainI defines the interface to interact with IRITA-HUB
type IritaHubChainI interface {
    ChainI

    // send the interchain request and handle the response with the given callback
    SendInterchainRequest(request InterchainRequestI, cb func(icRequestID string, response ResponseI)) error
}
```

## 接口适配器

### 跨链请求适配器

此适配器为 `InterchainRequestI` 的内置实现，用于将跨链事件适配到 IRITA-HUB 的跨链请求。

```go
// InterchainRequestAdaptor bridges the interchain event and Irita-Hub interchain request
type InterchainRequestAdaptor struct {
    ServiceName   string
    Provider      string
    Input         string
    Timeout       uint64
    ServiceFeeCap string
}
```

### 响应适配器

此适配器为 `ResponseI` 的内置实现，用于将 IRITA-HUB 的原生响应适配到应用链所需的形式。

```go
// ResponseAdaptor is the wrapped response struct of Irita-Hub
type ResponseAdaptor struct {
    StatusCode   int
    Result       string
    Output       string
    ICRequestID  string
}
```

## 链示例实现

### 应用链

```go
type IServiceRequestEvent struct {
    RequestID   string
    ServiceName string
    Provider    string
    Input       string
    Timeout     uint64
}

func (e IServiceRequestEvent) GetRequestID() string {
    return e.RequestID
}

func (e IServiceRequestEvent) GetServiceName() string {
    return e.ServiceName
}

func (e IServiceRequestEvent) GetInput() string {
    return e.Input
}

func (e IServiceRequestEvent) GetTimeout() uint64 {
    return e.Timeout
}

type ServiceBinding struct {
    ServiceName string 
    Schemas     string
    Provider    string
    ServiceFee  string
    QoS         uint64
}

func (b ServiceBinding) GetServiceName() string {
    return b.ServiceName
}

func (b ServiceBinding) GetSchemas() string {
    return b.Schemas
}

func (b ServiceBinding) GetProvider() string {
    return b.Provider
}

func (b ServiceBinding) GetServiceFee() string {
    return b.ServiceFee
}

func (b ServiceBinding) GetQoS() uint64 {
    return b.QoS
}
```

```go
type FabricChain struct {
    ChannelID      string
    ChainCodeID    string
    PeerRPCAddrs   []string
    OrdererRPCAddr string
    Client         interface{}
    Key            string
    Passphrase     string
}

func NewFabricChain(
    channelID string,
    chainCodeID string,
    peerRPCAddrs []string,
    ordererRPCAddr string,
    client interface{},
    key string,
    Passphrase string,
) FabricChain {
    return FabricChain{
        ChannelID:      channelID,
        ChainCodeID:    chainCodeID,
        PeerRPCAddrs:   peerRPCAddrs,
        OrdererRPCAddr: ordererRPCAddr,
        Client:         client,
        Key:            key,
        Passphrase:     passphrase,
    }
}

func (fc FabricChain) GetChainID() string {
    return fc.ChannelID
}

func (fc FabricChain) InterchainEventListener(cb func(icEvent InterchainEventI)) error {
    i := 0

    for {
        icEvent := InterchainEvent{
            RequestID: fmt.Sprintf("request%d", i+1),
            ServiceName:  "exchange_rate",
            Input:        fmt.Sprintf(`{"name":"CNY-USD"}`),
            Timeout:      uint64(50),
        }

        cb(icEvent)

        time.Sleep(10 * time.Second)
        i++
    }

    return nil
}

func (fc FabricChain) SendResponse(requestID string, response ResponseI) error {
    return nil
}

func (fc FabricChain) AddServiceBinding(serviceName, schemas, provider, serviceFee string, qos uint64) error {
    return nil
}

func (fc FabricChain) UpdateServiceBinding(serviceName, schemas, provider, serviceFee string, qos uint64) error {
    return nil
}

func (fc FabricChain) GetServiceBinding(serviceName string) (IServiceBinding, error) {
    return nil, nil
}
```

### IRITA-HUB

```go
type IritaHubChain struct {
    ChainID    string
    RPCAddr    string
    Client     interface{}
    Key        string
    Passphrase string
}

func NewIritaHubChain(chainID string, rpcAddr string, client interface{}, key string, passphrase string) IritaHubChain {
    return IritaHubChain{
        ChainID:    chainID,
        RPCAddr:    rpcAddr,
        Client:     client,
        Key:        key,
        Passphrase: passphrase,
        }
}

func (ic IritaHubChain) GetChainID() string {
    return ic.ChainID
}

func (ic IritaHubChain) SendInterchainRequest(request InterchainRequestI, cb func(icRequestID string, response ResponseI)) error {
    return nil
}
```

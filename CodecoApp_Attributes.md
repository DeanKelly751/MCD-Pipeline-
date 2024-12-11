# CODECO Spec Attributes

`CodecoApp Spec` defines the desired state of CodecoApp.

## CodecoApp

### AppName (String)
- Used to identify the CODECO application.
- **Optional**

### QosClass (String)
- Used to identify the CODECO application QoS.
- Possible values: `Gold`, `Silver`, `BestEffort`
- **Optional**

### Workloads
- Used to identify the CODECO microservices which compose the application.
- Defines the desired state of CodecoApp microservices.
- **Minimum 1 item required**

### SecurityClass (String)
- Used to identify the CODECO application security class.
- Possible values: `High`, `Good`, `Medium`, `Low`, `None`
- **Optional**

### ComplianceClass (String)
- Expected level of compliance, based on a scale.
- Possible values: `High`, `Medium`, `Low`
- **Optional**

### AppEnergyLimit (Integer)
- Maximum desired level of energy expenditure for the overall Kubernetes infrastructure associated with an application (percent).
- **Optional**

### FailureTolerance (String)
- Desired tolerance to infrastructure failures.
- Possible values: `High`, `Medium`, `Low`
- **Optional**

## Workloads

### BaseName (String)
- Used to identify the CODECO microservice.
- **Mandatory**

### Channels
- Service channels.
- **Optional**

### Templatev1.PodSpec
- A reference to the PodSpec of the microservice.
- **Optional**

### NWBandwidthMbs (String)
- Desired network bandwidth.
- **Optional**

### NWLatencyMs (String)
- Desired network latency.
- **Optional**

## Channels

### BaseName (String)
- Used as the name for the channel resource.
- **Optional**

### ServiceClass (String)
- A communication service class for this channel.
- Currently, two service classes are supported: `BESTEFFORT` and `ASSURED`.
- **Optional**

### OtherWorkload
- Identifies the target workload of the connection via its application name and workload basename.
- All fields **optional**:
  - **BaseName (String)**
  - **ApplicationName (String)**
  - **Port**: The port where the application listens for Channel data. This must match the `containerPort` on the relevant container.

### AdvancedChannelSettings
- All fields **optional**:

#### MinBandwidth (String)
- Specifies the traffic requirements for the Channel.
- Specified in bit/s, e.g., `5M` means 5 Mbit/s.
- If only the bandwidth is specified, the system will request a default framesize of 500 bytes for you.

#### MaxDelay (String)
- The maximum tolerated latency (end-to-end) on this channel in seconds.
- Examples: `1` means one second, `10e-3` means 10 milliseconds.

#### Framesize (String)
- Specifies the number of bytes sent in one go.
- Example: Specifying a framesize of `1K` and a send interval of `10e-3` (10ms) results in an effective bandwidth of 100kB/s or 800kbit/s.

#### SendInterval (String)
- Specifies the interval between two consecutive frames sent over this channel, in seconds.
- Examples: `10e-6` means 10 microseconds.
- The value should not exceed `10e-3` (10ms). The code will cap it at 10ms if a larger value is specified.

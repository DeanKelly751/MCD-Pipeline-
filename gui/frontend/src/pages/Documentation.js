import {useState} from 'react';
import {Tabs, Tab, TabTitleText, Title} from '@patternfly/react-core';


export const Documentation = () => {
  const [activeTabKey, setActiveTabKey] = useState(0);

  const handleTabClick = (event, tabIndex) => {
    setActiveTabKey(tabIndex);
  };


  return (
    <div>
      <Tabs
        activeKey={activeTabKey}
        onSelect={handleTabClick}
        isBox
        aria-label="Tabs in the box light variation example"
        role="region"
      >
        <Tab
          eventKey={0}
          title={<TabTitleText>CRD information</TabTitleText>}
          aria-label="Box light variation content - crd info"
        >
          <div>
          <Title headingLevel="h1">CRD Info...</Title>

          <Title headingLevel="h2">CODECO Spec Attributes</Title>
  <p><code>CodecoApp Spec</code> defines the desired state of CodecoApp.</p>

  <h2>CodecoApp</h2>

  <h3>AppName (String)</h3>
  <ul>
    <li>Used to identify the CODECO application.</li>
     <br/>
    <li><strong>QosClass (string): Optional</strong></li>
  </ul>

  <ul>
    <li>Used to identify the CODECO application QoS.</li>
    <li>Possible values:
    <li>Gold</li>
    <li>Silver</li>
    <li>Best Effort</li>
    </li>
  </ul>
  <br/>

  <p><strong>Workloads : Min. 1 item Required</strong></p>
  <ul>
    <li>Used to identify the CODECO microservices which compose the application.</li>
    <li>Defines the desired state of CodecoApp microservices.</li>
  </ul>
    <br/>

  <p><strong>Security Class: Optional</strong></p>
  <ul>
    <li>Used to identify the CODECO application security class.</li>
    <li>Possible values: <code>High</code>, <code>Good</code>, <code>Medium</code>, <code>Low</code>, <code>None</code></li>

  </ul>
<br/>
<p><strong>Complianceclass (string) : Optional</strong></p>
  <ul>
    <li>Expected level of compliance, based on a scale.</li>
    <li>Possible values: <code>High</code>, <code>Medium</code>, <code>Low</code></li>
  </ul>

  <h3>AppEnergyLimit (Integer)</h3>
  <ul>
    <li>Maximum desired level of energy expenditure for the overall Kubernetes infrastructure associated with an application (percent).</li>
    <li><strong>Optional</strong></li>
  </ul>
<br/>

<p><strong>Failure Tolerance: Optional</strong></p>
  <ul>
    <li>Desired tolerance to infrastructure failures.</li>
    <li>Possible values: <code>High</code>, <code>Medium</code>, <code>Low</code></li>
  </ul>
<br/>

  <h2>Workloads</h2>

  <h3>BaseName (String)</h3>
  <ul>
    <li>Used to identify the CODECO microservice.</li>
    <li><strong>Mandatory</strong></li>
  </ul>

  <h3>Channels</h3>
  <ul>
    <li>Service channels.</li>
    <li><strong>Optional</strong></li>
  </ul>

  <h3>Templatev1.PodSpec</h3>
  <ul>
    <li>A reference to the PodSpec of the microservice.</li>
    <li><strong>Optional</strong></li>
  </ul>

  <h3>NWBandwidthMbs (String)</h3>
  <ul>
    <li>Desired network bandwidth.</li>
    <li><strong>Optional</strong></li>
  </ul>

  <h3>NWLatencyMs (String)</h3>
  <ul>
    <li>Desired network latency.</li>
    <li><strong>Optional</strong></li>
  </ul>

  <h2>Channels</h2>

  <h3>BaseName (String)</h3>
  <ul>
    <li>Used as the name for the channel resource.</li>
    <li><strong>Optional</strong></li>
  </ul>

  <h3>ServiceClass (String)</h3>
  <ul>
    <li>A communication service class for this channel.</li>
    <li>Currently, two service classes are supported: <code>BESTEFFORT</code> and <code>ASSURED</code>.</li>
    <li><strong>Optional</strong></li>
  </ul>

  <h3>OtherWorkload</h3>
  <ul>
    <li>Identifies the target workload of the connection via its application name and workload basename.</li>
    <li>All fields <strong>optional</strong>:</li>
    <ul>
      <li><strong>BaseName (String)</strong></li>
      <li><strong>ApplicationName (String)</strong></li>
      <li><strong>Port</strong>: The port where the application listens for Channel data. This must match the <code>containerPort</code> on the relevant container.</li>
    </ul>
  </ul>

  <h3>AdvancedChannelSettings</h3>
  <ul>
    <li>All fields <strong>optional</strong>:</li>
  </ul>

  <h4>MinBandwidth (String)</h4>
  <ul>
    <li>Specifies the traffic requirements for the Channel.</li>
    <li>Specified in bit/s, e.g., <code>5M</code> means 5 Mbit/s.</li>
    <li>If only the bandwidth is specified, the system will request a default framesize of 500 bytes for you.</li>
  </ul>

  <h4>MaxDelay (String)</h4>
  <ul>
    <li>The maximum tolerated latency (end-to-end) on this channel in seconds.</li>
    <li>Examples: <code>1</code> means one second, <code>10e-3</code> means 10 milliseconds.</li>
  </ul>

  <h4>Framesize (String)</h4>
  <ul>
    <li>Specifies the number of bytes sent in one go.</li>
    <li>Example: Specifying a framesize of <code>1K</code> and a send interval of <code>10e-3</code> (10ms) results in an effective bandwidth of 100kB/s or 800kbit/s.</li>
  </ul>

  <h4>SendInterval (String)</h4>
  <ul>
    <li>Specifies the interval between two consecutive frames sent over this channel, in seconds.</li>
    <li>Examples: <code>10e-6</code> means 10 microseconds.</li>
    <li>The value should not exceed <code>10e-3</code> (10ms). The code will cap it at 10ms if a larger value is specified.</li>
  </ul>

          </div>
        </Tab>
        <Tab eventKey={1} title={<TabTitleText>Set up Guide</TabTitleText>}>
          <div>
            <h1>Set Up</h1>
            <p>CODECO Readme</p>
          </div>
        </Tab>
        <Tab eventKey={2} title={<TabTitleText>AOB</TabTitleText>}>
          <div>
            <h1>Aob</h1>
            <p>Any other useful docs.</p>
          </div>
        </Tab>
      </Tabs>
      <div
        style={{
          marginTop: '20px',
        }}
      >

      </div>
    </div>
  );
};

export default Documentation;
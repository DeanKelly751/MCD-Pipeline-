import React, { useState, useEffect } from 'react';
import {
  Card,
  CardBody,
  CardTitle,
  Grid,
  GridItem,
  PageSection,
  Title,
  Text,
  Spinner,
  Label,
  Progress,
  List,
  ListItem,
  Flex,
  FlexItem,
  DataList,
  DataListItem,
  DataListItemRow,
  DataListItemCells,
  DataListCell,
  Alert,
  Chip,
  ChipGroup,
  Badge
} from '@patternfly/react-core';
import {
  CheckCircleIcon,
  ExclamationCircleIcon,
  TimesCircleIcon,
  InfoCircleIcon,
  ClusterIcon,
  CubeIcon,
  NetworkIcon
} from '@patternfly/react-icons';
import axios from 'axios';
import config from '../../config';

const MonitoringDashboard = () => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [refreshing, setRefreshing] = useState(false);
  const [data, setData] = useState({
    namespaces: [],
    pods: [],
    services: [],
    deployments: [],
    nodes: [],
    codecoApps: []
  });

  const fetchMonitoringData = async (showRefreshing = false) => {
    if (showRefreshing) setRefreshing(true);
    try {
      const [namespacesRes, podsRes, servicesRes, deploymentsRes, nodesRes, codecoAppsRes] = await Promise.allSettled([
        axios.get(`${config.apiUrl}/api/namespaces`),
        axios.get(`${config.apiUrl}/api/pods`),
        axios.get(`${config.apiUrl}/api/services`),
        axios.get(`${config.apiUrl}/api/deployments`),
        axios.get(`${config.apiUrl}/api/nodes`),
        axios.get(`${config.apiUrl}/crds/microservices`)
      ]);

      setData({
        namespaces: namespacesRes.status === 'fulfilled' ? namespacesRes.value.data : [],
        pods: podsRes.status === 'fulfilled' ? podsRes.value.data : [],
        services: servicesRes.status === 'fulfilled' ? servicesRes.value.data : [],
        deployments: deploymentsRes.status === 'fulfilled' ? deploymentsRes.value.data : [],
        nodes: nodesRes.status === 'fulfilled' ? nodesRes.value.data : [],
        codecoApps: codecoAppsRes.status === 'fulfilled' ? codecoAppsRes.value.data : []
      });
      setError(null);
    } catch (err) {
      setError('Failed to fetch monitoring data');
      console.error('Monitoring data fetch error:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchMonitoringData();
    
    // Auto-refresh every 30 seconds
    const interval = setInterval(() => {
      fetchMonitoringData(true);
    }, 30000);

    return () => clearInterval(interval);
  }, []);

  const getStatusIcon = (status) => {
    switch (status?.toLowerCase()) {
      case 'running':
      case 'ready':
      case 'active':
      case 'available':
        return <CheckCircleIcon style={{ color: 'var(--pf-global--success-color--100)' }} />;
      case 'pending':
      case 'terminating':
        return <InfoCircleIcon style={{ color: 'var(--pf-global--warning-color--100)' }} />;
      case 'failed':
      case 'error':
      case 'crashloopbackoff':
        return <TimesCircleIcon style={{ color: 'var(--pf-global--danger-color--100)' }} />;
      case 'unknown':
        return <ExclamationCircleIcon style={{ color: 'var(--pf-global--warning-color--100)' }} />;
      default:
        return <InfoCircleIcon style={{ color: 'var(--pf-global--info-color--100)' }} />;
    }
  };

  const getStatusColor = (status) => {
    switch (status?.toLowerCase()) {
      case 'running':
      case 'ready':
      case 'active':
      case 'available':
        return 'green';
      case 'pending':
      case 'terminating':
        return 'orange';
      case 'failed':
      case 'error':
      case 'crashloopbackoff':
        return 'red';
      default:
        return 'grey';
    }
  };

  const getPodStatus = (pod) => {
    if (pod.status?.phase) {
      return pod.status.phase;
    }
    if (pod.status?.containerStatuses?.length > 0) {
      const container = pod.status.containerStatuses[0];
      if (container.state?.running) return 'Running';
      if (container.state?.waiting) return container.state.waiting.reason || 'Waiting';
      if (container.state?.terminated) return container.state.terminated.reason || 'Terminated';
    }
    return 'Unknown';
  };

  const getHealthyCount = (items, getStatusFn) => {
    if (!items || items.length === 0) return { healthy: 0, total: 0 };
    const total = items.length;
    const healthy = items.filter(item => {
      const status = getStatusFn(item);
      return ['running', 'ready', 'active', 'available'].includes(status?.toLowerCase());
    }).length;
    return { healthy, total };
  };

  if (loading) {
    return (
      <PageSection>
        <Flex justifyContent={{ default: 'justifyContentCenter' }}>
          <FlexItem>
            <Spinner size="lg" />
            <Text style={{ marginTop: '1rem' }}>Loading monitoring data...</Text>
          </FlexItem>
        </Flex>
      </PageSection>
    );
  }

  const podHealth = getHealthyCount(data.pods, getPodStatus);
  const namespaceCount = data.namespaces.length;
  const serviceCount = data.services.length;
  const codecoAppCount = data.codecoApps.length;

  return (
    <PageSection>
      <Flex direction={{ default: 'column' }} spaceItems={{ default: 'spaceItemsLg' }}>
        <FlexItem>
          <Flex justifyContent={{ default: 'justifyContentSpaceBetween' }} alignItems={{ default: 'alignItemsCenter' }}>
            <FlexItem>
              <Title headingLevel="h1" size="2xl">
                <ClusterIcon style={{ marginRight: '0.5rem' }} />
                Cluster Monitoring Dashboard
              </Title>
              <Text component="p" style={{ marginTop: '0.5rem', color: 'var(--pf-global--Color--200)' }}>
                Real-time monitoring of Kubernetes cluster resources and services
              </Text>
            </FlexItem>
            <FlexItem>
              {refreshing && <Spinner size="md" />}
            </FlexItem>
          </Flex>
        </FlexItem>

        {error && (
          <FlexItem>
            <Alert variant="danger" title="Error fetching monitoring data">
              {error}
            </Alert>
          </FlexItem>
        )}

        {/* Overview Cards */}
        <FlexItem>
          <Grid hasGutter span={12}>
            <GridItem xl={3} lg={6} md={6} sm={12}>
              <Card isClickable isSelectableRaised>
                <CardTitle>
                  <Flex alignItems={{ default: 'alignItemsCenter' }}>
                    <FlexItem>
                      <CubeIcon style={{ color: 'var(--pf-global--primary-color--100)', marginRight: '0.5rem' }} />
                      Pods Health
                    </FlexItem>
                  </Flex>
                </CardTitle>
                <CardBody>
                  <Flex direction={{ default: 'column' }} spaceItems={{ default: 'spaceItemsSm' }}>
                    <FlexItem>
                      <Text component="p" style={{ fontSize: '2rem', fontWeight: 'bold' }}>
                        {podHealth.healthy}/{podHealth.total}
                      </Text>
                    </FlexItem>
                    <FlexItem>
                      <Progress 
                        value={podHealth.total > 0 ? (podHealth.healthy / podHealth.total) * 100 : 0} 
                        title="Pod Health"
                        variant={podHealth.healthy === podHealth.total ? 'success' : 'warning'}
                      />
                    </FlexItem>
                  </Flex>
                </CardBody>
              </Card>
            </GridItem>

            <GridItem xl={3} lg={6} md={6} sm={12}>
              <Card isClickable isSelectableRaised>
                <CardTitle>
                  <NetworkIcon style={{ color: 'var(--pf-global--info-color--100)', marginRight: '0.5rem' }} />
                  Namespaces
                </CardTitle>
                <CardBody>
                  <Text component="p" style={{ fontSize: '2rem', fontWeight: 'bold' }}>
                    {namespaceCount}
                  </Text>
                  <Text component="small">Active namespaces</Text>
                </CardBody>
              </Card>
            </GridItem>

            <GridItem xl={3} lg={6} md={6} sm={12}>
              <Card isClickable isSelectableRaised>
                <CardTitle>Services</CardTitle>
                <CardBody>
                  <Text component="p" style={{ fontSize: '2rem', fontWeight: 'bold' }}>
                    {serviceCount}
                  </Text>
                  <Text component="small">Running services</Text>
                </CardBody>
              </Card>
            </GridItem>

            <GridItem xl={3} lg={6} md={6} sm={12}>
              <Card isClickable isSelectableRaised>
                <CardTitle>CodecoApps</CardTitle>
                <CardBody>
                  <Text component="p" style={{ fontSize: '2rem', fontWeight: 'bold' }}>
                    {codecoAppCount}
                  </Text>
                  <Text component="small">Custom resources</Text>
                </CardBody>
              </Card>
            </GridItem>
          </Grid>
        </FlexItem>

        {/* Pods Status */}
        <FlexItem>
          <Card>
            <CardTitle>Pod Status</CardTitle>
            <CardBody>
              {data.pods.length > 0 ? (
                <DataList aria-label="Pod list" isCompact>
                  {data.pods.slice(0, 10).map((pod, index) => {
                    const status = getPodStatus(pod);
                    return (
                      <DataListItem key={pod.metadata?.uid || index}>
                        <DataListItemRow>
                          <DataListItemCells
                            dataListCells={[
                              <DataListCell key="status-icon">
                                {getStatusIcon(status)}
                              </DataListCell>,
                              <DataListCell key="name" width={3}>
                                <Text component="p" style={{ fontWeight: 'bold' }}>
                                  {pod.metadata?.name || 'Unknown'}
                                </Text>
                                <Text component="small" style={{ color: 'var(--pf-global--Color--200)' }}>
                                  {pod.metadata?.namespace || 'default'}
                                </Text>
                              </DataListCell>,
                              <DataListCell key="status" width={2}>
                                <Label color={getStatusColor(status)}>
                                  {status}
                                </Label>
                              </DataListCell>,
                              <DataListCell key="node" width={2}>
                                <Text component="small">
                                  Node: {pod.spec?.nodeName || 'Not assigned'}
                                </Text>
                              </DataListCell>,
                              <DataListCell key="restarts">
                                <Badge isRead>
                                  {pod.status?.containerStatuses?.[0]?.restartCount || 0} restarts
                                </Badge>
                              </DataListCell>
                            ]}
                          />
                        </DataListItemRow>
                      </DataListItem>
                    );
                  })}
                </DataList>
              ) : (
                <Text>No pods found</Text>
              )}
            </CardBody>
          </Card>
        </FlexItem>

        {/* Namespaces */}
        <FlexItem>
          <Grid hasGutter span={12}>
            <GridItem lg={6} md={12}>
              <Card>
                <CardTitle>Namespaces</CardTitle>
                <CardBody>
                  {data.namespaces.length > 0 ? (
                    <ChipGroup>
                      {data.namespaces.map((ns) => (
                        <Chip key={ns.uid} isReadOnly>
                          {ns.name}
                        </Chip>
                      ))}
                    </ChipGroup>
                  ) : (
                    <Text>No namespaces found</Text>
                  )}
                </CardBody>
              </Card>
            </GridItem>

            <GridItem lg={6} md={12}>
              <Card>
                <CardTitle>CodecoApp Resources</CardTitle>
                <CardBody>
                  {data.codecoApps && data.codecoApps.length > 0 ? (
                    <List isPlain>
                      {data.codecoApps.slice(0, 5).map((app, index) => (
                        <ListItem key={app.metadata?.uid || index}>
                          <Flex alignItems={{ default: 'alignItemsCenter' }}>
                            <FlexItem spacer={{ default: 'spacerSm' }}>
                              {getStatusIcon(app.status?.phase || 'unknown')}
                            </FlexItem>
                            <FlexItem>
                              <Text component="p">{app.metadata?.name || 'Unknown'}</Text>
                              <Text component="small" style={{ color: 'var(--pf-global--Color--200)' }}>
                                {app.metadata?.namespace || 'default'}
                              </Text>
                            </FlexItem>
                          </Flex>
                        </ListItem>
                      ))}
                    </List>
                  ) : (
                    <Text>No CodecoApp resources found</Text>
                  )}
                </CardBody>
              </Card>
            </GridItem>
          </Grid>
        </FlexItem>
      </Flex>
    </PageSection>
  );
};

export default MonitoringDashboard; 
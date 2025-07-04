import React from 'react';
import {
    Title,
    Card,
    CardBody,
    Gallery,
    GalleryItem,
    Alert,
    Button,
    ButtonVariant
} from '@patternfly/react-core';
import { ExternalLinkAltIcon } from '@patternfly/react-icons';

const MetricsLanding = () => {
    return (
        <div>
            <Title headingLevel="h1" size="2xl">
                Metrics & Monitoring
            </Title>
            
            <Alert 
                variant="info" 
                title="Metrics Integration Coming Soon" 
                isInline
                style={{ marginBottom: '20px' }}
            >
                This section will provide comprehensive metrics and monitoring capabilities for CODECO applications.
            </Alert>

            <Gallery hasGutter>
                <GalleryItem>
                    <Card>
                        <CardBody>
                            <Title headingLevel="h3" size="lg">
                                Application Metrics
                            </Title>
                            <p>
                                Monitor CPU, memory, and network usage for your deployed applications.
                            </p>
                            <Button 
                                variant={ButtonVariant.secondary} 
                                isDisabled
                                style={{ marginTop: '10px' }}
                            >
                                Coming Soon
                            </Button>
                        </CardBody>
                    </Card>
                </GalleryItem>

                <GalleryItem>
                    <Card>
                        <CardBody>
                            <Title headingLevel="h3" size="lg">
                                Cluster Health
                            </Title>
                            <p>
                                View overall cluster health, node status, and resource utilization.
                            </p>
                            <Button 
                                variant={ButtonVariant.secondary} 
                                isDisabled
                                style={{ marginTop: '10px' }}
                            >
                                Coming Soon
                            </Button>
                        </CardBody>
                    </Card>
                </GalleryItem>

                <GalleryItem>
                    <Card>
                        <CardBody>
                            <Title headingLevel="h3" size="lg">
                                Performance Analytics
                            </Title>
                            <p>
                                Analyze application performance trends and identify optimization opportunities.
                            </p>
                            <Button 
                                variant={ButtonVariant.secondary} 
                                isDisabled
                                style={{ marginTop: '10px' }}
                            >
                                Coming Soon
                            </Button>
                        </CardBody>
                    </Card>
                </GalleryItem>

                <GalleryItem>
                    <Card>
                        <CardBody>
                            <Title headingLevel="h3" size="lg">
                                External Monitoring
                            </Title>
                            <p>
                                Access external monitoring tools like Prometheus and Grafana.
                            </p>
                            <Button 
                                variant={ButtonVariant.link} 
                                icon={<ExternalLinkAltIcon />}
                                iconPosition="right"
                                component="a"
                                href="#"
                                isDisabled
                                style={{ marginTop: '10px' }}
                            >
                                Open Prometheus
                            </Button>
                            <br />
                            <Button 
                                variant={ButtonVariant.link} 
                                icon={<ExternalLinkAltIcon />}
                                iconPosition="right"
                                component="a"
                                href="#"
                                isDisabled
                                style={{ marginTop: '5px' }}
                            >
                                Open Grafana
                            </Button>
                        </CardBody>
                    </Card>
                </GalleryItem>
            </Gallery>
        </div>
    );
};

export default MetricsLanding; 
import React, { useState } from 'react';
import yaml from 'js-yaml';
import axios from 'axios';
import config from '../../config';
import {
    Button,
    ButtonVariant,
    CodeBlock,
    CodeBlockCode,
    ClipboardCopyButton,
    Title,
    Form,
    FormFieldGroup,
    FormGroup,
    TextInput,
    Panel,
    Alert
} from '@patternfly/react-core';
import CopyIcon from '@patternfly/react-icons/dist/esm/icons/download-icon';
import { useLocation } from 'react-router-dom';

function YamlGenerator() {
    const location = useLocation();

    const [cam, setCam] = useState(location.state || {
        apiVersion: 'codeco.he-codeco.eu/v1alpha1',
        kind: 'CodecoApp'
    });
    // const [cam, setCam] = useState({
    //     apiVersion: 'codeco.he-codeco.eu/v1alpha1',
    //     kind: 'CodecoApp',

    //     spec: {
    //         appEnergyLimit: '',
    //         appFailureTolerance: '',
    //         appName: '',
    //         complianceClass: '',
    //         qosClass: '',
    //         securityClass: '',
    //         codecoappmsspec: [
    //             {
    //                 nwbandwidth: '',
    //                 nwlatency: '',
    //                 podspec: {
    //                     containers: [
    //                         {
    //                             image: '',
    //                             name: '',
    //                             ports: [{ containerPort: '', name: '', protocol: '' }],
    //                             resources: { limits: { cpu: '', memory: '' } },
    //                         },
    //                     ],
    //                 },
    //                 serviceChannels: [
    //                     {
    //                         advancedChannelSettings: {
    //                             minBandwidth: '',
    //                             frameSize: '',
    //                             maxDelay: '',
    //                             sendInterval: '',
    //                         },
    //                         channelName: '',
    //                     },
    //                 ],
    //             },
    //         ],
    //         otherService: { appName: '', port: '', serviceName: '' },
    //     },
    // });

    const [copied, setCopied] = useState(false);
    const [response, setResponse] = useState(null);
    const [error, setError] = useState(null);

    // Generic handler for updating nested fields
    const handleInputChange = (path, value, index = null, subIndex = null) => {
        setCam((prev) => {
            const newCam = JSON.parse(JSON.stringify(prev)); // Deep copy
            let current = newCam;

            // Navigate to the parent of the target field
            const keys = path.split('.');
            for (let i = 0; i < keys.length - 1; i++) {
                current = current[keys[i]] = current[keys[i]] || {};
            }

            // Set the value at the target field
            const lastKey = keys[keys.length - 1];
            if (index !== null && subIndex !== null) {
                current[lastKey][index][lastKey][subIndex][lastKey] = value;
            } else if (index !== null) {
                current[lastKey][index][lastKey] = value;
            } else {
                current[lastKey] = value;
            }

            return newCam;
        });
    };

    const download = (file, text) => {
        //creating an invisible element
        let element = document.createElement('a');
        element.setAttribute('href',
            'data:text/plain;charset=utf-8,'
            + encodeURIComponent(text));
        element.setAttribute('download', file);
        document.body.appendChild(element);
        element.click();

        document.body.removeChild(element);
    }

    const downloadFunction = () => {
        const filename = `${cam.metadata?.name || "CodecoApp"}-${new Date().toISOString().split('T')[0]}.yaml`;

        download(filename, yaml.dump(cam, { skipInvalid: true }));
    }


    // Add a new codecoappmsspec entry
    const addMSSpec = () => {
        setCam((prev) => ({
            ...prev,
            spec: {
                ...prev.spec,
                codecoappmsspec: [
                    ...(prev.spec?.codecoappmsspec || []),
                    {
                        nwbandwidth: '',
                        nwlatency: '',
                        podspec: {
                            containers: [
                                {
                                    image: '',
                                    name: '',
                                    ports: [{ containerPort: '', name: '', protocol: '' }],
                                    resources: { limits: { cpu: '', memory: '' } },
                                },
                            ],
                        },
                        serviceChannels: [
                            {
                                advancedChannelSettings: {
                                    minBandwidth: '',
                                    frameSize: '',
                                    maxDelay: '',
                                    sendInterval: '',
                                },
                                channelName: '',
                            },
                        ],
                    },
                ],
            },
        }));
    };

    // Remove a codecoappmsspec entry
    const removeMSSpec = (index) => {
        setCam((prev) => ({
            ...prev,
            spec: {
                ...prev.spec,
                codecoappmsspec: prev.spec.codecoappmsspec.filter((_, i) => i !== index),
            },
        }));
    };

    // Handle applying the YAML to the cluster
    const handleApply = async () => {
        try {
            const yamlString = yaml.dump(cam, { skipInvalid: true });
            const res = await axios.post(`${config.apiUrl}${config.endpoints.applyYaml}`, { yaml: yamlString });
            setResponse(res.data);
            setError(null);
        } catch (err) {
            setError(err.response?.data?.error || 'Failed to apply YAML');
            setResponse(null);
            console.error('Error applying YAML:', err);
        }
    };

    return (
        <Form>
            <Title headingLevel="h1">YAML Generator</Title>

            {/* Display response or error */}
            {response && (
                <Alert variant="success" title="Success" isInline>
                    YAML applied successfully: {JSON.stringify(response.message)}
                </Alert>
            )}
            {error && (
                <Alert variant="danger" title="Error" isInline>
                    {error}
                </Alert>
            )}

            {/* Metadata Inputs */}
            <FormFieldGroup>
                <Title headingLevel="h2">Metadata</Title>
                <FormGroup label="Name">
                    <TextInput
                        value={cam.metadata?.name}
                        onChange={(e) => handleInputChange('metadata.name', e.target.value)}
                    />
                </FormGroup>

                <FormGroup label="Namespace">
                    <TextInput
                        value={cam.metadata?.namespace}
                        onChange={(e) => handleInputChange('metadata.namespace', e.target.value)}
                    />
                </FormGroup>
            </FormFieldGroup>

            {/* Spec Inputs */}
            <FormFieldGroup>
                <Title headingLevel="h2">Spec</Title>
                <FormGroup label="App Energy Limit">
                    <TextInput
                        value={cam.spec?.appEnergyLimit}
                        onChange={(e) => handleInputChange('spec.appEnergyLimit', e.target.value)}
                    />
                </FormGroup>
                <FormGroup label="App Failure Tolerance">
                    <TextInput
                        value={cam.spec?.appFailureTolerance}
                        onChange={(e) => handleInputChange('spec.appFailureTolerance', e.target.value)}
                    />
                </FormGroup>
                <FormGroup label="App Name">
                    <TextInput
                        value={cam.spec?.appName}
                        onChange={(e) => handleInputChange('spec.appName', e.target.value)}
                    />
                </FormGroup>
                <FormGroup label="Compliance Class">
                    <TextInput
                        value={cam.spec?.complianceClass}
                        onChange={(e) => handleInputChange('spec.complianceClass', e.target.value)}
                    />
                </FormGroup>
                <FormGroup label="QoS Class">
                    <TextInput
                        value={cam.spec?.qosClass}
                        onChange={(e) => handleInputChange('spec.qosClass', e.target.value)}
                    />
                </FormGroup>
                <FormGroup label="Security Class">
                    <TextInput
                        value={cam.spec?.securityClass}
                        onChange={(e) => handleInputChange('spec.securityClass', e.target.value)}
                    />
                </FormGroup>
            </FormFieldGroup>

            {/* CodecoApp MSSpec */}
            <FormFieldGroup>
                <Title headingLevel="h2">CodecoApp MSSpec</Title>
                {cam.spec?.codecoappmsspec?.map((msSpec, index) => (
                    <Panel key={index} variant="secondary">
                        <Button
                            variant={ButtonVariant.link}
                            onClick={() => removeMSSpec(index)}
                        >
                            Delete
                        </Button>
                        <FormGroup label="NW Bandwidth">
                            <TextInput
                                value={msSpec?.nwbandwidth}
                                onChange={(e) =>
                                    handleInputChange(`spec.codecoappmsspec.${index}.nwbandwidth`, e.target.value)
                                }
                            />
                        </FormGroup>
                        <FormGroup label="NW Latency">
                            <TextInput
                                type="number"
                                value={msSpec?.nwlatency}
                                onChange={(e) =>
                                    handleInputChange(`spec.codecoappmsspec.${index}.nwlatency`, e.target.value)
                                }
                            />
                        </FormGroup>

                        {/* PodSpec */}
                        <Title headingLevel="h3">PodSpec</Title>
                        <FormGroup label="Container Image">
                            <TextInput
                                value={msSpec?.podspec?.containers[0]?.image}
                                onChange={(e) =>
                                    handleInputChange(
                                        `spec.codecoappmsspec.${index}.podspec.containers.0.image`,
                                        e.target.value
                                    )
                                }
                            />
                        </FormGroup>
                        <FormGroup label="Container Name">
                            <TextInput
                                value={msSpec?.podspec?.containers[0]?.name}
                                onChange={(e) =>
                                    handleInputChange(
                                        `spec.codecoappmsspec.${index}.podspec.containers.0.name`,
                                        e.target.value
                                    )
                                }
                            />
                        </FormGroup>

                        {/* Ports */}
                        <Title headingLevel="h3">Ports</Title>
                        <FormGroup label="Container Port">
                            <TextInput
                                type="number"
                                value={msSpec?.podspec?.containers[0]?.ports[0]?.containerPort}
                                onChange={(e) =>
                                    handleInputChange(
                                        `spec.codecoappmsspec.${index}.podspec.containers.0.ports.0.containerPort`,
                                        e.target.value
                                    )
                                }
                            />
                        </FormGroup>
                        <FormGroup label="Port Name">
                            <TextInput
                                value={msSpec?.podspec?.containers[0]?.ports[0]?.name}
                                onChange={(e) =>
                                    handleInputChange(
                                        `spec.codecoappmsspec.${index}.podspec.containers.0.ports.0.name`,
                                        e.target.value
                                    )
                                }
                            />
                        </FormGroup>
                        <FormGroup label="Protocol">
                            <TextInput
                                value={msSpec?.podspec?.containers[0]?.ports[0]?.protocol}
                                onChange={(e) =>
                                    handleInputChange(
                                        `spec.codecoappmsspec.${index}.podspec.containers.0.ports.0.protocol`,
                                        e.target.value
                                    )
                                }
                            />
                        </FormGroup>

                        {/* Resources */}
                        <Title headingLevel="h3">Resources</Title>
                        <FormGroup label="CPU Limit">
                            <TextInput
                                value={msSpec.podspec?.containers[0]?.resources?.limits?.cpu}
                                onChange={(e) =>
                                    handleInputChange(
                                        `spec.codecoappmsspec.${index}.podspec.containers.0.resources.limits.cpu`,
                                        e.target.value
                                    )
                                }
                            />
                        </FormGroup>
                        <FormGroup label="Memory Limit">
                            <TextInput
                                value={msSpec.podspec?.containers[0]?.resources?.limits?.memory}
                                onChange={(e) =>
                                    handleInputChange(
                                        `spec.codecoappmsspec.${index}.podspec.containers.0.resources.limits.memory`,
                                        e.target.value
                                    )
                                }
                            />
                        </FormGroup>

                        {/* Service Channels */}
                        <Title headingLevel="h3">Service Channels</Title>
                        <FormGroup label="Channel Name">
                            <TextInput
                                value={msSpec?.serviceChannels?.[0]?.channelName}
                                onChange={(e) =>
                                    handleInputChange(
                                        `spec.codecoappmsspec.${index}.serviceChannels.0.channelName`,
                                        e.target.value
                                    )
                                }
                            />
                        </FormGroup>
                        <FormGroup label="Min Bandwidth">
                            <TextInput
                                value={msSpec?.serviceChannels?.[0]?.advancedChannelSettings?.minBandwidth}
                                onChange={(e) =>
                                    handleInputChange(
                                        `spec.codecoappmsspec.${index}.serviceChannels.0.advancedChannelSettings.minBandwidth`,
                                        e.target.value
                                    )
                                }
                            />
                        </FormGroup>
                    </Panel>
                ))}
                <Button variant={ButtonVariant.link} onClick={addMSSpec}>
                    Add codecoappmsspec
                </Button>
            </FormFieldGroup>

            {/* Other Service Inputs */}
            <FormFieldGroup>
                <Title headingLevel="h2">Other Services</Title>
                <FormGroup label="App Name">
                    <TextInput
                        value={cam.spec?.otherService?.appName}
                        onChange={(e) => handleInputChange('spec.otherService.appName', e.target.value)}
                    />
                </FormGroup>
                <FormGroup label="Port">
                    <TextInput
                        type="number"
                        value={cam.spec?.otherService?.port}
                        onChange={(e) => handleInputChange('spec.otherService.port', e.target.value)}
                    />
                </FormGroup>
                <FormGroup label="Service Name">
                    <TextInput
                        value={cam.spec?.otherService?.serviceName}
                        onChange={(e) => handleInputChange('spec.otherService.serviceName', e.target.value)}
                    />
                </FormGroup>
            </FormFieldGroup>

            {/* YAML Preview */}
            <CodeBlock
                actions={
                    <>
                        <ClipboardCopyButton
                            id="basic-copy-button"
                            textId="code-content"
                            aria-label="Copy to clipboard"
                            onClick={() => {
                                setCopied(true);
                                navigator.clipboard.writeText(yaml.dump(cam, { skipInvalid: true }));
                            }}
                            exitDelay={copied ? 1500 : 600}
                            maxWidth="110px"
                            variant="plain"
                            onTooltipHidden={() => setCopied(false)}
                        >
                            {copied ? 'Successfully copied to clipboard!' : 'Copy to clipboard'}
                        </ClipboardCopyButton>

                        <Button
                            type="button"
                            onClick={downloadFunction}
                            variant="plain"
                            icon={<CopyIcon />}
                        />
                    </>
                }
            >
                <CodeBlockCode id="code-content">{yaml.dump(cam, { skipInvalid: true })}</CodeBlockCode>
            </CodeBlock>

            {/* Apply Button */}
            <Button variant={ButtonVariant.primary} onClick={handleApply}>
                Apply YAML to Cluster
            </Button>

        </Form>
    );
}

export default YamlGenerator;
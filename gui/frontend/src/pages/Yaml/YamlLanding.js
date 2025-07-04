import React from 'react';
import {
    Button,
    EmptyState,
    EmptyStateVariant,
    EmptyStateBody,
    EmptyStateActions,
    EmptyStateFooter
} from '@patternfly/react-core';
import CubesIcon from '@patternfly/react-icons/dist/esm/icons/file-code-icon';

function YamlLanding() {
    return (
        <EmptyState variant={EmptyStateVariant.sm} titleText="YAML Generator" headingLevel="h4" icon={CubesIcon}>
            <EmptyStateBody>
                TBD
            </EmptyStateBody>
            <EmptyStateFooter>
                <EmptyStateActions>
                    <Button variant="primary" onClick={() => window.location.href = '/yaml'}>Create</Button>
                    <Button variant="primary" onClick={() => window.location.href = '/upload'}>Use Existing CRD</Button>
                </EmptyStateActions>
            </EmptyStateFooter>
        </EmptyState>
    );
}

export default YamlLanding;

// Decision to make the printed yaml unchangeable is due to the fact the user
// could easily make a typo and not realise
// If we send the uploaded yaml to a form the value will either be mapped or left blank
// Introduces a level of error handling
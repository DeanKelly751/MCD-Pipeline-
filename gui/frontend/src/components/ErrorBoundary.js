import React from 'react';
import { Alert, AlertActionCloseButton } from '@patternfly/react-core';

class ErrorBoundary extends React.Component {
    constructor(props) {
        super(props);
        this.state = { hasError: false, error: null, errorInfo: null };
    }

    static getDerivedStateFromError(error) {
        return { hasError: true };
    }

    componentDidCatch(error, errorInfo) {
        this.setState({
            error: error,
            errorInfo: errorInfo
        });
        
        // Log error to console for debugging
        console.error('Error caught by boundary:', error);
        console.error('Error info:', errorInfo);
    }

    render() {
        if (this.state.hasError) {
            return (
                <Alert
                    variant="danger"
                    title="Something went wrong"
                    actionClose={
                        <AlertActionCloseButton
                            onClose={() => this.setState({ hasError: false, error: null, errorInfo: null })}
                        />
                    }
                    isInline
                >
                    <p>An error occurred while rendering this component.</p>
                    {process.env.NODE_ENV === 'development' && (
                        <details style={{ whiteSpace: 'pre-wrap' }}>
                            <summary>Error details (development mode)</summary>
                            {this.state.error && this.state.error.toString()}
                            <br />
                            {this.state.errorInfo.componentStack}
                        </details>
                    )}
                </Alert>
            );
        }

        return this.props.children;
    }
}

export default ErrorBoundary; 
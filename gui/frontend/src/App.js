import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { PageSection, PageSectionVariants } from '@patternfly/react-core';
import Navigation from './components/Navigation';
import ErrorBoundary from './components/ErrorBoundary';
import { Documentation } from './pages/Documentation';
import YamlLanding from './pages/Yaml/YamlLanding';
import YamlGenerator from './pages/Yaml/YamlGenerator';
import YamlUpload from './pages/Yaml/YamlUpload';
import '@patternfly/react-core/dist/styles/base.css';
import './App.css';

function App() {
  return (
    <ErrorBoundary>
      <Router>
        <Navigation>
          <PageSection variant={PageSectionVariants.light}>
            <ErrorBoundary>
              <Routes>
                <Route path="/" element={<YamlLanding />} />
                <Route path="/yaml" element={<YamlGenerator />} />
                <Route path="/upload" element={<YamlUpload />} />
                <Route path="/docs" element={<Documentation />} />
              </Routes>
            </ErrorBoundary>
          </PageSection>
        </Navigation>
      </Router>
    </ErrorBoundary>
  );
}

export default App;

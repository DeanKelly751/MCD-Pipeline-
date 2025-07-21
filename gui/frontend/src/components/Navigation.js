import React from 'react';
import {
  Nav,
  NavItem,
  NavList,
  Page,
  PageSidebar,
  PageSidebarBody,
  Masthead,
  MastheadMain,
  MastheadBrand,
  PageToggleButton,
  Brand
} from '@patternfly/react-core';
import { BarsIcon } from '@patternfly/react-icons';
import { Link, useLocation } from 'react-router-dom';
import codecoLogo from '../assets/codeco.png';

const Navigation = ({ children }) => {
  const location = useLocation();
  const [isSidebarOpen, setIsSidebarOpen] = React.useState(true);

  const onSidebarToggle = () => {
    setIsSidebarOpen(!isSidebarOpen);
  };

  const Header = (
    <Masthead>
      <MastheadMain>
        <MastheadBrand>
          <PageToggleButton
            variant="plain"
            aria-label="Global navigation"
            isSidebarOpen={isSidebarOpen}
            onSidebarToggle={onSidebarToggle}
            id="vertical-nav-toggle"
          >
            <BarsIcon />
          </PageToggleButton>
          <Brand src={codecoLogo} alt="CODECO" heights={{ default: '36px' }} />
        </MastheadBrand>
      </MastheadMain>
    </Masthead>
  );

  const NavigationList = (
    <Nav>
      <NavList>
        <NavItem isActive={location.pathname === '/'}>
          <Link to="/">Home</Link>
        </NavItem>
        <NavItem isActive={location.pathname === '/yaml'}>
          <Link to="/yaml">YAML Generator</Link>
        </NavItem>
        <NavItem isActive={location.pathname === '/upload'}>
          <Link to="/upload">Upload YAML</Link>
        </NavItem>
        <NavItem isActive={location.pathname === '/monitoring'}>
          <Link to="/monitoring">Monitoring</Link>
        </NavItem>
        <NavItem isActive={location.pathname === '/docs'}>
          <Link to="/docs">Documentation</Link>
        </NavItem>
      </NavList>
    </Nav>
  );

  const Sidebar = (
    <PageSidebar isSidebarOpen={isSidebarOpen}>
      <PageSidebarBody>
        {NavigationList}
      </PageSidebarBody>
    </PageSidebar>
  );

  return (
    <Page header={Header} sidebar={Sidebar} isManagedSidebar>
      {children}
    </Page>
  );
};

export default Navigation; 
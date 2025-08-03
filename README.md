# Blockchain-Based Public Transit Fare Collection and Revenue Management System

## Overview

This system provides a comprehensive blockchain-based solution for public transit fare collection and revenue management. It consists of five interconnected smart contracts that handle multi-modal fare integration, reduced fare eligibility, revenue sharing, fare evasion detection, and transit usage analytics.

## System Architecture

### Core Contracts

1. **Multi-Modal Fare Integration Contract** (`multi-modal-fare.clar`)
    - Enables seamless payment across buses, trains, and other transit modes
    - Manages fare calculations based on distance, time, and mode
    - Handles transfers between different transit systems

2. **Reduced Fare Eligibility Verification Contract** (`reduced-fare-eligibility.clar`)
    - Validates discounts for seniors, students, and low-income riders
    - Manages eligibility verification and renewal processes
    - Tracks discount usage and compliance

3. **Revenue Sharing Coordination Contract** (`revenue-sharing.clar`)
    - Distributes fare revenue between different transit agencies
    - Manages revenue allocation based on usage metrics
    - Handles inter-agency settlements

4. **Fare Evasion Detection Contract** (`fare-evasion-detection.clar`)
    - Identifies and addresses unauthorized transit use
    - Tracks violations and penalty assessments
    - Manages enforcement actions and appeals

5. **Transit Usage Analytics Contract** (`transit-usage-analytics.clar`)
    - Analyzes ridership patterns to optimize routes and schedules
    - Collects and processes usage data
    - Generates insights for system improvements

## Key Features

- **Seamless Multi-Modal Integration**: Pay once, travel across all transit modes
- **Automated Eligibility Verification**: Real-time validation of discount eligibility
- **Fair Revenue Distribution**: Transparent revenue sharing between agencies
- **Smart Evasion Detection**: Automated detection and penalty management
- **Data-Driven Analytics**: Comprehensive usage analytics for optimization

## Data Types

### Core Data Structures

- **Trip**: Records individual transit journeys
- **User Profile**: Stores user information and eligibility status
- **Agency**: Represents transit agencies and their configurations
- **Fare Structure**: Defines pricing for different modes and distances
- **Revenue Record**: Tracks revenue generation and distribution

## Security Features

- **Access Control**: Role-based permissions for different system actors
- **Data Integrity**: Immutable transaction records
- **Privacy Protection**: Anonymized analytics while maintaining functionality
- **Audit Trail**: Complete transaction history for compliance

## Getting Started

### Prerequisites

- Clarinet CLI installed
- Node.js and npm for testing
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository
2. Install dependencies: `npm install`
3. Run tests: `npm test`
4. Deploy contracts: `clarinet deploy`

### Testing

The system includes comprehensive tests for all contracts:

\`\`\`bash
npm test
\`\`\`

## Usage Examples

### Paying a Fare

\`\`\`clarity
(contract-call? .multi-modal-fare pay-fare u100 "bus" u5)
\`\`\`

### Verifying Eligibility

\`\`\`clarity
(contract-call? .reduced-fare-eligibility verify-eligibility tx-sender "student")
\`\`\`

### Recording Usage

\`\`\`clarity
(contract-call? .transit-usage-analytics record-trip "route-1" u50 u1200)
\`\`\`

## Contract Interactions

Each contract operates independently while maintaining data consistency across the system. The contracts use standardized data formats to ensure interoperability.

## Compliance and Regulations

The system is designed to comply with:
- Transit industry standards
- Data privacy regulations
- Financial reporting requirements
- Accessibility guidelines

## Future Enhancements

- Integration with mobile payment systems
- Real-time route optimization
- Predictive maintenance scheduling
- Carbon footprint tracking

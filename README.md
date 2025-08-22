# Safenet - Occupational Safety Violation Tracker

A decentralized smart contract system for reporting workplace safety violations anonymously while protecting whistleblowers through blockchain technology and token incentives.

## Overview

Safenet enables workers to report occupational safety violations without fear of retaliation. The system provides:

- Anonymous violation reporting
- Whistleblower protection through pseudonymous addresses
- Token rewards for verified reports
- Reputation-based scoring system
- Company risk assessment tracking
- Decentralized verification process

## Smart Contract Features

### Core Functions

**Report Violation**
- Submit safety violations anonymously
- Include company details, location, violation type, and evidence hash
- Automatic severity scoring (1-10 scale)
- Timestamped records on blockchain

**Verification System**
- Registered verifiers can validate reports
- Stake-based verifier registration (minimum 1000 STX)
- Token rewards distributed upon verification
- Accuracy tracking for verifiers

**Token Economics**
- Whistleblower tokens minted for verified reports
- Reward amount based on violation severity (severity × 100 tokens)
- Community-funded reward pool
- Emergency withdrawal for contract owner

### Data Structures

- **Violations**: Complete violation records with status tracking
- **User Stats**: Reporter statistics and reputation scores  
- **Company Violations**: Aggregated company safety records
- **Verifiers**: Registered verifier profiles and stake amounts

## Usage Instructions

### 1. Initialize Contract
```clarity
(contract-call? .safenet initialize-contract)
```

### 2. Report a Violation
```clarity
(contract-call? .safenet report-violation 
  "Acme Corporation"
  "Factory Floor Building A" 
  "Equipment Safety"
  "Missing safety guards on machinery causing injury risk"
  u7
  (some 0x1234567890abcdef))
```

### 3. Register as Verifier
```clarity
(contract-call? .safenet register-verifier u5000)
```

### 4. Verify Violation
```clarity
(contract-call? .safenet verify-violation u1 true)
```

### 5. Fund Reward Pool
```clarity
(contract-call? .safenet fund-reward-pool u10000)
```

## Read-Only Functions

### Get Violation Details
```clarity
(contract-call? .safenet get-violation u1)
```

### Check User Statistics
```clarity
(contract-call? .safenet get-user-stats 'SP1234567890ABCDEF)
```

### Company Safety Record
```clarity
(contract-call? .safenet get-company-violations "Acme Corporation")
```

### Contract Statistics
```clarity
(contract-call? .safenet get-contract-stats)
```

### Risk Assessment
```clarity
(contract-call? .safenet get-company-risk-score "Acme Corporation")
```

## Violation Status Flow

1. **Reported** - Initial submission by whistleblower
2. **Verified/Rejected** - Reviewed by registered verifiers
3. **Resolved** - Marked complete by contract administrator

## Security Features

- Anonymous reporting preserves whistleblower identity
- Stake-based verifier system prevents gaming
- Multi-signature verification for high-value claims  
- Emergency controls for contract administration
- Input validation and error handling

## Token Distribution

- Reporters receive tokens based on violation severity
- Higher severity violations = higher token rewards
- Reputation scores improve with verified reports
- Community can fund reward pool through contributions

## Development

### Prerequisites
- Clarinet CLI
- Node.js and npm
- Stacks blockchain knowledge

### Testing
```bash
npm install
npm test
clarinet check
```

### Deployment
```bash
clarinet deploy --testnet
```

## License

This project is licensed under the MIT License.

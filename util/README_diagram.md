# Architecture Diagram Generator

This document explains how to generate the architecture diagram for the Amazon Lex Airline Solution.

## Prerequisites

1. Python 3.6 or higher
2. Graphviz (system dependency)
3. Python Diagrams library

## Installation

### Install Graphviz

#### macOS
```bash
brew install graphviz
```

#### Ubuntu/Debian
```bash
sudo apt-get install graphviz
```

#### CentOS/RHEL
```bash
sudo yum install graphviz
```

### Install Python Dependencies
```bash
pip install diagrams
```

## Usage

1. Save the following code as `generate_diagram.py`:

```python
#!/usr/bin/env python3
from diagrams import Diagram, Cluster
from diagrams.aws.compute import Lambda
from diagrams.aws.database import Dynamodb
from diagrams.aws.ml import Lex
from diagrams.aws.integration import SimpleQueueServiceSqs
from diagrams.aws.security import IAM
from diagrams.aws.network import APIGateway
from diagrams.aws.engagement import Connect

# Create the diagram
with Diagram("Amazon Lex Airline Solution Architecture", show=True, filename="airline_architecture", outformat="png"):
    # Create components
    user = APIGateway("User Interface")
    
    with Cluster("Amazon Lex"):
        lex_bot = Lex("Airline Bot")
    
    with Cluster("Lambda Functions"):
        business_logic = Lambda("Business Logic")
        lex_import = Lambda("Lex Import")
        db_import = Lambda("DynamoDB Import")
        connect_import = Lambda("Connect Import")
    
    db = Dynamodb("Airlines DB")
    connect = Connect("Amazon Connect\n(Optional)")
    iam = IAM("IAM Roles")
    
    # Define relationships
    user >> lex_bot
    lex_bot >> business_logic
    business_logic >> db
    lex_import >> lex_bot
    db_import >> db
    connect_import >> connect
    connect >> lex_bot
    iam >> lex_bot
    iam >> business_logic
    iam >> lex_import
    iam >> db_import
    iam >> connect_import
```

2. Run the script:
```bash
python generate_diagram.py
```

3. The diagram will be generated as `airline_architecture.png` in the current directory.

## Understanding the Diagram

The diagram visualizes the following components and their relationships:

- **User Interface**: Entry point for user interactions
- **Amazon Lex**: The conversational bot that processes user inputs
- **Lambda Functions**:
  - Business Logic: Handles the core functionality and fulfillment
  - Lex Import: Imports the pre-built Lex bot configuration
  - DynamoDB Import: Populates the DynamoDB table with sample data
  - Connect Import: Sets up Amazon Connect integration
- **DynamoDB**: Database for storing airline and customer data
- **Amazon Connect**: Optional integration for call center capabilities
- **IAM Roles**: Provides necessary permissions for all components

The arrows indicate the flow of data and dependencies between components.

## Customization

You can customize the diagram by:

1. Changing the diagram title, filename, or output format
2. Adding or removing components
3. Modifying the relationships between components
4. Adjusting the visual styling (colors, layout, etc.)

For more information, refer to the [Diagrams documentation](https://diagrams.mingrammer.com/).
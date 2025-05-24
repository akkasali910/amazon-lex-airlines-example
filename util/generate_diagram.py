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


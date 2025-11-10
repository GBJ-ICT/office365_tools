
import configparser
import asyncio
from pathlib import Path
from util.graph import Graph

async def main(): 
    print("Starting Teams Channels Exporter!")

    config = configparser.ConfigParser()
    config.read(['config.cfg', 'config.dev.cfg'])
    azure_settings = config['azure']

    graph: Graph = Graph(azure_settings)

    await greet_user(graph)

    print("Export Done.")

# <GreetUserSnippet>
async def greet_user(graph: Graph):
    user = await graph.get_user()
    if user:
        print('Hello,', user.display_name)
        # For Work/school accounts, email is in mail property
        # Personal accounts, email is in userPrincipalName
        print('Email:', user.mail or user.user_principal_name, '\n')
    else:
        print('Could not identify user.\n')


# Run main
asyncio.run(main())
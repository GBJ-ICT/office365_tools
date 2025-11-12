import configparser
import asyncio
from pathlib import Path
from util.graph import Graph

async def main(): 
    print("Starting Teams Channels Exporter!")

    config = configparser.ConfigParser()
    config.read(['config.cfg', 'config.dev.cfg'])
    azure_settings = config['azure']
    # Specify team ID and channel ID
    team_id = xx
    channel_id = xx

    graph: Graph = Graph(azure_settings)
    await greet_user(graph)



    # Export specific team and channel
    await graph.export_specific_channel(team_id, channel_id, 'teams_export.json')

    print("Export Done.")

# <GreetUserSnippet>
async def greet_user(graph: Graph):
    user = await graph.get_user()
    if user:
        print('Hello,', user.display_name)
        print('Email:', user.mail or user.user_principal_name, '\n')
    else:
        print('Could not identify user.\n')

# Run main
asyncio.run(main())
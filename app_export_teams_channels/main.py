import configparser
import asyncio
from util_graph_pyhton.graph import Graph

def main(): 
    print("Starting Teams Channels Exporter!")

    config = configparser.ConfigParser()
    config.read(['config.cfg', 'config.dev.cfg'])
    azure_settings = config['azure']

    graph: Graph = Graph(azure_settings)

    await greet_user(graph)

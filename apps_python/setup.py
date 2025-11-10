## Needed to i 
## It doesn't copy the code to the standard site-packages directory. Instead, it creates a link to the project's source directory where it currently is.

from setuptools import setup, find_packages

setup(
    name="office365_python_tools",
    version="0.1",
    packages=find_packages(),
    install_requires=[
        'azure-identity',
        'msgraph-sdk',
    ]
)
## # Run pip install -e . in the \office365_tools\apps_python directory to install the package in editable mode.
## §It doesn't copy the code to the standard site-packages directory. Instead, it creates a link to the project's source directory where it currently is.

from setuptools import setup, find_packages

setup(
    name="office365_python_tools",
    version="0.1",
    packages=find_packages(),
    python_requires=">3.10 <3.12", # works for sure with 3.12, not tested yet with lower versions
    install_requires=[
        'azure-identity',
        'msgraph-sdk',
    ]
)


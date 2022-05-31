import os
from pathlib import Path
from typing import Dict, Sequence, Optional, Tuple, Union, cast, List, AsyncContextManager, Any

import attr
from docker import DockerClient
from IN import ProblemDetector, ProblemDetectorResult, VulnerabilityInfo, NonDetectedVulnerability, DetectedVulnerability
from IN import CodeRange
import json

import subprocess
from shutil import which

import signal
import copy
from encodings import utf_8
from logbook import Logger
import sys
import codecs
import time
import stat
import asyncio
import multiprocessing

from Utils import strToBool


async def test():
    print('testing')
    args_buildContract = 'solc --bin ico.sol'

    buildContractRun = await asyncio.create_subprocess_shell(
    args_buildContract,
    #   input=inputJSON,
    #   shell=True,
    #   check=True,
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=sys.stderr,
    # universal_newlines=True,
    encoding=utf_8.getregentry().name)

    stdout = ((await buildContractRun.communicate())[0]).decode(utf_8.getregentry().name)
    assert buildContractRun.returncode == 0, F'unexpected exit status {buildContractRun.returncode}'

    bytecode = stdout

    if len(bytecode) == 0:
        logger.error(F'Compilation output: \n{buildContractRun.stdout}')
        raise ValueError('Compiled bytecode is empty!')

async def main():
    await test()

if __name__ == "__main__":
    main()

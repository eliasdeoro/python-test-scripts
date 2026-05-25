## Practice, opens CMD and runs some commands, including arithmetic operations using set /a. Useful for learning how to automate command line tasks and perform calculations directly in the terminal!

import subprocess
import os

subprocess.Popen('start cmd /k "set /a result=10+5 && echo Result: %result% & ipconfig && timeout /t 5"', shell=True)

import subprocess

# Start cmd with piped stdin
process = subprocess.Popen(
    'cmd',
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True
)

# Send commands including arithmetic via set /a
commands = (
    'echo Hello\n'
    'set /a sum=25+17\n'
    'echo Sum: %sum%\n'
    'set /a product=6*7\n'
    'echo Product: %product%\n'
    'set /a difference=100-45\n'
    'echo Difference: %difference%\n'
    'set /a quotient=80/4\n'
    'echo Quotient: %quotient%\n'
    'dir\n'
    'cd C:\\\n'
    'exit\n'
)
stdout, stderr = process.communicate(commands)
print(stdout)


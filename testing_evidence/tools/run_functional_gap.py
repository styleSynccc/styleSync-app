"""Run exactly one newly added test and preserve full output and native results."""
import argparse
from pathlib import Path
import shutil
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

from run_qa import BACKEND, EVIDENCE, MOBILE, PYTHON, capture

parser = argparse.ArgumentParser()
parser.add_argument('framework', choices=['flutter', 'fastapi'])
parser.add_argument('file')
parser.add_argument('test_name')
parser.add_argument('--label', required=True)
args = parser.parse_args()
if not all(c.isalnum() or c in '_-' for c in args.label):
    parser.error('Use a safe label')
native = EVIDENCE / f'logs/{args.framework}/{args.label}'
suffix = '.jsonl' if args.framework == 'flutter' else '.xml'
if Path(str(native) + suffix).exists():
    raise SystemExit('Refusing to overwrite native test evidence; choose another label.')
if args.framework == 'flutter':
    command = [shutil.which('flutter'), 'test', '--no-pub', '--reporter', 'expanded', '--file-reporter', f'json:{native}.jsonl', args.file, '--plain-name', args.test_name]
    cwd = MOBILE
else:
    command = [str(PYTHON), '-m', 'pytest', '-vv', '-ra', '--tb=short', '-p', 'no:cacheprovider', f'--junitxml={native}.xml', f'{args.file}::{args.test_name}']
    cwd = BACKEND
meta = capture(f'{args.framework}/{args.label}.log', command, cwd, 180)
sys.exit(meta['exit_code'])

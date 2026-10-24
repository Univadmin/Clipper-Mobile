"""Run the project checks with one command, without reading private inputs."""
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
for command in (["flutter", "analyze", "--no-pub"], ["flutter", "test", "--no-pub"],
                ["python3", "-m", "unittest", "discover", "-s", "test", "-p", "test_*.py"]):
    subprocess.run(command, cwd=root, check=True)

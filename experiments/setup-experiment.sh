#!/bin/bash
# Set up an experiment directory on nigel
# Usage: bash setup-experiment.sh <experiment-name>
# Example: bash setup-experiment.sh 1-solo

EXPNAME=$1
BASEDIR=~/autoresearch
EXPDIR=$BASEDIR/experiments/$EXPNAME

if [ -z "$EXPNAME" ]; then
    echo "Usage: bash setup-experiment.sh <experiment-name>"
    exit 1
fi

echo "Setting up experiment: $EXPNAME"

# Symlink shared files (prepare.py, pyproject.toml, uv.lock, .python-version)
for f in prepare.py pyproject.toml uv.lock .python-version; do
    ln -sf "$BASEDIR/$f" "$EXPDIR/$f" 2>/dev/null
done

# Symlink .venv so we don't reinstall packages
ln -sf "$BASEDIR/.venv" "$EXPDIR/.venv" 2>/dev/null

# Symlink kernels module if it exists
[ -d "$BASEDIR/kernels" ] && ln -sf "$BASEDIR/kernels" "$EXPDIR/kernels" 2>/dev/null

# Init git
cd "$EXPDIR"
if [ ! -d .git ]; then
    git init
    git config user.email 'bigsnarfdude@github.com'
    git config user.name 'Vincent'
    # Only track our files, not symlinks
    echo '.venv' > .gitignore
    echo '__pycache__' >> .gitignore
    echo 'run.log' >> .gitignore
    echo '*.pyc' >> .gitignore
    git add train.py results.tsv ralph-loop/ .gitignore
    git commit -m "initial: $EXPNAME baseline from original train.py"
fi

echo "Experiment $EXPNAME ready at $EXPDIR"
echo "Launch with: screen -dmS $EXPNAME bash $EXPDIR/ralph-loop/run.sh"

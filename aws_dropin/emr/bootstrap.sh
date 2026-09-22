#!/bin/bash
# Shebang line: when EMR runs this file, it uses /bin/bash as the interpreter.

# EMR bootstrap action: installs what the repo needs beyond EMR's built-in
# Spark. This needs outbound internet (a NAT gateway) from the cluster's
# subnet, because pip has to reach pypi.org to download the packages.

# set -e         : exit immediately if any command returns a non-zero status.
# set -u         : treat use of an unset variable as an error (catches typos).
# set -o pipefail: if any command in a pipeline fails, the pipeline fails.
# Together they make the script fail loudly at the first sign of trouble
# instead of continuing in a half-broken state.
set -euo pipefail

# Install the pinned Python packages the pipeline needs.
# sudo             : install into the system Python that EMR's Spark uses.
# python3 -m pip   : the safest way to call pip (avoids Python-version mixups).
# install --quiet  : suppresses noisy progress bars in the EMR log output.
# Version pins ("==") make builds reproducible — same versions every time.
# The trailing backslashes join everything into one logical command.
sudo python3 -m pip install --quiet \
  "pandas==2.2.3" "pyarrow>=14" "sqlalchemy==2.0.36" \
  "psycopg2-binary==2.9.10" "python-dotenv==1.1.1" boto3

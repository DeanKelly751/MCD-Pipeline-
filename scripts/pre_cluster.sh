
#!/bin/bash

## Prerequisites: git and go
## This script downloads the CNI plugins and compiles them, so they can later be accessed by the kind cluster in the tmp directory


git clone https://github.com/containernetworking/plugins /tmp/plugins
/tmp/plugins/build_linux.sh
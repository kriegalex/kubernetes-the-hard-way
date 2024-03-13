# Prerequisites

## Openstack Cloud

This guide uses [OpenStack](https://www.openstack.org/), an open-source cloud computing platform, to create the necessary infrastructure for deploying a Kubernetes cluster. Familiarize yourself with OpenStack by visiting the official [OpenStack Documentation](https://docs.openstack.org/latest/).

There's no direct cost associated with using OpenStack in this tutorial, as it assumes access to an existing OpenStack cloud. Costs may vary based on your cloud provider or private cloud setup.

## Openstack CLI Tools

### Install the OpenStack CLI

To interact with the OpenStack cloud, you'll need the OpenStack Command Line Interface (CLI). Follow the OpenStack CLI installation guide to set it up.

Ensure your OpenStack CLI version is compatible with your OpenStack cloud version:

```
openstack --version
```

### Configure OpenStack CLI Environment

Before you start, you must source your OpenStack project's OpenRC file, 
which sets the necessary environment variables for the CLI to communicate with your OpenStack cloud:

```
source YOUR_PROJECT-openrc.sh
```

Authenticate your CLI session:

```
openstack token issue
```

Set a default compute availability zone and region, if necessary. This step varies by OpenStack cloud provider; consult your cloud's documentation for details. If you are using a default local installation, you don't need to worry about it, as only one local zone named `nova` exists.

## Running Commands in Parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. Labs in this tutorial may require running the same commands across multiple compute instances, in those cases consider using tmux and splitting a window into multiple panes with synchronize-panes enabled to speed up the provisioning process.

> The use of tmux is optional and not required to complete this tutorial.

![tmux screenshot](images/tmux-screenshot.png)

> Enable synchronize-panes by pressing `ctrl+b` followed by `shift+:`. Next type `set synchronize-panes on` at the prompt. To disable synchronization: `set synchronize-panes off`.

Next: [Installing the Client Tools](02-client-tools.md)

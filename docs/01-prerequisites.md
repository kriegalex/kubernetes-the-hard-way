# Prerequisites

## Exoscale

This tutorial leverages the [Exoscale Platform](https://www.exoscale.com/) to streamline provisioning of the compute infrastructure required to bootstrap a Kubernetes cluster from the ground up. [Contact them](https://www.exoscale.com/contact/) to ask for a trial credit.

[Estimated cost](https://www.exoscale.com/calculator/) to run this tutorial: $0.72 per hour ($17.30 per day).

> The compute resources are a bit more expensive on Exoscale compared to other platforms. If you are looking for a cheaper option, consider the original "Kubernetes The Hard Way" [github repository](https://github.com/kelseyhightower/kubernetes-the-hard-way). It uses Google Cloud Platform.

## Exoscale CLI

### Install the Exoscale CLI

Follow the Exoscale CLI [documentation](https://community.exoscale.com/documentation/tools/exoscale-command-line-interface/) to install and configure the `exo` command line utility.

Verify the Exoscale CLI version is 1.76.1 or higher:

```
exo version
```

### Configure the Exoscale CLI

This tutorial assumes the exo CLI is configured. If you are using the `exo` command-line tool for the first time, `config` is the way to do this:

```
exo config
```

The first access key must be generated through the web portal. [More information here](https://community.exoscale.com/documentation/iam/quick-start/). It will also ask you to setup a default zone. Calling `config` again allows to setup another profile with another default zone.

> Use the `exo zone` command to view additional regions and zones.

## Running Commands in Parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. Labs in this tutorial may require running the same commands across multiple compute instances, in those cases consider using tmux and splitting a window into multiple panes with synchronize-panes enabled to speed up the provisioning process.

> The use of tmux is optional and not required to complete this tutorial.

![tmux screenshot](images/tmux-screenshot.png)

> Enable synchronize-panes by pressing `ctrl+b` followed by `shift+:`. Next type `set synchronize-panes on` at the prompt. To disable synchronization: `set synchronize-panes off`.

Next: [Installing the Client Tools](02-client-tools.md)

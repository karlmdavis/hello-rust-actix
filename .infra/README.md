Hello Rust Actix: Infrastructure Scripts
----------------------------------------

This repository contains the Ansible provisioning, roles, etc. used to setup and manage this Glitch project's optional cloud infrastructure.

## Development Environment

In order to use and/or modify these utilities, a number of tools need to be installed.

### Python

This project requires Python 3 to run Ansible. It can be installed as follows on Ubuntu 18.04:

    $ sudo apt-get install python3 python3-dev

The Ansible modules run (against `localhost`) will also require Python 2 and some packages. They can be installed as follows on Ubuntu 18.04:

    $ sudo apt-get install python python-boto python-boto3

### virtualenv

This project has some dependencies that have to be installed via `pip` (as opposed to `apt-get`). Accordingly, it's strongly recommended that you make use of a [Python virtual environment](http://docs.python-guide.org/en/latest/dev/virtualenvs/) to manage those dependencies.

If it isn't already installed, install the `virtualenv` tool. On Ubuntu, this is best done via:

    $ sudo apt-get install python3-virtualenv

Next, create a virtual environment for this project and install the project's dependencies into it:

    $ cd hello-rust-actix.git/ansible
    $ virtualenv -p /usr/bin/python3.6 venv
    $ source venv/bin/activate
    $ pip install --upgrade setuptools
    $ pip install --requirement requirements.txt

The `source` command above will need to be run every time you open a new terminal to work on this project.

Be sure to update the `requirements.txt.frozen` file after `pip install`ing a new dependency for this project:

    $ pip freeze > requirements.txt.frozen

### Ansible Vault Password

The security-sensitive values used in these playbooks (e.g. usernames, passwords, etc.) are encrypted using [Ansible Vault](http://docs.ansible.com/ansible/playbooks_vault.html). In order to view these values or run the plays you will need a copy of the project's `vault.password` file. Please this file in the root of the project, and ensure that it is only readable by your user account. **Never** commit it to source control! (Git is configured to ignore it via [.gitignore](./.gitignore).)

### AWS API Security Tokens

As a best practice, AWS accounts are often configured to require multi-factor authentication. You'll first need to ensure that you have set this up such that you can login to the AWS account's web console. Once you can login to the web console, ensure that you've created an API key for your user and configured it as a profile in `~/.aws/credentials`, e.g.:

```
# The AWS keys for the account used to provide compiler caching for Rust webapps in Glitch.
[glitch_rust]
aws_access_key_id = foo
aws_secret_access_key = bar
```

Due to the MFA requirements, though, that access key won't be useable by itself. Instead, you'll have to configure an additional profile in `~/.aws/credentials` with a valid MFA/session token, e.g.:

```
[glitch_rust_mfa]
aws_secret_access_key = fizz
aws_session_token = buzz
aws_access_key_id = whoozit
```

You can Google around for how to generate this. Or, much more simply, you can use the provided `aws-mfa-refresh.sh` script to automatically generate/update it as needed (be sure to use the correct `mfa-serial-number` value, as listed in IAM for your user):

    $ ./aws-mfa-refresh.sh --source-profile=glitch_rust --mfa-serial-number arn:aws:iam::11111111:mfa/myuser

## Running the Playbooks

The playbooks can be run, as follows:

    $ AWS_PROFILE=glitch_rust_mfa ./ansible-playbook-wrapper site.yml

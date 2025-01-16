# BRAVO Deployment with Ansible

Three roles:
- Install components & configure.
- Download, unpack, and load backing data.
- Run applications as systemd services.

## Dependencies
- AWS Credentials configured locally.
- [Ansible installed](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) 
- Requires Ansible collection community.mongodb
    ```
    ansible-galaxy collection install -r requirements.yml
    ```
- ssh keys to use to access the EC2 instances: [key-pair docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#prepare-key-pair)

### Optional S3 Dependency for Data Loading
Data for staging deployment may be downloaded from an S3 bucket to disk.
It can then be subsequently loaded into mongo.

This is a convenience for smaller data sets like the staging data.
It is not suitable for large data sets such as the production data.

### Optional S3 Runtime Dependency
Subsets of the coverage and crams data can be retrieved from S3 at runtime to save on disk space.
This requires a build of HTSLIB that supports the libcurl and s3 plugins.

In order to use S3 as the backing data for crams or coverage, the corresponding variable needs to be defined for the application host or group variables.
E.g. in `group_vars/bravo_staging/dirs.yml`:

```yml
---
coverage_url: "s3://example-bucket/runtime/coverage"
sequences_url: "s3://example-bucket/runtime/crams"
```

## Data Loading
The data loading step is time consuming.
The role creates lock files to indicate that it's already been run.
This facilitates a hack to avoid trying to figure out if data needs to be reloaded.
If data loading needs to be re-done, the lock files on the app server must be removed.

The download task is time consuming, but does **not** produce a lock file nor check if files are already present.

## Auth Configuration
To enable OAuth using Google as the identity provider, the client id and secrent must be given.
The following configuration is expected to be in `group_vars/app/auth.yml`
```yml
---
gauth_client_id: "yourcliendid"
gauth_client_secret: "yourclientsecret"
```
When absent, the generated application config will set `DISABLE_LOGIN` to `true`.

## Run deployment
Prior to running ansible, an ssh config and inventory needs to be written.
The `make_ansible_support_files.sh` script creates these.
The script is meant to be run from the directory in which it's located.
By default it reads the terraform cloud project 'bravo-staging'.
To get the production configs, `export WORKSPACE_NAME=bravo-production` before running the script.

The following sub-sections provide the commands for different deployment situations.

### Full deployment including download & data loading
Data will be downloaded from s3 and processes to load data into mongodb will be run.
Need to provide three variables `data_bucket` and `load_data` `do_download`.
Data download, unpacking, and loading can take a long time and should only need to be done once.

- `load_data`: (default false) Load basis data from disk into mongo instance.
- `do_download`: (default false) Download the data from bucket prior to loading.
- `data_bucket`: name of your s3 bucket without leading protocol (s3://).

```sh
ansible-playbook --ssh-common-args='-F inv/ssh-config' \
  -i 'inv/servers' playbook.yml \
  -e ' load_data=true do_download=true data_bucket=your_bucket_name'
```

### Full deployment with data loading (no bucket download)
To load the data only for the cases where it's already in place on disk, only `load_data=true` 
should be specified since `do_download` is false by default.

```sh
ansible-playbook --ssh-common-args='-F inv/ssh-config' \
  -i 'inv/servers' playbook.yml -e 'load_data=true'
```

### Deploy from specific git branch
To deploy from a specific reference on github, specify the `bravo_ref` variable (default value is "main").
```sh
ansible-playbook --ssh-common-args='-F inv/ssh-config' \
  -i 'inv/servers' playbook.yml -e 'bravo_ref=example'
```

### Only redeploy the python application:
Only update the API and restart the systemd service running it.
```
ansible-playbook --ssh-common-args='-F inv/ssh-config'\
  -i 'inv/servers' --tags instance playbook.yml
```

### Deployment including dependencies:
This is the default run.
Updates the machine, installs dependencies, installs application.
```
ansible-playbook --ssh-common-args='-F inv/ssh-config' -i 'inv/servers' playbook.yml
```

## Troubleshooting

### Unable to connect to app or db instance via ssh
After provisioning the infrastructure again, the application and bastion hosts will have changed but the private ips are static.
As such, the ssh known hosts will be in conflict. You may have remove the entries in your known hosts file and accept the new fingerprints when prompted.  The IPs should be listed in inv/servers.

```sh
ssh-keygen -f "~/.ssh/known_hosts" -R "10.0.101.14"
```


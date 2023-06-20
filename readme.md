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

### Optional Dependency
Data for staging deployment may be downloaded from an S3 bucket

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
Prior to running ansible, an ssh config and inventory needs to be built.
The `make_ansible_support_files.sh` script creates these.
The script is meant to be run from the directory in which it's located.

The following sub-sections provide the commands for different deployment situations.

### Full deployment including download & data loading
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
  -i 'inv/servers' playbook.yml -e ' load_data=true'
```

### Deployment including dependencies:
Updates the machine, installs dependencies, installs application.
```
ansible-playbook --ssh-common-args='-F inv/ssh-config' -i 'inv/servers' playbook.yml
```

### Just redeploy the python application:
Only update the application and restart the systemd service running it.
```
ansible-playbook --ssh-common-args='-F inv/ssh-config'\
  -i 'inv/servers' --tags instance playbook.yml
```

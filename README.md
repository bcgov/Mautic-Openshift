# Summary
This document contains both user documentation and developer documentation for the mautic server.
There is a seperate repository for the mautic subscription app (https://github.com/bcgov/Mautic-Subscription-App). 

# User Guide
## Community Users
### Segment
In Mautic, an email distribution list is called a `segment`. A segment can easily be created in the `Segments` tab by giving it a name and description.

### Email
A `New Segment Email` can be set up under the `Channels` -> `Emails` tab. It is important to note that an email template can only be sent to a contact once. This means that since Mautic keeps track of users that a segment email is sent to, only newly subscribed users will receive that email if it is sent out again.


In the `Advanced` tab, there are options to change the email address that the mailing list subscribers will receive the emails from. By setting this up, subscribed users will see the configured email as the sender rather than the admin account's email address. Similarly, the subscribed users will be able to reply to the configured email as well.


The `subject` field will be the title of the email, `Internal Name` will be the name of the email template tracked within Mautic, and the `Contact Segment` should be chosen as the segment to send the email to.


The contents of the email can be set in the `builder`.
Within the builder, the email templates will have `slots` for you to click on and edit the contents.


The email can be previewed by applying, then clicking on the `Public Preview URL`


The email template can be modified if needed. To do so, please contact the admin to update the templates in the source code.

## Admins
### Setting up Mautic

1. Go to the Mautic Deployment route. This will lead you to the Mautic Installation - Environment Check page. 
The installer may suggest some recommendations for the configuration. Review these recommendations and go to the next step.

2. On the Mautic Installation - Database Setup page, the required input should be pre-filled for you. Go to the next page.

3. On the Mautic Installation - Administrative User page, create the admin user as required.

4. On the Mautic Installation - Email Configuration page, select "Other SMTP Server" as the Mailer Transport.
To use the government server, use the following values:
- Server: apps.smtp.gov.bc.ca
- Port: 25
- Encryption: None
- Authentication mode: Login
- Username: firstname.lastname
- Password: Login Password

To use Gmail, use the following values:
- Server: smtp.gmail.com
- Port: 587
- Encryption: TLS
- Authentication mode: Login
- Username: Gmail Username
- Password: Gmail Password

Additionally, you may need to configure your security settings in Gmail to turn on "Less secure app access" at https://myaccount.google.com/security as well as turn on "Display Unlock Captcha" at https://accounts.google.com/b/0/DisplayUnlockCaptcha.

5. After logging in, navigate to the settings cog in the top right of the page -> configuration -> Email Settings and use the `Test Connection` and `Send Test Email` buttons to verify that the email is set up properly. 

    To allow emails to be sent out to contacts, you must change the Frequency Rule within Mautic.
    Scrolling down, you will see the "Default Frequency Rule". This number will be the maximum number of emails that can be sent to a user in the given time period. Setting this number to a reasonable value will help prevent unintentional email spamming.

    To customize the unsubscribe text that is to be displayed at the end of an email, scroll down to "Unsubscribe Settings". Replace the `|URL|` text under `Text for the {unsubscribe_text} token` with the mautic subsription app url. Doing so will allow us to easily generate the unsubscribe message in an email by adding `{unsubscribe_text}` to an email.

    Make sure to apply and save your changes.

### Setting up roles
To assign users with their own roles, a role can be created in the settings cog in the top right -> Roles. Recommended permissions settings are `View Own`, `Edit Own`, `Create`, and `Delete Own` for all permissions.

### Setting up subscription confirmation emails
Set up a subscription confirmation email by going to `Channels` -> `Emails` -> `New Template Email`. The email ID must match the CONFIRMATION_EMAIL_ID field in the `api/.env` file in the subscription app.

### Changing email themes
Email themes are saved in the mautic container at `var/www/html/themes`, you can the currently used themes at `./mautic-init/themes/`. To create a new theme, you can start by making a copy of the existing themes and modify it. To test it, you can upload the new themes directory to the mautic server container directly: `oc rsync ./mautic-init/themes/BCGov <pod-name>:/var/www/html/themes`. Alternatively, you can zip the theme package and uploaded through the mautic user interface.

Once tested, it's time to rebuild the mautic image so that the themes will be available persistently. To do so, start a Pull Request with the new themes included, kick off an image build to create a new image `mautic-init:latest`. You can find the openshift template for the buildConfig [here](./openshift/mautic.yaml).

# Developer Guide

# Architecture Diagram

![Architecture Diagram](architecture-diagram.png)

# Setting up Mautic on Openshift

Mautic has two components, Mautic server and MariaDB, as two separate deploymentConfigs.

There are two containers for the Mautic server pod:

**mautic-init:**
- purpose: the init container has the custom themes package, and it will make sure the themes are copied to the correct place on mautic server container
- build: buildConfig takes `ubuntu:latest` as the base image, and copies over the custom Mautic themes from this repo. You can find the Dockerfile for the init image [here](./mautic-init/Dockerfile).

**mautic:**
- purpose: this is the main container that runs the mautic server
- build: buildConfig builds the mautic server image based on the DockerFile located [here](./apache/Dockerfile)

You can find the corresponding buildConfig template from [here](./openshift/mautic.yaml)

MariaDB has its own deployment, using image `registry.redhat.io/rhel8/mariadb-103`. No extra building process needed.

## Building and Deploying Mautic on Openshift

### Create the network security policy
   First, create the network security policies using the command:
   ```oc process -f ./openshift/nsp.yaml -p APP_NAME=<app-name> -p NAMESPACE=<namespace> -p ENVIRONMENT=<environment> | oc apply -f -```

- Example: ```oc process -f ./openshift/nsp.yaml -p APP_NAME=mautic -p NAMESPACE=de0974 -p ENVIRONMENT=tools | oc apply -f -```

### Using manual commands

1. **Process and apply the mariadb secret.yaml**

    Create the secret using the command:
    ```
        oc process -f ./openshift/secret.yaml \
        -p NAME=<name> \
        -p DATABASE_NAME=<database-name> \
        -p DATABASE_USER=<database-user-name> \
        -p DATABASE_USER_PASSWORD=<database-user-password> \
        -p DATABASE_ROOT_PASSWORD=<database-root-password> \
        | oc apply -f - -n <namespace>
    ```

    The parameters can only contain alphanumeric and underscore characters.
    
    - Example: ```oc process -f ./openshift/secret.yaml -p APP_NAME=mautic -p DATABASE_NAME=mautic_db -p DATABASE_USER=mautic_db_user -p DATABASE_USER_PASSWORD=password -p DATABASE_ROOT_PASSWORD=password2 | oc apply -f - -n de0974-tools```

2. **Process and apply the mautic.yaml**
    ```
        oc process -f ./openshift/mautic.yaml \
        -p APP_NAME=<app-name> \
        -p GIT_REF=<git-branch> \
        -p GIT_REPO=<git-repo> \
        -p NAMESPACE=<namespace> \
        -p STORAGE_CLASS_NAME=<storage-class-name> \
        -p IMAGE_TAG=3.1.2 \\
        | oc apply -f - -n <namespace>

    ```

    - Example: ```oc process -f ./openshift/mautic.yaml -p APP_NAME=mautic -p GIT_REF=main -p GIT_REPO=https://github.com/bcgov/mautic-openshift -p NAMESPACE=de0974-tools -p STORAGE_CLASS_NAME=netapp-file-standard -p IMAGE_TAG=3.1.2 | oc apply -f - -n de0974-tools```
    
3. **Start the builds**
Start the builds for Mautic and the init container using `oc start-build [app-name]` and `oc start-build [app-name]-init`
When the builds are finished, redeploy the deploymentConfig.

## Cleaning up the namespaces
To clean up mautic artifacts, use the command: 
    `oc delete all,secret,configmap -l app=<app-name> -n <tools-namespace>`
- Example: `oc delete all,secret,configmap -l app=mautic -n de0974-tools`

### Database Backup
Database backups can be created using [backup-container](https://github.com/BCDevOps/backup-container). Files utilized can be found in the backup directory.
The commands used to deploy the backup container are:

1. Build the image in the tools namespace
`oc -n de0974-tools process -f ./openshift/templates/backup/backup-build.yaml -p DOCKER_FILE_PATH=Dockerfile_MariaDB -p NAME=mautic-db-backup OUTPUT_IMAGE_TAG=prod | oc -n de0974-tools create -f -`

2. Label the database to be backed up with backup=true and env=<output-image-tag>

3. Create configmap for the backup configuration
`oc -n de0974-prod create configmap backup-conf --from-file=./backup-container/config/backup.conf`
`oc -n de0974-prod label configmap backup-conf app=mautic-db-backup`

4. Deploy the container
```
oc -n de0974-prod process -f ./openshift/templates/backup/backup-deploy.yaml \
  -p NAME=mautic-db-backup \
  -p IMAGE_NAMESPACE=de0974-tools \
  -p SOURCE_IMAGE_NAME=mautic-db-backup \
  -p TAG_NAME=prod \
  -p BACKUP_VOLUME_NAME=mautic-db-backup-pvc \
  -p BACKUP_VOLUME_SIZE=1Gi \
  -p VERIFICATION_VOLUME_SIZE=10Gi \
  -p VERIFICATION_VOLUME_CLASS=netapp-file-standard \
  -p DATABASE_DEPLOYMENT_NAME=mautic-db \
  -p DATABASE_USER_KEY_NAME=database-user \
  -p DATABASE_PASSWORD_KEY_NAME=database-password \
  -p ENVIRONMENT_FRIENDLY_NAME='mautic-db backups' \
  -p ENVIRONMENT_NAME=de0974-prod | oc -n de0974-prod create -f -
```

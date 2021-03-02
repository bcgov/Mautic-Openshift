# Setting up Mautic on Openshift
This guide will go over two methods to build and deploy Mautic on openshift: using argo and using openshift commands.

The guide will also go over a brief Mautic setup guide.

## Building and Deploying Mautic on Openshift
### Create the network security policy
   First, create the network security policies using the command:
   ```oc process -f ./openshift/nsp.yaml -p APP_NAME=<app-name> -p NAMESPACE=<namespace> -p ENVIRONMENT=<environment> | oc apply -f -```

- Example: ```oc process -f ./openshift/nsp.yaml -p APP_NAME=mautic -p NAMESPACE=de0974 -p ENVIRONMENT=tools | oc apply -f -```


### CI/CD Argo

To build and deploy in the tools namespace using the argo pipeline, use the following command:

```argo submit argo/mautic.build.yaml -p GIT_REF=<branch-name> -p GIT_REPO=<git-repo> -p  NAMESPACE=<tools-namespace> -p APP_NAME=<app-name> -p IMAGE_TAG=3.1.2 -p STORAGE_CLASS_NAME=<storage-class-name> -p DATABASE_NAME=[database-name] -p DATABASE_USER=[database-user-name] -p DATABASE_USER_PASSWORD=[database-user-password] -p DATABASE_ROOT_PASSWORD=[database-user-password]```

Note that the DATABASE_USER, DATABASE_USER_PASSWORD, and DATABASE_ROOT_PASSWORD must not contain

- Example: ```argo submit argo/mautic.build.yaml -p GIT_REF=clean-state -p GIT_REPO=https://github.com/bcgov/mautic-openshift -p  NAMESPACE=de0974-tools -p APP_NAME=mautic -p IMAGE_TAG=3.1.2 -p STORAGE_CLASS_NAME=netapp-file-standard -p DATABASE_NAME=mautic_db -p DATABASE_USER=mautic_db_user -p DATABASE_USER_PASSWORD=password -p DATABASE_ROOT_PASSWORD=password2```

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
    
## Cleaning up the namespaces
To clean up mautic artifacts, use the command: 
    `oc delete all,secret,configmap -l app=<app-name> -n <tools-namespace>`
- Example: `oc delete all,secret,configmap -l app=mautic -n de0974-tools`

## Setting up Mautic

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

To customize the unsubscribe text, scroll down to "Unsubscribe Settings". Replace the `|URL|` text under `Text for the {unsubscribe_text} token` with the mautic subsription app url. Doing so will allow us to easily generate the unsubscribe message in an email by adding `{unsubscribe_text}` to an email.

Make sure to apply and save your changes.

## Mautic Workflow

### Segment
In Mautic, an email distribution list is called a `segment`. A segment can easily be created in the `Segments` tab by giving it a name.

### Form
Forms allow users to subscribe/unsubscribe themselves using the Mautic Subscription App. For each segment two forms should be created: subscribe and unsubscribe.

The forms name can be customized to any name but they must match the SUBSCRIBE_FORM and UNSUBSCRIBE_FORM parameters for the Mautic Subscription App.

When creating a form it is important that the `Successful Submit Action` is set to Redirect URL and that the Redirect URL/Message is set to https://<mautic-subscription-app-url>/subscribed for the subscribed form and https://<mautic-subscription-app-url>/unsubscribed for the unsubscribe form.

- Example: ```https://mautic-subscription.apps.silver.devops.gov.bc.ca/subscribed``` and ```https://mautic-subscription.apps.silver.devops.gov.bc.ca/unsubscribed```

Under the `Fields` tab, a new `Email` field should be created with a label value of `Email`. This is important since the Mautic Subscription app utilizes the label value as `Email`

Under the `Actions` tab, a new submit action to `Modify contact segments` should be created. You can choose to `Add contact to selected segment(s)` for the subscribe form or `Remove contact from selected segment(s)` for the unsubscribe form. The name of the action can be customized.

### Email
A `New Segment Email` can be set up under the `Channels` tab. For a basic layout the Blank theme can be used. The contents of the email can be set in the `builder`.

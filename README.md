# WinMan REST API

## Prerequisites

Before the WinMan REST API can be installed on a customer's server, several steps must be completed:

1. **Create a new DNS entry:**
a. This needs to be completed by Mike. The new DNS entry should be of the format `[customername]rest.winman.net`, e.g. `talkingtablesrest.winman.net`, and should point to the customer's WinMan application server.

2. **Create a new Firewall rule:**
a. The API will run on port 3000 by default. To accommodate this, port 3000 must be accessible on the customer's WinMan application server. Create a new TCP Firewall rule to allow traffic on this port. A discussion with the customer will need to be had to determine whether this rule should apply for all remote IPs or just specified ones.

3. **Install NodeJS:**
a. NodeJS version 6.11.2 needs to be installed on the customer's WinMan application server. The installation of NodeJS requires a restart, so please schedule this in with the customer carefully.

## Building the API package for release

### TODO
```BASH
npm run build
```
- change config file to reflect customer's db info/url
- change session cookie secret

## Installing the API

1. Copy the **contents** of your `dist` directory (not the directory itself!) onto the client's WinMan application server in a suitable location (e.g. `C:\Program Files\winman-rest-api`). 
2. Log on to the client's server as an Administrator and open an **elevated** command prompt.
3. Issue the following command:
    ```BASH
    npm install --global --production windows-build-tools
    ```
    This command will take approximately 5-10 minutes to complete.
4. After the previous command has completed, issue the following command:
    ```BASH
    npm install --global node-gyp
    ```
    This command will only take a minute or two to complete.
5. Add two new **system** environment variables:
    - Variable Name: **PYTHON**
      Variable Value: **/path/to/python/python.exe**
      
    - Variable Name: **NODE_ENV**
      Variable Value: **production**
      
    The Python executable is downloaded by the command in step 3, and the path to your `python.exe` will usually be something like `C:\Users\Admin-Winman\.windows-build-tools\python27\python.exe`.
6. Back in your elevated command prompt, `cd` to your `winman-rest-api` directory then issue the following command:
    ```BASH
    npm install
    ```
    This commmand will download and install the necessary Node modules.
7. After the previous command has completed, your API has been successfully installed.

## Adding the Windows service

1. In order for the API to be perpetually available, it needs to be run as a Windows service. To do this, from your **elevated** command prompt, still within your `winman-rest-api` directory, issue the following command:
    ```BASH
    node winman-rest --add
    ```
    If the service is added correctly you should see the following message:
    ```BASH
    WinMan REST API service successfully added.
    ```
    
## Starting the Windows service

1. In an **elevated** command prompt, enter the following command:
    ```BASH
    net start winman-rest
    ```
    If the service is started correctly, you should see the following message:
    ```BASH
    The WinMan REST API service was started successfully.
    ```
    Please note, you do not have to `cd` to your `winman-rest-api` directory to run the above command - it can be run from any directory.
    
## Stopping the Windows service

1. In an **elevated** command prompt, enter the following command:
    ```BASH
    net stop winman-rest
    ```
    If the service is stopped correctly, you should see the following messages:
    ```BASH
    The WinMan REST API service is stopping.
    The WinMan REST API service was stopped successfully.
    ```
    Please note, you do not have to `cd` to your `winman-rest-api` directory to run the above command - it can be run from any directory.
    
## Restarting the Windows service

1. Restarting the Windows service can be achieved in one step by chaining the stop and start commands together. In an **elevated** command prompt, enter the following command:
    ```BASH
    net stop winman-rest && net start winman-rest
    ```
    If the service is restarted correctly, you should see the following messages:
    ```BASH
    The WinMan REST API service is stopping.
    The WinMan REST API service was stopped successfully.
    
    The WinMan REST API service was started successfully.
    ```
    Please note, you do not have to `cd` to your `winman-rest-api` directory to run the above commands - it can be run from any directory.
    
## Removing the Windows service

1. Follow the steps above to stop the Windows service. **This step is important! See Troubleshooting Guide if you ommitted it.**
2. In an **elevated** command prompt, `cd` to your `winman-rest-api` directory and enter the following command:
    ```BASH
    node winman-rest --delete
    ```
    If the service is removed correctly, you should see the following message:
    ```BASH
    WinMan REST API service successfully removed.
    ```
    
## Troubleshooting Guide

1. If you removed the Windows service without stopping it first, you may see the following message when you try to add it again:
    ```BASH
    Trace: Error: CreateService() failed: The specified service already exists.
    ```
    To resolve this, you need to kill the process:
    
    a. Obtain the process ID number (PID) by issuing the following command in a command prompt:
    ```BASH
    sc queryex winman-rest
    ```
    You should see something similar to the following, where the highlighted line shows your PID:
    <pre>    
    SERVICE_NAME: winman-rest
        TYPE               : 10  WIN32_OWN_PROCESS
        STATE              : 4  RUNNING
                                (STOPPABLE, NOT_PAUSABLE, ACCEPTS_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x0
        <mark>PID                : [PID]</mark>
        FLAGS              : 
    </pre>
    
    It is possible you will see the error below instead of the information you require:
    ```BASH
    [SC] EnumQueryServicesStatus:OpenService FAILED 1060:

    The specified service does not exist as an installed service.    
    ```
    If this is the case, you can issue the following command to see information for all installed services:
    ```BASH
    sc queryex type=service
    ```
    The WinMan REST API service should appear towards the bottom of this list.
    
    b. Once you have obtained your PID, issue the following command:
    ```BASH
    taskkill /f /pid [PID]
    ```
    You should see the following success mesasge:
    ```BASH
    SUCCESS: The process with PID [PID] has been terminated.
    ```
    You should now be able to add the Windows service again.

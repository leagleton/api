# Note from Lynn: Please note, this is still a work in progress so please ignore the README for now. I will update when it's ready for use.

# WinMan REST API

## Installing the service

1. Open a command prompt as Administrator.
2. cd to winman-rest-api directory
3. 
    ```BASH
    npm update
    node winman-rest --add
    net start winman-rest
    ```
4. Done :).

## Removing the service

1. Open a command prompt as Administrator.
2. 
    ```BASH
    node winman-rest --remove
    ```

## Stopping the service

1. Open a command prompt as Adminsitrator.
2. 
    ```BASH
    net stop winman-rest
    ```
# webmon
Webmon is a website monitoring and alerting tool built with PowerShell and uses a MySQL backend, container platform (docker, kubernetes, etc), and Pager Duty for alerting and incident management.

[![Webmon Website Monitoring and Alerting with PagerDuty](https://rickjacobo.com/wp-content/uploads/2022/04/Webmon-Play.png)](https://rickjacobo.com/wp-content/uploads/2022/04/webmon.mp4)

## Requirements
- Container Platform
- MySql Database
- PagerDuty

### PagerDuty
Get Started with PagerDuty: https://support.pagerduty.com/docs/quick-start-guide
- Log in to your PagerDuty Account
  - Select the PagerDuty App/Service you would like to integrate with opsmon > add the "Events API V2" integration to the service. 
  - Obtain the "Integration Key" from the "Events API V2" integration

## Setup
### Docker Example
* Run Docker Command
    ````
    docker run -d -e ENV_SQL_HOSTNAME="<hostname>" -e ENV_SQL_USERNAME="<username>" -e ENV_SQL_PASSWORD="<password>" -e ENV_SQL_DATABASE="<database>" -e ENV_SQL_TABLE="<table>" -e ENV_PAGERDUTY_ENDPOINT="https://events.pagerduty.com/v2/enqueue" -e ENV_PAGERDUTY_ROUTING_KEY="<pagerduty_routing_key>" --name webmon rickjacobo/webmon
    ````


### Create SQL Database and Table
* Obtain SQL Statement
    ````
    docker exec -it webmon cat import.sql > import.sql
    ````

* Import SQL Statement into MySQL
    ````
    mysql -u <username> -p
    CREATE DATABASE <database>
    mysql -u <username> -p <database> < import.sql
    ````

### Add Services via CLI (Docker Example)
````
docker exec -it webmon pwsh add.ps1 -Url "https://news.google.com" -Keyword "google"
````

### Delete Monitored Service via CLI (Docker Example)
* Obtain Id
  ````
  docker exec -it webmon pwsh query.ps1
  ````

* Delete Id
  ````
  docker exec -it webmon pwsh delete.ps1 -Id <id>
  ````
  
### Add A Web Dashboard
* [Webmon-Dashboad](https://github.com/rickjacobo/Webmon-dashboard)
  
## Services
There are two example services in the database. When adding new services to monitor you only need to enter the url, type, and keyword. The id, status, alert, pagerduty_dedup, and lastupdate_utc fields are used by the app and don't need to be manually populated.
### Url
Enter the IP address or FQDN of the service to monitor
  
### Keyword
Enter a string to test.

### Example
Do not populate fields with an *

| id          | url              | type      | keyword | status | alert | pagerduty_dedup | lastupdate_utc |
| ----------- | ---------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ----------- |
| *           | news.google.com  | keyword  | google  |*            |*            |*            |*            |*            |


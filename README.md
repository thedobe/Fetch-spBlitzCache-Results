# Fetch spBlitzCache Results
Wrapper for collecting spBlitzCache results

## Requirements
* spBlitzCache - https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit
* SQL Server 2016 RTM (or a string_slpit() equivalent function)

## Functionality
### Parameters
* @Top INT (default: 5)
  * The top N results per each '@SortOrder'
* @DatabaseList VARCHAR(200) (default: NULL)
  * An inclusive list of databases 
    * If NULL @Top N per server
* @SortOrder VARCHAR(200) (default: 'CPU')
  * An inclusive list of @SortOrder's 
    * If NULL @SorderOrder = 'CPU' only
* @MinutesBack INT (default: -60)
  * The minutes back which to look through cache
* @Help BIT (default = NULL)
  * If @Help = 1 spBlitzCache's help will be executed

### Note(s):
* For a list of @SortOrder or anything related to spBlitzCache 
  * EXEC spBlitzCache @Help = 1

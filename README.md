# Fetch spBlitzCache Results
A wrapper for collecting and persisting the top N spBlitzCache results per server or per database

## Requirements
* [spBlitzCache](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit) 
* SQL Server 2016 RTM (or a string_slpit() equivalent)
* Utility database

## Functionality
### Parameters
* @Top INT (default: 5)
  * The top N results per each '@SortOrder'
* @DatabaseList VARCHAR(200) (default: NULL)
  * An inclusive list of databases 
    * If NULL then the @Top N *per server* versus *per database*
* @SortOrder VARCHAR(200) (default: 'CPU')
  * An inclusive list of @SortOrder's 
    * If NULL then @SorderOrder = 'CPU' only
* @MinutesBack INT (default: -60)
  * The minutes back which to look through cache
* @Help BIT (default = NULL)
  * If @Help = 1 spBlitzCache's help will be executed

### Gist
* Dynamic SQL 
* Basic error checking
* Adjustments to OOTB spBlitzCache tables
* Each @SortOrder creates two tables
  * spBlitzCache_Results_CPU
    * upserted table from Stage which persists the output of spBlitzCache
  * spBlitzCache_Results_CPU_Stage
    * truncated staging table which temporarily holds the output of spBlitzCache

### Example Usage
* The Top 10 CPU and Reads queries of the past sixty minutes for the entire server
  * `EXEC usp_fetch_spBlitzCache_Results @Top = 10, @SortOrder = 'CPU, Reads'`
* The Top 15 CPU, Reads, and Writes queries of the past thirty minutes per database
  * `EXEC usp_fetch_spBlitzCache_Results @Top = 15, @DatabaseList = 'myDatabase, theDatabase, db1', @SortOrder = 'CPU, Reads, Writes', @MinutesBack = -30`
 
### Note(s)
* Replace [¿] with your database name
* Create a job calling the sproc on a schedule which fits your need
  * If the schedule is **NOT** hourly be sure to adjust @MinutesBack accordingly 
* For a list of @SortOrder or anything related to spBlitzCache 
  * `EXEC spBlitzCache @Help = 1`

# Fetch spBlitzCache Results
Wrapper for collecting spBlitzCache results

Requirements:
spBlitzCache - https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit
SQL Server 2016 RTM (or a string_slpit() equivalent function)

Functionality:
Parameters
@Top INT (default: 5)
@DatabaseList VARCHAR(200) (default: NULL)
@SortOrder VARCHAR(200) (default: 'CPU')
@MinutesBack INT (default: -60)
@Help BIT (default = NULL)

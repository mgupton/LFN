# Log File Normalizer
Log File Normalizer (LFN) is a Windows Powershell implemented solution that consumes log records from one or more files that match a regex file glob and outputs the data to another file with a file naming scheme that may be consumed by the Alert Logic log management solution.

In particular, this script overcomes the limitations with the flat-file collector only supporting a limited number of file rotation and file naming schemes. In addition, the script will convert Unicode encoded (UTF-8, UTF-16 etc) files to ASCII. 


For example, if the original file is `access.log` the output file could be specified as `access_normalized.log`. And the script would output the current log file to `access_nornalized.log`. When the output log file reaches a certain size limit the script will archive the file using the scheme `<log file base name>_YYYYMMDD_HHMMSS.<original file extension>`. A specific example of this would be, `access_normalized_20181206_120000.log`.


The archive file naming scheme is `<log file base name>_YYYYMMDD_HHMMSS.<original file extension>`. Where YYYYMMDD is a four digit year, two digit month and two digit day. And HHMMSS is a two digit hour, two digit minute and two digit second.

# Usage
### Example of running the script from a Windows command line to normalize MS SQL Server error logs.
MS SQL Server logs are usually Unicode encoded. The following example shows how to consume the logs and output them to a new file that is ASCII encoded.

```
C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\Log>dir errorlog*
 Volume in drive C is Windows
 Volume Serial Number is D88F-5BD2

 Directory of C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\Log

12/06/2018  11:21 AM           720,914 ERRORLOG
11/08/2018  03:12 PM         1,086,472 ERRORLOG.1
10/15/2018  05:58 PM           343,146 ERRORLOG.2
10/09/2018  06:10 PM            26,120 ERRORLOG.3
10/09/2018  06:10 PM                 0 ERRORLOG.4
               5 File(s)      2,176,652 bytes
               0 Dir(s)   6,494,998,528 bytes free
```

```
powershell -executionpolicy bypass -file lfn.ps1 -dir "$LOGPATH" -filePattern "errorlog*" -outputFile "$LOGPATH\errorlog_normalized.log"
```

### Examples that collect from a set of files matching the specified regex pattern.

```
# 
# Example of log files:
#
# error_20150929_095500.log
# error_20150929_105500.log
#
#
# Example command line for running the script from Powershell.
#
# lfn.ps1 -dir "$LOGPATH" -filePattern "error_([2-9]\d{3}((0[1-9]|1[012])(0[1-9]|1\d|2[0-8])|(0[13456789]|1[012])(29|30)|(0[13578]|1[02])31)|(([2-9]\d)(0[48]|[2468][048]|[13579][26])|(([2468][048]|[3579][26])00))0229)_([01]\d|2[0123])([0-5]\d){2}\.log" -outputFile "$LOGPATH\normalized.log"
```
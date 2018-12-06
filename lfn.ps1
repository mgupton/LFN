
#
# Written by: Michael Gupton
# mg@bitpile.me
# Date created: 10/6/2015
#

#
# lfn.ps1
#
# Log File Normalizer (LFN) consumes log files in one form and outputs them in another form.
# The purpose of this to transform the files into a form that meets the requirements of
# other solutions that need to consume the log data.
#
# This script has the following functionality.
#
#   - Reads lines of log records from a set of files that use one naming scheme and
#     outputs them to a set of files that uses another scheme.
#   - Reads Unicode encoded (UTF-8, UTC-16 etc) text and outputs ASCII text.
#

#
# This script takes three arguments:
#
# -dir is the target directory where the original (source) log files reside.
# -filePattern is the regex that specifies the file pattern for matching the source log files.
# -outputFile is the path and file name for the output file for the log data.
#
# 
# Example of collecting from files matching errorlog* by running the script from a Windows command line.
#
#
# powershell -executionpolicy bypass -file lfn.ps1 -dir "$LOGPATH" -filePattern "errorlog*" -outputFile "$LOGPATH\error_normalized.log"
#
#
Param(
     [Parameter(Mandatory=$true)][string]$dir  = "",
     [Parameter(Mandatory=$true)][string]$outputFile  = "",
     [Parameter(Mandatory=$true)][string]$filePattern = ""
)

#
# List files in the specified directory in descending ordered by last modified date-time.
#
function ListFilesEx($dir, $glob)
{
     
    $files_ex = @()
   
    $files = Get-ChildItem $dir | Where-Object {$_.Name -match $glob} | Select Name, LastWriteTime
    
    foreach ($file in $files)
    {
        $fileinfo = New-Object PSObject
        
        $fileinfo | Add-member -membertype noteproperty -name Filename -value $($file.Name)
        $fileinfo | Add-member -membertype noteproperty -name LastModifiedTime -value $($file.LastWriteTime) 

        $files_ex += $fileinfo
    }

    # $files_ex = $files_ex.GetEnumerator() | sort -property Filename -descending
    # $files_ex = $files_ex.GetEnumerator() | select Filename, LastModifiedTime  | sort -property LastModifiedTime -descending
    
    $files_ex = $files_ex.GetEnumerator() | sort -property LastModifiedTime -descending
        
    return $files_ex
}

function GetEOF($sourceFile)
{
    $source = new-object System.IO.StreamReader(New-Object IO.FileStream($sourceFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [IO.FileShare]::ReadWrite))
    
    # $source.BaseStream.Seek(0, [System.IO.SeekOrigin]::End) | out-null
    
    return $source.ReadToEnd().Length
}

#
# Read all lines from the position $pos until EOF and output each line to the output file.
#
function ReadAndOutput($sourceFile, $pos, $outputFile)
{
    $source = new-object System.IO.StreamReader(New-Object IO.FileStream($sourceFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [IO.FileShare]::ReadWrite))
    
    $source.BaseStream.Seek($pos, [System.IO.SeekOrigin]::Begin) | out-null
    
    $output = new-object System.IO.StreamWriter((new-object IO.FileStream($outputFile, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)), [System.Text.Encoding]::ASCII)
    
    $output.AutoFlush = $true
    
    Write-Host "$(Get-Date), Reading file: $sourceFile starting at position $pos."
    
    while (($line = $source.ReadLine()) -ne $null)
    {
        if ($line -ne "")
        {
            Write-Host "$(Get-Date), Outputting: $line"
            $output.WriteLine($line)
        }
    }
 
    $last_read_pos = $source.BaseStream.Position

    $source.Close()
    $output.Close()
    
    return $last_read_pos
}

#
# Remove extra archive files so there are never more than the specified limit. The oldest archives are removed until
# there are only the N most recent archive files.
# 
function RemoveExtraArchives($dir, $glob)
{
    $max_archives = 10
    
    $file_info = @(ListFilesEx $dir $glob)
   
   if ($file_info.Length -gt $max_archives)
   {               
        for ($i = $file_info.Length - 1; $i -gt ($max_archives - 1); $i--)
        {
            Remove-Item ($dir + "\" + $file_info[$i].Filename)
        }
   }
}

#
# Archive the file once it reaches a certain size.
#
# The archive file name will have the form <basename of output file>_YYYYMMDD_hhmmss.<ext>
#
function ArchiveLog($file)
{
    $curr_time = Get-Date
    
# Format time using the 24 hour format.     
    $timestamp = $curr_time.ToString("yyyyMMdd") + "_" + $curr_time.ToString("HHmmss")
    
    $archive_file = [System.IO.Path]::GetFileNameWithoutExtension($file) + "_" + $timestamp + [System.IO.Path]::GetExtension($file)
    
    if ((Test-Path $file) -and ((Get-Item $file).length -ge 100kb))
    {
        Rename-Item $file $archive_file
    }
# 
# Example file and regex:   
# error_20151013_073300.log    
# error_\d{4}\d{2}\d{2}_[0-2]\d[0-5]\d[0-5]\d\.log    
#
    $glob = [System.IO.Path]::GetFileNameWithoutExtension($file) + "_\d{4}\d{2}\d{2}_[0-2]\d[0-5]\d[0-5]\d" + [System.IO.Path]::GetExtension($file)
    
    RemoveExtraArchives $([System.IO.Path]::GetDirectoryName($file)) $glob
}

# Last log file being read.
$last_log = ""

# Last position in the file read.
$last_pos = 0

while ($true)
{
   
    Write-host "$(Get-Date), Running..."

# Single element arrays are weird in Powershell, so the return value needs to be explicitly "cast"
# as an array.
    $file_info = @(ListFilesEx $dir $filePattern)

#
# If the most recent file is not the last file read then a new
# file has been detected. Seek to the end of the file to begin
# collection from there.
#     
    if ($file_info.Length -ne 0 -and $file_info[0].Filename -ne $last_log)
    {
        #
        # Read the last records from the previous current log before
        # moving on.        
        # 
        if ($last_log -ne "")
        {
            ReadAndOutput ($dir + "\" + $last_log) $last_pos $outputFile
        }
        
        Write-Host "$(Get-Date), New log file detected: $($file_info[0].Filename)"
        
        $last_log = $file_info[0].Filename        
        $last_pos = GetEOF($dir + "\" + $last_log)
    }
    else
    {
        $last_pos = ReadAndOutput ($dir + "\" + $last_log) $last_pos $outputFile
    }
	
#
# Archive the output file once it reaches a certain size.
#    
    ArchiveLog($outputFile)
    
    sleep -m 15000
}






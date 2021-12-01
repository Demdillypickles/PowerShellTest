function Test-CloudFlare {
    <#
    .SYNOPSIS
    Execute a connection test on a remote computer.
    .DESCRIPTION
    The user is prompted to supply a computer name or IP address to create a remote session.
    The remote session is then used to perform a connection test to 'one.one.one.one'.
    After the connection test finishes, the results are retreived and ouput in the format specified.
    .PARAMETER ComputerName
    A string, or list of strings, used to identify the computer to create a remote session with.
    This is a REQUIRED parameter.
    .PARAMETER Path
    A path string that specifies the working directory for the script.
    The default is the current users home directory.
    .PARAMETER Output
    Used to select the format of the output. The acceptable strings are:
        - Host ([DEFAULT]Writes to the console screen.)
        - CSV (Writes output to a .csv file)
        - Text (Writes output to a .txt file)
    .Example
    Test-CloudFlare -ComputerName 192.168.0.1

    DEFAULT USAGE
    This is the basic usage. -ComputerName is the only required variable.
    By default, -Output will be 'Host' which causes the results to be printed on the screen.
    .EXAMPLE
    Test-CloudFlare -ComputerName 192.168.0.1 -Output 'Text'

    CREATING A .txt FILE
    Setting -Output to 'Text' will create a .txt file and then open it in Notepad.
    .EXAMPLE
    Test-CloudFlare -ComputerName 192.168.0.1 -Output 'CSV'

    CREATING A .CSV FILE
    Setting -Output to 'CSV' will create a .csv file. You can then view it with the application of your choice.
    .EXAMPLE
    Test-CloudFlare -ComputerName 192.168.0.1 -Output 'CSV' -Path "$env:USERPROFILE\Desktop"

    CHOOSING THE LOCATION OF THE OUTPUT FILE
    Using the -Path parameter allows you to specify the location of the output file.
    This works with -Output being either 'Text' or 'CSV'.
    When -Path is ommitted, it defaults to the users home directory.
    .NOTES
    Author: Dylan Martin
    Last Edit: 2021-11-12
    Version 1.2 - Added simple error handling for opening remote sessions.
    #>
    [CmdletBinding()]
    param (
        # used to select computer for remote session
        [Parameter(
            ValueFromPipeline=$True,
            Mandatory=$true
        )]
        [Alias('CN', 'Name')]
        [string[]]$ComputerName,

        # path string used to set working directory. Defaults to user directory.
        $Path = $env:USERPROFILE,
    
        # controls how the output is created. Default prints to screen.
        [ValidateSet ('Host', 'CSV', 'Text')]
        [string]$Output = 'Host'

    )  # param
    
    begin {}  # EMPTY
    
    process {
        # keep an index of the loop to use as a unique way to name files.
        # this allows multiple log files to be generated when $ComputerName is a list.
        $loop_index = 1
        ForEach ($remote_com in $ComputerName) {
            # create and enter remote session
            Try {
                $session_params = @{
                    'ComputerName' = $remote_com
                    'ErrorAction' = 'Stop'
                }
                $session = New-PSSession @session_params
                Enter-PSSession $session
            }
            Catch {
                Write-Host "Remote connection to $remote_com failed." -ForegroundColor 'red'
                # break current iteration of the loop since remote session could not be made
                Continue
            }

            # Timestamp for log file
            $DateTime = Get-Date
            # Perform ping test and extract key data points
            $TestCF = Test-NetConnection 'one.one.one.one' -InformationLevel Detailed
            
            # Create object with key data as properties
            $OBJ = [PSCustomObject]@{
                'ComputerName' = "$remote_com"
                'PingSuccess' = $TestCF.PingSucceeded
                'NameResolve' = $TestCF.NameResolutionSucceeded
                'ResolvedAddresses' = $TestCF.ResolvedAddresses
            }

            # exit and close the remote session
            Exit-PSSession
            Remove-PSSession $session

            # Create function output based on chosen mode
            Switch  -wildcard ($Output) {
                'Host' {
                    # Write the output to the screen
                    Write-Verbose "Outputting results to screen"
                    $OBJ | Format-List | Out-Default
                }
            
                'CSV' {
                    # Create file path
                    $file_name = "$Path\JobResults$loop_index.csv"
                    Write-Verbose "Creating .csv file at $file_name"
                    # Create .csv file
                    $OBJ | Export-Csv $file_name

                    # Open .csv file
                    Write-Verbose "Opening $file_name"
                    notepad.exe $file_name
                }
            
                'Text' {
                    # Create file paths
                    $temp_file_name = "$Path\TestResults.txt"
                    $file_name = "$Path\RemTestNet$loop_index.txt"
                    # Write data to temp file. List prevents excessive line length.
                    Write-Verbose "Creating temporary file."
                    $OBJ | Format-List | Out-File $temp_file_name
                    
                    # delete old file if it exists
                    if (Test-Path $file_name) {
                        Write-Verbose "Deleting old log file."
                        Remove-Item $file_name
                    }
                    
                    # create the log file with a header
                    Write-Verbose "Creating new log file at $file_name."
                    Add-Content -Path $file_name -Value (
                        "Computer Tested: $ComputerName",
                        "Timestamp: $DateTime",
                        (Get-Content $temp_file_name)
                    )

                    # Clean up temp file
                    Write-Verbose "Deleting temp file."
                    Remove-Item $temp_file_name

            
                    # open the file for viewing
                    Write-Verbose "Opening results"
                    notepad.exe $file_name
                }
            }  # Switch

            # increment the index before next loop
            $loop_index += 1

        }  # ForEach  
    }  # process
    
    end {}  # EMPTY
}

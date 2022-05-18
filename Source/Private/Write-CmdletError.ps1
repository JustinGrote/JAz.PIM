using namespace System.Management.Automation
function Write-CmdletError {
    param(
        [Exception]$Message = 'An Error Occured in the cmdlet',
        [String]$ErrorId,
        [ErrorCategory]$Category = 'InvalidOperation',
        $TargetObject = $PSItem,
        $cmdlet = $PSCmdlet,
        [Switch]$Terminating
    )
    process {
        $errorRecord = [ErrorRecord]::new(
            $Message,
            $ErrorId,
            $Category,
            $TargetObject
        )
        if ($Terminating) {
            $cmdlet.ThrowTerminatingError(
                $ErrorRecord
            )
        } else {
            $cmdlet.WriteError(
                $ErrorRecord
            )
        }
    }
}

using namespace System.Management.Automation
using namespace Microsoft.Graph.Powershell.Models
using namespace Microsoft.Graph.Powershell.Runtime
function Convert-GraphHttpException {
    [OutputType([Management.Automation.ErrorRecord])]
    param(
        [ErrorRecord]$errorRecord
    )
    <#
    .SYNOPSIS
    #HACK: This re-types the generic HttpResponseExceptions back to the specific ones, passes thru if nothing needs to be done
    #This can be removed once the actual cmdlet is available
    #>

    if ($errorRecord.Exception -isnot [Microsoft.Graph.PowerShell.Authentication.Helpers.HttpResponseException]) {
        return $errorRecord
    }

    $response = $errorRecord.Exception.Response
    $errMessage = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json | Select-Object -expand error
    $ioDataError = [IODataError]@{
        Error = @{
            Code    = $errMessage.code
            Message = $errMessage.message
        }
    }
    $exception = [RestException[IODataError]]::new($response, $ioDataError)
    $errorId = $ioDataError.Error.Code, $ioDataError.Error.Message -join ','

    #Generate new error record
    $errRecord = [ErrorRecord]::new(
        $exception,
        $errorId,
        'OperationStopped',
        $request
    )
    $errRecord.ErrorDetails = $ioDataError.Error.Code, $ioDataError.Error.Message -join ': '
    return $errRecord
}

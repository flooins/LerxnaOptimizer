# PSScriptAnalyzer settings used by the GitHub Actions lint job.
# Errors fail the build; warnings are shown as annotations only.
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'                       # it's an interactive console app - Write-Host is the point
        'PSUseApprovedVerbs'                          # friendly names like Parse-Selection are fine for a script
        'PSUseShouldProcessForStateChangingFunctions' # the script has its own preview mode and asks before changes
        'PSUseSingularNouns'
        'PSAvoidUsingEmptyCatchBlock'                 # optional checks deliberately ignore failures
        'PSUseBOMForUnicodeEncodedFile'               # files are plain ASCII
        'PSReviewUnusedParameter'
    )
}

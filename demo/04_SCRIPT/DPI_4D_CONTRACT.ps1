Set-StrictMode -Version Latest

$script:TopAllowed = @(
    'case_id','synthetic_fixture','as_of_date','source_ref','source_version','authority_ref','source_registry','cardinality',
    'worker_ref','job_role_id','risk_id','requirement_id','ppe_type_id','assigned_ppe','evidence_ref','validity','relations'
)
$script:NodeAllowed = @('value','source_ref','source_version','valid_from','valid_to','authority_ref')
$script:RelationsAllowed = @('worker_job_role','job_role_risk','risk_requirement','requirement_ppe','worker_ppe_assignment','assignment_evidence')
$script:RelationAllowed = @('from','to','status','source_ref','source_version','valid_from','valid_to','authority_ref')
$script:SourceAllowed = @('source_id','source_version','authority_ref','valid_from','valid_to')
$script:CardinalityAllowed = @('assignment_count','requirement_count')
$script:ConflictRepresentations = @('assignments','requirements','alternative_assignments','alternative_requirements')

function Get-P {
    param($Object,[string]$Name)
    if ($null -eq $Object) { return $null }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Get-RawP {
    param($Object,[string]$Name)
    if ($null -eq $Object) { return [pscustomobject]@{Exists=$false;Value=$null} }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p) { return [pscustomobject]@{Exists=$false;Value=$null} }
    return [pscustomobject]@{Exists=$true;Value=$p.Value}
}

function Test-Object {
    param($Value)
    return ($null -ne $Value -and $Value -is [pscustomobject])
}

function Test-StrictString {
    param($Value,[bool]$AllowEmpty=$false)
    if (-not ($Value -is [string])) { return $false }
    if (-not $AllowEmpty -and $Value.Length -eq 0) { return $false }
    if ($Value -cne $Value.Trim()) { return $false }
    return $true
}

function Test-StrictInteger {
    param($Value)
    return ($Value -is [int] -or $Value -is [long])
}

function Get-Unknown {
    param($Object,[string[]]$Allowed)
    $result = @()
    if (-not (Test-Object $Object)) { return $result }
    foreach ($p in $Object.PSObject.Properties) {
        if (-not ($Allowed -ccontains $p.Name)) { $result += $p.Name }
    }
    return @($result)
}

function Parse-Date {
    param($Value,[bool]$AllowEmpty=$false)
    if (-not (Test-StrictString $Value $AllowEmpty)) { return $null }
    if ($AllowEmpty -and $Value.Length -eq 0) { return [datetime]::MinValue }
    $d = [datetime]::MinValue
    $ok = [datetime]::TryParseExact(
        $Value,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None,[ref]$d
    )
    if (-not $ok) { return $null }
    return $d.Date
}

function Test-Interval {
    param($Object)
    $rawFrom = (Get-RawP $Object 'valid_from').Value
    $rawTo = (Get-RawP $Object 'valid_to').Value
    $from = Parse-Date $rawFrom
    $to = Parse-Date $rawTo $true
    if ($null -eq $from -or $null -eq $to) { return $false }
    if ($to -ne [datetime]::MinValue -and $from -gt $to) { return $false }
    return $true
}

function Test-ActiveAt {
    param($Object,[datetime]$AsOf)
    if (-not (Test-Interval $Object)) { return $false }
    $from = Parse-Date ((Get-RawP $Object 'valid_from').Value)
    $to = Parse-Date ((Get-RawP $Object 'valid_to').Value) $true
    if ($from -gt $AsOf) { return $false }
    if ($to -ne [datetime]::MinValue -and $to -lt $AsOf) { return $false }
    return $true
}

function New-Decision {
    param(
        $InputObject,[string]$Decision,[string]$ReasonCode,[string]$Text,
        [string[]]$Missing=@(),[string]$Provenance='FAIL',[object[]]$Trace=@(),[string[]]$SourceRefs=@()
    )
    return [pscustomobject]@{
        ENGINE='DPI_4D_POSITIVE_CHAIN_MINIMUM'
        CONTRACT_VERSION='DPI_4D_R2'
        CASE_ID=Get-P $InputObject 'case_id'
        DECISION=$Decision
        REASON_CODE=$ReasonCode
        REASON_TEXT_MINIMAL=$Text
        MISSING_LINKS=@($Missing)
        SOURCE_REFS=@($SourceRefs | Sort-Object -Unique)
        PROVENANCE=$Provenance
        DOMAIN_INFERENCE='ZERO'
        PROVENANCE_TRACE=@($Trace)
    }
}

function Fail-Decision {
    param($InputObject,[string]$Reason,[string]$Text,[string[]]$Missing=@())
    return New-Decision $InputObject 'NON_VERIFICATO' $Reason $Text $Missing 'FAIL'
}

function Build-Registry {
    param($InputObject,[datetime]$AsOf)

    $rawRegistry = Get-RawP $InputObject 'source_registry'
    if (-not $rawRegistry.Exists -or $null -eq $rawRegistry.Value) {
        return [pscustomobject]@{Ok=$false;Reason='SOURCE_NOT_BOUND';Text='source_registry mancante.';Map=$null}
    }
    if (-not ($rawRegistry.Value -is [System.Array])) {
        return [pscustomobject]@{Ok=$false;Reason='SCHEMA_TYPE_INVALID';Text='source_registry deve essere JSON array.';Map=$null}
    }
    $items = @($rawRegistry.Value)
    if ($items.Count -eq 0) {
        return [pscustomobject]@{Ok=$false;Reason='SOURCE_NOT_BOUND';Text='source_registry vuoto.';Map=$null}
    }

    $map = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($source in $items) {
        if (-not (Test-Object $source)) {
            return [pscustomobject]@{Ok=$false;Reason='SCHEMA_TYPE_INVALID';Text='Elemento source_registry non-oggetto.';Map=$null}
        }
        $unknown = @(Get-Unknown $source $script:SourceAllowed)
        if ($unknown.Count -gt 0) {
            return [pscustomobject]@{Ok=$false;Reason='SCHEMA_UNKNOWN_FIELD';Text=('Campo source_registry ignoto: '+($unknown -join ','));Map=$null}
        }
        foreach ($field in @('source_id','source_version','authority_ref')) {
            if (-not (Test-StrictString ((Get-RawP $source $field).Value))) {
                return [pscustomobject]@{Ok=$false;Reason='SCHEMA_TYPE_INVALID';Text=('Campo source_registry non strict: '+$field);Map=$null}
            }
        }
        if (-not (Test-Interval $source)) {
            return [pscustomobject]@{Ok=$false;Reason='VALIDITY_CONTRADICTION';Text='Intervallo source_registry invalido.';Map=$null}
        }
        if (-not (Test-ActiveAt $source $AsOf)) {
            return [pscustomobject]@{Ok=$false;Reason='VALIDITY_CONTRADICTION';Text='Sorgente non valida ad AS_OF_DATE.';Map=$null}
        }
        $id = Get-P $source 'source_id'
        if ($map.ContainsKey($id)) {
            return [pscustomobject]@{Ok=$false;Reason='SOURCE_CONFLICT';Text=('source_id duplicato: '+$id);Map=$null}
        }
        $map.Add($id,$source)
    }
    return [pscustomobject]@{Ok=$true;Reason='';Text='';Map=$map}
}

function Check-Binding {
    param($Object,$Registry,[bool]$AuthorityRequired=$true)

    foreach ($field in @('source_ref','source_version')) {
        if (-not (Test-StrictString ((Get-RawP $Object $field).Value))) {
            return [pscustomobject]@{Ok=$false;Reason='SCHEMA_TYPE_INVALID';Text=('Provenance non strict: '+$field)}
        }
    }
    $authority = (Get-RawP $Object 'authority_ref').Value
    if ($AuthorityRequired -and -not (Test-StrictString $authority)) {
        return [pscustomobject]@{Ok=$false;Reason='SCHEMA_TYPE_INVALID';Text='authority_ref non strict.'}
    }
    $ref = Get-P $Object 'source_ref'
    if (-not $Registry.ContainsKey($ref)) {
        return [pscustomobject]@{Ok=$false;Reason='SOURCE_NOT_BOUND';Text=('source_ref non registrato: '+$ref)}
    }
    $registered = $Registry[$ref]
    if ((Get-P $Object 'source_version') -cne (Get-P $registered 'source_version')) {
        return [pscustomobject]@{Ok=$false;Reason='SOURCE_VERSION_CONFLICT';Text=('Versione sorgente discordante: '+$ref)}
    }
    if ($AuthorityRequired -and $authority -cne (Get-P $registered 'authority_ref')) {
        return [pscustomobject]@{Ok=$false;Reason='SOURCE_AUTHORITY_CONFLICT';Text=('Autorita sorgente discordante: '+$ref)}
    }
    return [pscustomobject]@{Ok=$true;Reason='';Text=''}
}

function Add-Trace {
    param([Collections.ArrayList]$Trace,[string]$Link,$Object,[string]$Value)
    [void]$Trace.Add([pscustomobject]@{
        LINK=$Link
        VALUE=$Value
        SOURCE_REF=Get-P $Object 'source_ref'
        SOURCE_VERSION=Get-P $Object 'source_version'
        VALID_FROM=Get-P $Object 'valid_from'
        VALID_TO=Get-P $Object 'valid_to'
        AUTHORITY_REF=Get-P $Object 'authority_ref'
    })
}

function Invoke-Dpi4DDecision {
    param($InputObject)

    if (-not (Test-Object $InputObject)) {
        return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' 'Root JSON non-oggetto.' @('root')
    }

    foreach ($field in $script:ConflictRepresentations) {
        if ($null -ne $InputObject.PSObject.Properties[$field]) {
            return Fail-Decision $InputObject 'SCHEMA_CONFLICTING_REPRESENTATION' ('Rappresentazione concorrente: '+$field) @($field)
        }
    }

    $unknownTop = @(Get-Unknown $InputObject $script:TopAllowed)
    if ($unknownTop.Count -gt 0) {
        return Fail-Decision $InputObject 'SCHEMA_UNKNOWN_FIELD' ('Campo top-level ignoto: '+($unknownTop -join ',')) $unknownTop
    }

    foreach ($field in @('case_id','as_of_date','source_ref','source_version','authority_ref')) {
        if (-not (Test-StrictString ((Get-RawP $InputObject $field).Value))) {
            return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' ('Campo top-level non strict: '+$field) @($field)
        }
    }
    $synthetic = (Get-RawP $InputObject 'synthetic_fixture').Value
    if (-not ($synthetic -is [bool]) -or -not $synthetic) {
        return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' 'synthetic_fixture deve essere boolean true.' @('synthetic_fixture')
    }
    $asOf = Parse-Date ((Get-RawP $InputObject 'as_of_date').Value)
    if ($null -eq $asOf) {
        return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' 'AS_OF_DATE deve essere yyyy-MM-dd.' @('as_of_date')
    }

    $rawCardinality = Get-RawP $InputObject 'cardinality'
    if ($rawCardinality.Exists) {
        if (-not (Test-Object $rawCardinality.Value)) {
            return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' 'cardinality deve essere oggetto.' @('cardinality')
        }
        $unknownCardinality = @(Get-Unknown $rawCardinality.Value $script:CardinalityAllowed)
        if ($unknownCardinality.Count -gt 0) {
            return Fail-Decision $InputObject 'SCHEMA_UNKNOWN_FIELD' ('Campo cardinality ignoto: '+($unknownCardinality -join ',')) @('cardinality')
        }
        foreach ($field in $script:CardinalityAllowed) {
            $rawCount = Get-RawP $rawCardinality.Value $field
            if (-not $rawCount.Exists -or -not (Test-StrictInteger $rawCount.Value)) {
                return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' ('Cardinalita non intera strict: '+$field) @('cardinality')
            }
            if ($rawCount.Value -ne 1) {
                return Fail-Decision $InputObject 'CARDINALITY_UNSUPPORTED' ('4D Minimum richiede cardinalita 1: '+$field) @('cardinality')
            }
        }
    }

    $registryResult = Build-Registry $InputObject $asOf
    if (-not $registryResult.Ok) {
        return Fail-Decision $InputObject $registryResult.Reason $registryResult.Text @('source_registry')
    }
    $registry = $registryResult.Map

    $topBindingObject = [pscustomobject]@{
        source_ref=Get-P $InputObject 'source_ref'
        source_version=Get-P $InputObject 'source_version'
        authority_ref=Get-P $InputObject 'authority_ref'
    }
    $topBinding = Check-Binding $topBindingObject $registry $true
    if (-not $topBinding.Ok) {
        return Fail-Decision $InputObject $topBinding.Reason $topBinding.Text @('source_ref')
    }

    $nodeNames = @('worker_ref','job_role_id','risk_id','requirement_id','ppe_type_id','assigned_ppe','evidence_ref','validity')
    $nodes = @{}
    foreach ($name in $nodeNames) {
        $node = Get-P $InputObject $name
        if (-not (Test-Object $node)) {
            $reason = switch ($name) {
                'job_role_id' {'WORKER_JOB_ROLE_NOT_PROVEN'}
                'risk_id' {'JOB_ROLE_RISK_NOT_PROVEN'}
                'requirement_id' {'RISK_REQUIREMENT_NOT_PROVEN'}
                'evidence_ref' {'EVIDENCE_NOT_PROVEN'}
                'validity' {'VALIDITY_NOT_PROVEN'}
                default {'SCHEMA_TYPE_INVALID'}
            }
            return Fail-Decision $InputObject $reason ('Nodo mancante/non-oggetto: '+$name) @($name)
        }
        $unknown = @(Get-Unknown $node $script:NodeAllowed)
        if ($unknown.Count -gt 0) {
            return Fail-Decision $InputObject 'SCHEMA_UNKNOWN_FIELD' ('Campo nodo ignoto in '+$name+': '+($unknown -join ',')) @($name)
        }
        foreach ($field in @('value','source_ref','source_version','authority_ref')) {
            if (-not (Test-StrictString ((Get-RawP $node $field).Value))) {
                return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' ('Campo nodo non strict: '+$name+'.'+$field) @($name)
            }
        }
        if (-not (Test-Interval $node)) {
            return Fail-Decision $InputObject 'VALIDITY_CONTRADICTION' ('Intervallo nodo invalido: '+$name) @($name)
        }
        $binding = Check-Binding $node $registry $true
        if (-not $binding.Ok) { return Fail-Decision $InputObject $binding.Reason $binding.Text @($name) }
        $nodes[$name] = $node
    }

    $relations = Get-P $InputObject 'relations'
    if (-not (Test-Object $relations)) {
        return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' 'relations deve essere oggetto.' @('relations')
    }
    $unknownRelations = @(Get-Unknown $relations $script:RelationsAllowed)
    if ($unknownRelations.Count -gt 0) {
        return Fail-Decision $InputObject 'SCHEMA_UNKNOWN_FIELD' ('Relazione ignota: '+($unknownRelations -join ',')) @('relations')
    }

    $relMap = @{}
    foreach ($name in $script:RelationsAllowed) {
        $rel = Get-P $relations $name
        if (-not (Test-Object $rel)) {
            $reason = switch ($name) {
                'worker_job_role' {'WORKER_JOB_ROLE_NOT_PROVEN'}
                'job_role_risk' {'JOB_ROLE_RISK_NOT_PROVEN'}
                'risk_requirement' {'RISK_REQUIREMENT_NOT_PROVEN'}
                'requirement_ppe' {'REQUIREMENT_PPE_NOT_PROVEN'}
                'worker_ppe_assignment' {'ASSIGNMENT_NOT_PROVEN'}
                'assignment_evidence' {'EVIDENCE_NOT_PROVEN'}
            }
            return Fail-Decision $InputObject $reason ('Relazione mancante: '+$name) @($name)
        }
        $unknown = @(Get-Unknown $rel $script:RelationAllowed)
        if ($unknown.Count -gt 0) {
            return Fail-Decision $InputObject 'SCHEMA_UNKNOWN_FIELD' ('Campo relazione ignoto in '+$name+': '+($unknown -join ',')) @($name)
        }
        foreach ($field in @('from','to','source_ref','source_version','authority_ref')) {
            if (-not (Test-StrictString ((Get-RawP $rel $field).Value))) {
                return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' ('Campo relazione non strict: '+$name+'.'+$field) @($name)
            }
        }
        $rawStatus = Get-RawP $rel 'status'
        if ($rawStatus.Exists -and -not (Test-StrictString $rawStatus.Value $true)) {
            return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' ('Status relazione non strict: '+$name) @($name)
        }
        if ($rawStatus.Exists -and $rawStatus.Value.Length -gt 0 -and -not ($name -ceq 'worker_ppe_assignment' -or $name -ceq 'assignment_evidence')) {
            return Fail-Decision $InputObject 'RELATION_STATUS_UNSUPPORTED' ('Status non supportato sulla relazione: '+$name) @($name)
        }
        if (-not (Test-Interval $rel)) {
            return Fail-Decision $InputObject 'VALIDITY_CONTRADICTION' ('Intervallo relazione invalido: '+$name) @($name)
        }
        $binding = Check-Binding $rel $registry $true
        if (-not $binding.Ok) { return Fail-Decision $InputObject $binding.Reason $binding.Text @($name) }
        $relMap[$name] = $rel
    }

    $worker = Get-P $nodes['worker_ref'] 'value'
    $role = Get-P $nodes['job_role_id'] 'value'
    $risk = Get-P $nodes['risk_id'] 'value'
    $requirement = Get-P $nodes['requirement_id'] 'value'
    $ppe = Get-P $nodes['ppe_type_id'] 'value'
    $assignment = Get-P $nodes['assigned_ppe'] 'value'
    $evidence = Get-P $nodes['evidence_ref'] 'value'
    $validity = Get-P $nodes['validity'] 'value'

    $expected = @{
        worker_job_role=@($worker,$role)
        job_role_risk=@($role,$risk)
        risk_requirement=@($risk,$requirement)
        requirement_ppe=@($requirement,$ppe)
        worker_ppe_assignment=@($worker,$ppe)
        assignment_evidence=@($ppe,$evidence)
    }
    foreach ($name in $script:RelationsAllowed) {
        $rel = $relMap[$name]
        $actualFrom = Get-P $rel 'from'
        $actualTo = Get-P $rel 'to'
        $expectedFrom = $expected[$name][0]
        $expectedTo = $expected[$name][1]
        if ($actualFrom -cne $expectedFrom -or $actualTo -cne $expectedTo) {
            $caseOnlyMismatch =
                (($actualFrom -cne $expectedFrom) -and [string]::Equals($actualFrom,$expectedFrom,[StringComparison]::OrdinalIgnoreCase)) -or
                (($actualTo -cne $expectedTo) -and [string]::Equals($actualTo,$expectedTo,[StringComparison]::OrdinalIgnoreCase))
            if ($caseOnlyMismatch) {
                return Fail-Decision $InputObject 'SCHEMA_TYPE_INVALID' ('Case mismatch relazione: '+$name) @($name)
            }
            return Fail-Decision $InputObject 'RELATION_CONTRADICTION' ('Endpoint relazione contraddittorio: '+$name) @($name)
        }
    }

    if (-not ($assignment -ceq 'ASSIGNED' -or $assignment -ceq 'NOT_ASSIGNED')) {
        return Fail-Decision $InputObject 'ASSIGNMENT_NOT_PROVEN' 'assigned_ppe deve essere ASSIGNED o NOT_ASSIGNED.' @('assigned_ppe')
    }
    if ((Get-P $relMap['worker_ppe_assignment'] 'status') -cne $assignment) {
        return Fail-Decision $InputObject 'RELATION_CONTRADICTION' 'Stato assignment node/relation contraddittorio.' @('worker_ppe_assignment')
    }
    if ((Get-P $relMap['assignment_evidence'] 'status') -cne 'PRESENT') {
        return Fail-Decision $InputObject 'EVIDENCE_NOT_PROVEN' 'assignment_evidence.status deve essere PRESENT.' @('assignment_evidence')
    }

    foreach ($name in @('worker_ref','job_role_id','risk_id','requirement_id','ppe_type_id','assigned_ppe','evidence_ref','validity')) {
        if (-not (Test-ActiveAt $nodes[$name] $asOf)) {
            return Fail-Decision $InputObject 'VALIDITY_CONTRADICTION' ('Nodo non coerente ad AS_OF_DATE: '+$name) @($name)
        }
    }
    foreach ($name in $script:RelationsAllowed) {
        if (-not (Test-ActiveAt $relMap[$name] $asOf)) {
            return Fail-Decision $InputObject 'VALIDITY_CONTRADICTION' ('Relazione non coerente ad AS_OF_DATE: '+$name) @($name)
        }
    }

    if (-not ($validity -ceq 'VALID' -or $validity -ceq 'INVALID' -or $validity -ceq 'EXPIRED')) {
        return Fail-Decision $InputObject 'VALIDITY_NOT_PROVEN' 'validity.value non ammesso.' @('validity')
    }
    $validFrom = Parse-Date ((Get-RawP $nodes['validity'] 'valid_from').Value)
    $validTo = Parse-Date ((Get-RawP $nodes['validity'] 'valid_to').Value) $true
    if ($validity -ceq 'VALID') {
        if ($validFrom -gt $asOf -or ($validTo -ne [datetime]::MinValue -and $validTo -lt $asOf)) {
            return Fail-Decision $InputObject 'VALIDITY_CONTRADICTION' 'VALID contraddice AS_OF_DATE e intervallo.' @('validity')
        }
    }
    if ($validity -ceq 'EXPIRED') {
        if ($validTo -eq [datetime]::MinValue -or $validTo -ge $asOf) {
            return Fail-Decision $InputObject 'VALIDITY_CONTRADICTION' 'EXPIRED richiede valid_to precedente ad AS_OF_DATE.' @('validity')
        }
    }

    $trace = [Collections.ArrayList]::new()
    $refs = [Collections.ArrayList]::new()
    foreach ($name in $nodeNames) {
        Add-Trace $trace $name $nodes[$name] ([string](Get-P $nodes[$name] 'value'))
        [void]$refs.Add((Get-P $nodes[$name] 'source_ref'))
    }
    foreach ($name in $script:RelationsAllowed) {
        $rel = $relMap[$name]
        $value = (Get-P $rel 'from')+'->'+(Get-P $rel 'to')
        $status = Get-P $rel 'status'
        if ($null -ne $status -and $status.Length -gt 0) { $value += ' ['+$status+']' }
        Add-Trace $trace $name $rel $value
        [void]$refs.Add((Get-P $rel 'source_ref'))
    }
    [void]$refs.Add((Get-P $InputObject 'source_ref'))

    if ($assignment -ceq 'NOT_ASSIGNED') {
        return New-Decision $InputObject 'GAP' 'REQUIRED_PPE_NOT_ASSIGNED' 'Requirement provato; DPI richiesto esplicitamente non assegnato.' @() 'SYNTHETIC_PROVENANCE_REFERENTIALLY_BOUND' @($trace) @($refs)
    }
    if ($validity -ceq 'INVALID' -or $validity -ceq 'EXPIRED') {
        return New-Decision $InputObject 'GAP' 'ASSIGNED_PPE_INVALID_OR_EXPIRED' 'Requirement e assegnazione provati; copertura esplicitamente invalida o scaduta.' @() 'SYNTHETIC_PROVENANCE_REFERENTIALLY_BOUND' @($trace) @($refs)
    }
    return New-Decision $InputObject 'COVERED' 'COVERED_COMPLETE_CHAIN' 'Catena completa, strict, temporalmente coerente e referenzialmente tracciabile.' @() 'SYNTHETIC_PROVENANCE_REFERENTIALLY_BOUND' @($trace) @($refs)
}

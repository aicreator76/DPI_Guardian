Set-StrictMode -Version Latest

$script:Dpi4DTopAllowed = @(
    'case_id','synthetic_fixture','as_of_date','source_ref','source_version','authority_ref','source_registry',
    'worker_ref','job_role_id','risk_id','requirement_id','ppe_type_id','assigned_ppe','evidence_ref','validity','relations'
)
$script:Dpi4DNodeAllowed = @('value','source_ref','source_version','valid_from','valid_to','authority_ref')
$script:Dpi4DRelationAllowed = @('from','to','status','source_ref','source_version','valid_from','valid_to','authority_ref')
$script:Dpi4DRelationsAllowed = @('worker_job_role','job_role_risk','risk_requirement','requirement_ppe','worker_ppe_assignment','assignment_evidence')
$script:Dpi4DSourceAllowed = @('source_id','source_version','authority_ref','valid_from','valid_to')
$script:Dpi4DConflictFields = @('assignments','requirements','alternative_assignments','alternative_requirements')

function Get-Dpi4DProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Test-Dpi4DExactString {
    param($Value, [bool]$AllowEmpty = $false)
    if (-not ($Value -is [string])) { return $false }
    if (-not $AllowEmpty -and $Value.Length -eq 0) { return $false }
    if ($Value -cne $Value.Trim()) { return $false }
    return $true
}

function Test-Dpi4DObject {
    param($Value)
    return ($null -ne $Value -and $Value -is [pscustomobject])
}

function Get-Dpi4DUnknownFields {
    param($Object, [string[]]$Allowed)
    if (-not (Test-Dpi4DObject $Object)) { return @() }
    $unknown = @()
    foreach ($p in $Object.PSObject.Properties) {
        if (-not ($Allowed -ccontains $p.Name)) { $unknown += $p.Name }
    }
    return @($unknown)
}

function Convert-Dpi4DDateStrict {
    param($Value, [bool]$AllowEmpty = $false)
    if (-not (Test-Dpi4DExactString $Value $AllowEmpty)) { return $null }
    if ($AllowEmpty -and $Value.Length -eq 0) { return [datetime]::MinValue }
    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParseExact(
        $Value,
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$parsed
    )
    if (-not $ok) { return $null }
    return $parsed.Date
}

function New-Dpi4DDecision {
    param(
        $InputObject,
        [string]$Decision,
        [string]$ReasonCode,
        [string]$ReasonText,
        [string[]]$MissingLinks = @(),
        [string]$Provenance = 'PARTIAL',
        [object[]]$Trace = @(),
        [string[]]$SourceRefs = @()
    )
    return [pscustomobject]@{
        ENGINE = 'DPI_4D_POSITIVE_CHAIN_MINIMUM'
        CONTRACT_VERSION = 'DPI_4D_R2'
        CASE_ID = Get-Dpi4DProperty $InputObject 'case_id'
        DECISION = $Decision
        REASON_CODE = $ReasonCode
        REASON_TEXT_MINIMAL = $ReasonText
        MISSING_LINKS = @($MissingLinks)
        SOURCE_REFS = @($SourceRefs | Sort-Object -Unique)
        PROVENANCE = $Provenance
        DOMAIN_INFERENCE = 'ZERO'
        PROVENANCE_TRACE = @($Trace)
    }
}

function New-Dpi4DFail {
    param($InputObject,[string]$ReasonCode,[string]$ReasonText,[string[]]$MissingLinks=@(),[object[]]$Trace=@(),[string[]]$SourceRefs=@())
    return New-Dpi4DDecision $InputObject 'NON_VERIFICATO' $ReasonCode $ReasonText $MissingLinks 'FAIL' $Trace $SourceRefs
}

function Test-Dpi4DIntervalShape {
    param($Object)
    $fromRaw = Get-Dpi4DProperty $Object 'valid_from'
    $toRaw = Get-Dpi4DProperty $Object 'valid_to'
    if (-not (Test-Dpi4DExactString $fromRaw $false)) { return $false }
    if (-not (Test-Dpi4DExactString $toRaw $true)) { return $false }
    $from = Convert-Dpi4DDateStrict $fromRaw
    $to = Convert-Dpi4DDateStrict $toRaw $true
    if ($null -eq $from -or $null -eq $to) { return $false }
    if ($to -ne [datetime]::MinValue -and $from -gt $to) { return $false }
    return $true
}

function Test-Dpi4DActiveAt {
    param($Object,[datetime]$AsOf)
    if (-not (Test-Dpi4DIntervalShape $Object)) { return $false }
    $from = Convert-Dpi4DDateStrict (Get-Dpi4DProperty $Object 'valid_from')
    $to = Convert-Dpi4DDateStrict (Get-Dpi4DProperty $Object 'valid_to') $true
    if ($from -gt $AsOf) { return $false }
    if ($to -ne [datetime]::MinValue -and $to -lt $AsOf) { return $false }
    return $true
}

function New-Dpi4DSourceRegistry {
    param($InputObject,[datetime]$AsOf)
    $registryRaw = Get-Dpi4DProperty $InputObject 'source_registry'
    if ($null -eq $registryRaw -or -not ($registryRaw -is [System.Collections.IEnumerable]) -or ($registryRaw -is [string]) -or ($registryRaw -is [pscustomobject])) {
        return [pscustomobject]@{ Ok=$false; Reason='SOURCE_NOT_BOUND'; Text='source_registry mancante o non-array.'; Registry=$null }
    }
    $items = @($registryRaw)
    if ($items.Count -eq 0) {
        return [pscustomobject]@{ Ok=$false; Reason='SOURCE_NOT_BOUND'; Text='source_registry vuoto.'; Registry=$null }
    }
    $dict = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::Ordinal)
    foreach ($source in $items) {
        if (-not (Test-Dpi4DObject $source)) {
            return [pscustomobject]@{ Ok=$false; Reason='SCHEMA_TYPE_INVALID'; Text='source_registry contiene elemento non-oggetto.'; Registry=$null }
        }
        $unknown = @(Get-Dpi4DUnknownFields $source $script:Dpi4DSourceAllowed)
        if ($unknown.Count -gt 0) {
            return [pscustomobject]@{ Ok=$false; Reason='SCHEMA_UNKNOWN_FIELD'; Text=('Campo source_registry ignoto: '+($unknown -join ',')); Registry=$null }
        }
        foreach ($name in @('source_id','source_version','authority_ref')) {
            if (-not (Test-Dpi4DExactString (Get-Dpi4DProperty $source $name))) {
                return [pscustomobject]@{ Ok=$false; Reason='SCHEMA_TYPE_INVALID'; Text=("Campo sorgente non stringa strict: $name"); Registry=$null }
            }
        }
        if (-not (Test-Dpi4DIntervalShape $source)) {
            return [pscustomobject]@{ Ok=$false; Reason='VALIDITY_CONTRADICTION'; Text='Intervallo source_registry invalido.'; Registry=$null }
        }
        $sourceId = Get-Dpi4DProperty $source 'source_id'
        if ($dict.ContainsKey($sourceId)) {
            return [pscustomobject]@{ Ok=$false; Reason='SOURCE_CONFLICT'; Text=("source_id duplicato: $sourceId"); Registry=$null }
        }
        $dict.Add($sourceId,$source)
    }
    return [pscustomobject]@{ Ok=$true; Reason=''; Text=''; Registry=$dict }
}

function Test-Dpi4DSourceBinding {
    param($Object,$Registry,[bool]$AuthorityRequired=$true)
    foreach ($name in @('source_ref','source_version')) {
        if (-not (Test-Dpi4DExactString (Get-Dpi4DProperty $Object $name))) {
            return [pscustomobject]@{ Ok=$false; Reason='SCHEMA_TYPE_INVALID'; Text=("Provenance non strict: $name") }
        }
    }
    $authority = Get-Dpi4DProperty $Object 'authority_ref'
    if ($AuthorityRequired -and -not (Test-Dpi4DExactString $authority)) {
        return [pscustomobject]@{ Ok=$false; Reason='SCHEMA_TYPE_INVALID'; Text='authority_ref non strict.' }
    }
    $ref = Get-Dpi4DProperty $Object 'source_ref'
    if (-not $Registry.ContainsKey($ref)) {
        return [pscustomobject]@{ Ok=$false; Reason='SOURCE_NOT_BOUND'; Text=("source_ref non registrato: $ref") }
    }
    $source = $Registry[$ref]
    if ((Get-Dpi4DProperty $Object 'source_version') -cne (Get-Dpi4DProperty $source 'source_version')) {
        return [pscustomobject]@{ Ok=$false; Reason='SOURCE_VERSION_CONFLICT'; Text=("Versione sorgente discordante: $ref") }
    }
    if ($AuthorityRequired -and $authority -cne (Get-Dpi4DProperty $source 'authority_ref')) {
        return [pscustomobject]@{ Ok=$false; Reason='SOURCE_AUTHORITY_CONFLICT'; Text=("Autorita sorgente discordante: $ref") }
    }
    return [pscustomobject]@{ Ok=$true; Reason=''; Text='' }
}

function Add-Dpi4DTrace {
    param([System.Collections.ArrayList]$Trace,[string]$Link,$Object,[string]$Value)
    [void]$Trace.Add([pscustomobject]@{
        LINK=$Link
        VALUE=$Value
        SOURCE_REF=Get-Dpi4DProperty $Object 'source_ref'
        SOURCE_VERSION=Get-Dpi4DProperty $Object 'source_version'
        VALID_FROM=Get-Dpi4DProperty $Object 'valid_from'
        VALID_TO=Get-Dpi4DProperty $Object 'valid_to'
        AUTHORITY_REF=Get-Dpi4DProperty $Object 'authority_ref'
    })
}

function Invoke-Dpi4DDecision {
    param($InputObject)

    if (-not (Test-Dpi4DObject $InputObject)) {
        return New-Dpi4DFail $InputObject 'SCHEMA_TYPE_INVALID' 'Root JSON non-oggetto.' @('root')
    }

    foreach ($conflictName in $script:Dpi4DConflictFields) {
        if ($null -ne $InputObject.PSObject.Properties[$conflictName]) {
            return New-Dpi4DFail $InputObject 'SCHEMA_CONFLICTING_REPRESENTATION' ("Rappresentazione concorrente non supportata: $conflictName") @($conflictName)
        }
    }

    $topUnknown = @(Get-Dpi4DUnknownFields $InputObject $script:Dpi4DTopAllowed)
    if ($topUnknown.Count -gt 0) {
        return New-Dpi4DFail $InputObject 'SCHEMA_UNKNOWN_FIELD' ('Campo top-level ignoto: '+($topUnknown -join ',')) $topUnknown
    }

    foreach ($name in @('case_id','source_ref','source_version','authority_ref','as_of_date')) {
        if (-not (Test-Dpi4DExactString (Get-Dpi4DProperty $InputObject $name))) {
            return New-Dpi4DFail $InputObject 'SCHEMA_TYPE_INVALID' ("Campo top-level non stringa strict: $name") @($name)
        }
    }
    $synthetic = Get-Dpi4DProperty $InputObject 'synthetic_fixture'
    if (-not ($synthetic -is [bool]) -or -not $synthetic) {
        return New-Dpi4DFail $InputObject 'SCHEMA_TYPE_INVALID' 'synthetic_fixture deve essere boolean true in 4D R2.' @('synthetic_fixture')
    }
    $asOf = Convert-Dpi4DDateStrict (Get-Dpi4DProperty $InputObject 'as_of_date')
    if ($null -eq $asOf) {
        return New-Dpi4DFail $InputObject 'SCHEMA_TYPE_INVALID' 'AS_OF_DATE deve essere yyyy-MM-dd.' @('as_of_date')
    }

    $registryResult = New-Dpi4DSourceRegistry $InputObject $asOf
    if (-not $registryResult.Ok) {
        return New-Dpi4DFail $InputObject $registryResult.Reason $registryResult.Text @('source_registry')
    }
    $registry = $registryResult.Registry

    $topPseudo = [pscustomobject]@{
        source_ref=Get-Dpi4DProperty $InputObject 'source_ref'
        source_version=Get-Dpi4DProperty $InputObject 'source_version'
        authority_ref=Get-Dpi4DProperty $InputObject 'authority_ref'
    }
    $topBind = Test-Dpi4DSourceBinding $topPseudo $registry $true
    if (-not $topBind.Ok) { return New-Dpi4DFail $InputObject $topBind.Reason $topBind.Text @('source_ref') }

    $nodeNames = @('worker_ref','job_role_id','risk_id','requirement_id','ppe_type_id','assigned_ppe','evidence_ref','validity')
    $nodes = @{}
    foreach ($name in $nodeNames) {
        $node = Get-Dpi4DProperty $InputObject $name
        if (-not (Test-Dpi4DObject $node)) {
            $reason = switch ($name) {
                'job_role_id' {'WORKER_JOB_ROLE_NOT_PROVEN'}
                'risk_id' {'JOB_ROLE_RISK_NOT_PROVEN'}
                'requirement_id' {'RISK_REQUIREMENT_NOT_PROVEN'}
                'evidence_ref' {'EVIDENCE_NOT_PROVEN'}
                'validity' {'VALIDITY_NOT_PROVEN'}
                default {'SCHEMA_TYPE_INVALID'}
            }
            return New-Dpi4DFail $InputObject $reason ("Nodo mancante/non-oggetto: $name") @($name)
        }
        $unknown = @(Get-Dpi4DUnknownFields $node $script:Dpi4DNodeAllowed)
        if ($unknown.Count -gt 0) {
            return New-Dpi4DFail $InputObject 'SCHEMA_UNKNOWN_FIELD' ("Campo nodo ignoto in $name: "+($unknown -join ',')) @($name)
        }
        foreach ($field in @('value','source_ref','source_version','authority_ref')) {
            if (-not (Test-Dpi4DExactString (Get-Dpi4DProperty $node $field))) {
                return New-Dpi4DFail $InputObject 'SCHEMA_TYPE_INVALID' ("Campo nodo non stringa strict: $name.$field") @($name)
            }
        }
        if (-not (Test-Dpi4DIntervalShape $node)) {
            return New-Dpi4DFail $InputObject 'VALIDITY_CONTRADICTION' ("Intervallo nodo invalido: $name") @($name)
        }
        $bind = Test-Dpi4DSourceBinding $node $registry $true
        if (-not $bind.Ok) { return New-Dpi4DFail $InputObject $bind.Reason $bind.Text @($name) }
        $nodes[$name] = $node
    }

    $relations = Get-Dpi4DProperty $InputObject 'relations'
    if (-not (Test-Dpi4DObject $relations)) {
        return New-Dpi4DFail $InputObject 'SCHEMA_TYPE_INVALID' 'relations deve essere oggetto.' @('relations')
    }
    $relationsUnknown = @(Get-Dpi4DUnknownFields $relations $script:Dpi4DRelationsAllowed)
    if ($relationsUnknown.Count -gt 0) {
        return New-Dpi4DFail $InputObject 'SCHEMA_UNKNOWN_FIELD' ('Relazione ignota: '+($relationsUnknown -join ',')) @('relations')
    }

    $relMap = @{}
    foreach ($name in $script:Dpi4DRelationsAllowed) {
        $rel = Get-Dpi4DProperty $relations $name
        if (-not (Test-Dpi4DObject $rel)) {
            $reason = switch ($name) {
                'worker_job_role' {'WORKER_JOB_ROLE_NOT_PROVEN'}
                'job_role_risk' {'JOB_ROLE_RISK_NOT_PROVEN'}
                'risk_requirement' {'RISK_REQUIREMENT_NOT_PROVEN'}
                'requirement_ppe' {'REQUIREMENT_PPE_NOT_PROVEN'}
                'worker_ppe_assignment' {'ASSIGNMENT_NOT_PROVEN'}
                'assignment_evidence' {'EVIDENCE_NOT_PROVEN'}
            }
            return New-Dpi4DFail $InputObject $reason ("Relazione mancante: $name") @($name)
        }
        $unknown = @(Get-Dpi4DUnknownFields $rel $script:Dpi4DRelationAllowed)
        if ($unknown.Count -gt 0) {
            return New-Dpi4DFail $InputObject 'SCHEMA_UNKNOWN_FIELD' ("Campo relazione ignoto in $name: "+($unknown -join ',')) @($name)
        }
        foreach ($field in @('from','to','source_ref','source_version','authority_ref')) {
            if (-not (Test-Dpi4DExactString (Get-Dpi4DProperty $rel $field))) {
                return New-Dpi4DFail $InputObject 'SCHEMA_TYPE_INVALID' ("Campo relazione non stringa strict: $name.$field") @($name)
            }
        }
        $status = Get-Dpi4DProperty $rel 'status'
        if ($null -ne $status -and -not (Test-Dpi4DExactString $status $true)) {
            return New-Dpi4DFail $InputObject 'SCHEMA_TYPE_INVALID' ("Status relazione non stringa strict: $name") @($name)
        }
        if (-not (Test-Dpi4DIntervalShape $rel)) {
            return New-Dpi4DFail $InputObject 'VALIDITY_CONTRADICTION' ("Intervallo relazione invalido: $name") @($name)
        }
        $bind = Test-Dpi4DSourceBinding $rel $registry $true
        if (-not $bind.Ok) { return New-Dpi4DFail $InputObject $bind.Reason $bind.Text @($name) }
        $relMap[$name] = $rel
    }

    $worker = Get-Dpi4DProperty $nodes['worker_ref'] 'value'
    $role = Get-Dpi4DProperty $nodes['job_role_id'] 'value'
    $risk = Get-Dpi4DProperty $nodes['risk_id'] 'value'
    $requirement = Get-Dpi4DProperty $nodes['requirement_id'] 'value'
    $ppe = Get-Dpi4DProperty $nodes['ppe_type_id'] 'value'
    $evidence = Get-Dpi4DProperty $nodes['evidence_ref'] 'value'
    $assignmentState = Get-Dpi4DProperty $nodes['assigned_ppe'] 'value'
    $validityState = Get-Dpi4DProperty $nodes['validity'] 'value'

    $expected = @{
        worker_job_role=@($worker,$role)
        job_role_risk=@($role,$risk)
        risk_requirement=@($risk,$requirement)
        requirement_ppe=@($requirement,$ppe)
        worker_ppe_assignment=@($worker,$ppe)
        assignment_evidence=@($ppe,$evidence)
    }
    foreach ($name in $script:Dpi4DRelationsAllowed) {
        $rel = $relMap[$name]
        if ((Get-Dpi4DProperty $rel 'from') -cne $expected[$name][0] -or (Get-Dpi4DProperty $rel 'to') -cne $expected[$name][1]) {
            return New-Dpi4DFail $InputObject 'RELATION_CONTRADICTION' ("Endpoint relazione contraddittorio: $name") @($name)
        }
    }

    if (-not (($assignmentState -ceq 'ASSIGNED') -or ($assignmentState -ceq 'NOT_ASSIGNED'))) {
        return New-Dpi4DFail $InputObject 'ASSIGNMENT_NOT_PROVEN' 'assigned_ppe deve essere ASSIGNED o NOT_ASSIGNED.' @('assigned_ppe')
    }
    $assignmentRelStatus = Get-Dpi4DProperty $relMap['worker_ppe_assignment'] 'status'
    if ($assignmentRelStatus -cne $assignmentState) {
        return New-Dpi4DFail $InputObject 'RELATION_CONTRADICTION' 'Stato assignment node/relation contraddittorio.' @('worker_ppe_assignment')
    }
    if ((Get-Dpi4DProperty $relMap['assignment_evidence'] 'status') -cne 'PRESENT') {
        return New-Dpi4DFail $InputObject 'EVIDENCE_NOT_PROVEN' 'assignment_evidence.status deve essere PRESENT.' @('assignment_evidence')
    }

    foreach ($name in @('worker_ref','job_role_id','risk_id','requirement_id','ppe_type_id','assigned_ppe','evidence_ref')) {
        if (-not (Test-Dpi4DActiveAt $nodes[$name] $asOf)) {
            return New-Dpi4DFail $InputObject 'VALIDITY_CONTRADICTION' ("Nodo non temporalmente coerente ad AS_OF_DATE: $name") @($name)
        }
    }
    foreach ($name in $script:Dpi4DRelationsAllowed) {
        if (-not (Test-Dpi4DActiveAt $relMap[$name] $asOf)) {
            return New-Dpi4DFail $InputObject 'VALIDITY_CONTRADICTION' ("Relazione non temporalmente coerente ad AS_OF_DATE: $name") @($name)
        }
    }

    $validFrom = Convert-Dpi4DDateStrict (Get-Dpi4DProperty $nodes['validity'] 'valid_from')
    $validTo = Convert-Dpi4DDateStrict (Get-Dpi4DProperty $nodes['validity'] 'valid_to') $true
    if (-not ($validityState -ceq 'VALID' -or $validityState -ceq 'INVALID' -or $validityState -ceq 'EXPIRED')) {
        return New-Dpi4DFail $InputObject 'VALIDITY_NOT_PROVEN' 'validity.value non ammesso.' @('validity')
    }
    if ($validityState -ceq 'VALID') {
        if ($validFrom -gt $asOf -or ($validTo -ne [datetime]::MinValue -and $validTo -lt $asOf)) {
            return New-Dpi4DFail $InputObject 'VALIDITY_CONTRADICTION' 'VALID contraddice AS_OF_DATE e intervallo.' @('validity')
        }
    }
    if ($validityState -ceq 'EXPIRED') {
        if ($validTo -eq [datetime]::MinValue -or $validTo -ge $asOf) {
            return New-Dpi4DFail $InputObject 'VALIDITY_CONTRADICTION' 'EXPIRED richiede valid_to precedente ad AS_OF_DATE.' @('validity')
        }
    }

    $trace = [System.Collections.ArrayList]::new()
    $sourceRefs = [System.Collections.ArrayList]::new()
    foreach ($name in $nodeNames) {
        Add-Dpi4DTrace $trace $name $nodes[$name] ([string](Get-Dpi4DProperty $nodes[$name] 'value'))
        [void]$sourceRefs.Add((Get-Dpi4DProperty $nodes[$name] 'source_ref'))
    }
    foreach ($name in $script:Dpi4DRelationsAllowed) {
        $rel=$relMap[$name]
        $v=(Get-Dpi4DProperty $rel 'from')+'->'+(Get-Dpi4DProperty $rel 'to')
        $st=Get-Dpi4DProperty $rel 'status'; if ($null -ne $st -and $st.Length -gt 0) { $v += " [$st]" }
        Add-Dpi4DTrace $trace $name $rel $v
        [void]$sourceRefs.Add((Get-Dpi4DProperty $rel 'source_ref'))
    }
    [void]$sourceRefs.Add((Get-Dpi4DProperty $InputObject 'source_ref'))

    if ($assignmentState -ceq 'NOT_ASSIGNED') {
        return New-Dpi4DDecision $InputObject 'GAP' 'REQUIRED_PPE_NOT_ASSIGNED' 'Requirement provato; DPI richiesto esplicitamente non assegnato.' @() 'SYNTHETIC_PROVENANCE_REFERENTIALLY_BOUND' @($trace) @($sourceRefs)
    }
    if ($validityState -ceq 'INVALID' -or $validityState -ceq 'EXPIRED') {
        return New-Dpi4DDecision $InputObject 'GAP' 'ASSIGNED_PPE_INVALID_OR_EXPIRED' 'Requirement e assegnazione provati; copertura esplicitamente invalida o scaduta.' @() 'SYNTHETIC_PROVENANCE_REFERENTIALLY_BOUND' @($trace) @($sourceRefs)
    }
    return New-Dpi4DDecision $InputObject 'COVERED' 'COVERED_COMPLETE_CHAIN' 'Catena completa, strict, coerente, temporalmente valida e referenzialmente tracciabile.' @() 'SYNTHETIC_PROVENANCE_REFERENTIALLY_BOUND' @($trace) @($sourceRefs)
}

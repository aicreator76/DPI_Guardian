param(
    [ValidateSet('Full','OriginalRegression')]
    [string]$Mode = 'Full'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceRunner = Join-Path $RepoRoot 'demo\04_SCRIPT\DPI_GUARDIAN_RUN.ps1'
$SourceContract = Join-Path $RepoRoot 'demo\04_SCRIPT\DPI_4D_CONTRACT.ps1'
$Shell = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $Shell) { $Shell = (Get-Command powershell -ErrorAction Stop).Source }

$script:Pass = 0
$script:Fail = 0
$script:RuntimeExecutions = 0
$script:FalseCovered = 0
$script:FalseGap = 0

function Assert-Case {
    param([bool]$Condition,[string]$Name)
    if (-not $Condition) { $script:Fail++; throw "$Name=FAIL" }
    $script:Pass++
    Write-Host "$Name=PASS"
}

function New-Source {
    param([string]$Id='SRC_SYN',[string]$Version='v1',[string]$Authority='AUTH_SYN')
    return [ordered]@{
        source_id=$Id
        source_version=$Version
        authority_ref=$Authority
        valid_from='2026-01-01'
        valid_to=''
    }
}

function New-Node {
    param([object]$Value,[string]$ValidTo='')
    return [ordered]@{
        value=$Value
        source_ref='SRC_SYN'
        source_version='v1'
        valid_from='2026-01-01'
        valid_to=$ValidTo
        authority_ref='AUTH_SYN'
    }
}

function New-Relation {
    param([object]$From,[object]$To,[object]$Status='')
    return [ordered]@{
        from=$From
        to=$To
        status=$Status
        source_ref='SRC_SYN'
        source_version='v1'
        valid_from='2026-01-01'
        valid_to=''
        authority_ref='AUTH_SYN'
    }
}

function New-ValidCase {
    $worker='WORKER_SYN_001'; $role='JOB_ROLE_SYN_001'; $risk='RISK_SYN_001'; $req='REQ_SYN_001'; $ppe='PPE_SYN_001'; $evidence='EVIDENCE_SYN_001'
    return [ordered]@{
        case_id='CASE_A_POSITIVE_COVERED'
        synthetic_fixture=$true
        as_of_date='2026-06-01'
        source_ref='SRC_SYN'
        source_version='v1'
        authority_ref='AUTH_SYN'
        source_registry=@(New-Source)
        cardinality=[ordered]@{
            assignment_count=1
            requirement_count=1
        }
        worker_ref=New-Node $worker
        job_role_id=New-Node $role
        risk_id=New-Node $risk
        requirement_id=New-Node $req
        ppe_type_id=New-Node $ppe
        assigned_ppe=New-Node 'ASSIGNED'
        evidence_ref=New-Node $evidence
        validity=New-Node 'VALID'
        relations=[ordered]@{
            worker_job_role=New-Relation $worker $role
            job_role_risk=New-Relation $role $risk
            risk_requirement=New-Relation $risk $req
            requirement_ppe=New-Relation $req $ppe
            worker_ppe_assignment=New-Relation $worker $ppe 'ASSIGNED'
            assignment_evidence=New-Relation $ppe $evidence 'PRESENT'
        }
    }
}

function Invoke-Runtime {
    param($Case,[string]$Name,[bool]$AddSecondFile=$false)
    $sandbox=Join-Path ([IO.Path]::GetTempPath()) ('dpi4dr2_'+$Name+'_'+[guid]::NewGuid().ToString('N'))
    $demo=Join-Path $sandbox 'demo'; $scriptDir=Join-Path $demo '04_SCRIPT'; $inputDir=Join-Path $demo '01_DEMO_DATI'
    New-Item -ItemType Directory -Force -Path $scriptDir,$inputDir | Out-Null
    Copy-Item -LiteralPath $SourceRunner -Destination (Join-Path $scriptDir 'DPI_GUARDIAN_RUN.ps1')
    Copy-Item -LiteralPath $SourceContract -Destination (Join-Path $scriptDir 'DPI_4D_CONTRACT.ps1')
    $Case['case_id']=$Name
    $Case | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $inputDir 'DPI_4D_CHAIN.json') -Encoding UTF8
    if ($AddSecondFile) { 'synthetic' | Set-Content -LiteralPath (Join-Path $inputDir 'EXTRA.txt') -Encoding UTF8 }
    $stdout=Join-Path $sandbox 'stdout.txt'; $stderr=Join-Path $sandbox 'stderr.txt'
    $p=Start-Process -FilePath $Shell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $scriptDir 'DPI_GUARDIAN_RUN.ps1')) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $script:RuntimeExecutions++
    $decisionPath=Join-Path $demo '02_OUTPUT\DPI_4D_DECISION.json'
    $decision=if(Test-Path $decisionPath){Get-Content -LiteralPath $decisionPath -Raw|ConvertFrom-Json}else{$null}
    return [pscustomobject]@{Root=$sandbox;ExitCode=$p.ExitCode;Decision=$decision;Stdout=(Get-Content $stdout -Raw -ErrorAction SilentlyContinue);Stderr=(Get-Content $stderr -Raw -ErrorAction SilentlyContinue)}
}

function Remove-Runtime { param($Result) if($Result -and (Test-Path $Result.Root)){Remove-Item -LiteralPath $Result.Root -Recurse -Force} }

function Check-Decision {
    param($Case,[string]$Name,[string]$ExpectedDecision,[string]$ExpectedReason,[bool]$AddSecondFile=$false)
    $r=Invoke-Runtime $Case $Name $AddSecondFile
    try {
        $actualDecision=if($r.Decision){[string]$r.Decision.DECISION}else{'<NONE>'}
        $actualReason=if($r.Decision){[string]$r.Decision.REASON_CODE}else{'<NONE>'}
        if($ExpectedDecision -ne 'COVERED' -and $actualDecision -eq 'COVERED'){$script:FalseCovered++}
        if($ExpectedDecision -ne 'GAP' -and $actualDecision -eq 'GAP'){$script:FalseGap++}
        Assert-Case ($actualDecision -ceq $ExpectedDecision) ($Name+'_DECISION')
        if($ExpectedReason){Assert-Case ($actualReason -ceq $ExpectedReason) ($Name+'_REASON')}
        Write-Host ("ATTACK_RESULT ATTACK_ID={0} RUNTIME_EXECUTED=YES EXIT_CODE={1} DECISION={2} REASON_CODE={3} PASS=YES" -f $Name,$r.ExitCode,$actualDecision,$actualReason)
    } finally { Remove-Runtime $r }
}

# Original 4D semantics under hardened contract.
Check-Decision (New-ValidCase) 'T01_HAPPY_PATH' 'COVERED' 'COVERED_COMPLETE_CHAIN'
$c=New-ValidCase; $c['assigned_ppe']['value']='NOT_ASSIGNED'; $c['relations']['worker_ppe_assignment']['status']='NOT_ASSIGNED'
Check-Decision $c 'T02_TRUE_GAP' 'GAP' 'REQUIRED_PPE_NOT_ASSIGNED'
$c=New-ValidCase; $c['relations']['job_role_risk']=$null
Check-Decision $c 'T03_MAPPING_MISSING' 'NON_VERIFICATO' 'JOB_ROLE_RISK_NOT_PROVEN'
$c=New-ValidCase; $c['requirement_id']=$null
Check-Decision $c 'T04_REQUIREMENT_MISSING' 'NON_VERIFICATO' 'RISK_REQUIREMENT_NOT_PROVEN'
$c=New-ValidCase; $c['evidence_ref']=$null
Check-Decision $c 'T05_EVIDENCE_MISSING' 'NON_VERIFICATO' 'EVIDENCE_NOT_PROVEN'
$c=New-ValidCase; $c['validity']['value']='EXPIRED'; $c['validity']['valid_to']='2026-05-31'
Check-Decision $c 'T06_EXPIRED' 'GAP' 'ASSIGNED_PPE_INVALID_OR_EXPIRED'
$c=New-ValidCase; $c['department']='JOB_ROLE_SYN_001'
Check-Decision $c 'T07_UNKNOWN_FIELD' 'NON_VERIFICATO' 'SCHEMA_UNKNOWN_FIELD'
$c=New-ValidCase; $c['ppe_type_id']=$null
Check-Decision $c 'T08_PARTIAL_CHAIN' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
$c=New-ValidCase; $c['source_ref']=''
Check-Decision $c 'T09_SOURCE_REF_MISSING' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
$c=New-ValidCase
Check-Decision $c 'T09B_SECOND_INPUT_FILE' 'NON_VERIFICATO' 'CARDINALITY_UNSUPPORTED' $true

if($Mode -eq 'Full'){
    # PREDEFINED CLAUDE MATRIX frozen before the fix.
    $c=New-ValidCase; $c['unknown_top']='x'; Check-Decision $c 'A01_UNKNOWN_TOP' 'NON_VERIFICATO' 'SCHEMA_UNKNOWN_FIELD'
    $c=New-ValidCase; $c['worker_ref']['unknown_node']='x'; Check-Decision $c 'A02_UNKNOWN_NODE' 'NON_VERIFICATO' 'SCHEMA_UNKNOWN_FIELD'
    $c=New-ValidCase; $c['relations']['job_role_risk']['unknown_relation']='x'; Check-Decision $c 'A03_UNKNOWN_RELATION' 'NON_VERIFICATO' 'SCHEMA_UNKNOWN_FIELD'
    $c=New-ValidCase; $c['source_registry'][0]['unknown_source']='x'; Check-Decision $c 'A04_UNKNOWN_SOURCE' 'NON_VERIFICATO' 'SCHEMA_UNKNOWN_FIELD'
    $c=New-ValidCase; $c['worker_ref']['value']=$true; Check-Decision $c 'A05_BOOL_ID' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['risk_id']['value']=7; Check-Decision $c 'A06_INTEGER_ID' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['requirement_id']['value']=@('REQ_SYN_001'); Check-Decision $c 'A07_ARRAY_ID' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['ppe_type_id']['value']=[ordered]@{id='PPE_SYN_001'}; Check-Decision $c 'A08_OBJECT_ID' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['worker_ref']['value']=' WORKER_SYN_001'; Check-Decision $c 'A09_LEADING_WS' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['worker_ref']['source_ref']='SRC_SYN '; Check-Decision $c 'A10_TRAILING_WS' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['risk_id']['value']=''; Check-Decision $c 'A11_EMPTY_STRING' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['risk_id']['value']=$null; Check-Decision $c 'A12_NULL_ID' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['worker_ref']['source_ref']='SRC_ARBITRARY'; Check-Decision $c 'A13_ARBITRARY_SOURCE' 'NON_VERIFICATO' 'SOURCE_NOT_BOUND'
    $c=New-ValidCase; $c['source_registry']=$null; Check-Decision $c 'A14_REGISTRY_MISSING' 'NON_VERIFICATO' 'SOURCE_NOT_BOUND'
    $c=New-ValidCase; $c['worker_ref']['source_version']='v2'; Check-Decision $c 'A15_VERSION_MISMATCH' 'NON_VERIFICATO' 'SOURCE_VERSION_CONFLICT'
    $c=New-ValidCase; $c['worker_ref']['authority_ref']='OTHER_AUTH'; Check-Decision $c 'A16_AUTHORITY_MISMATCH' 'NON_VERIFICATO' 'SOURCE_AUTHORITY_CONFLICT'
    $c=New-ValidCase; $c['worker_ref']['valid_from']='2026-12-31'; $c['worker_ref']['valid_to']='2026-01-01'; Check-Decision $c 'A17_FROM_AFTER_TO' 'NON_VERIFICATO' 'VALIDITY_CONTRADICTION'
    $c=New-ValidCase; $c['validity']['value']='VALID'; $c['validity']['valid_to']='2026-05-31'; Check-Decision $c 'A18_VALID_DATE_CONTRADICTION' 'NON_VERIFICATO' 'VALIDITY_CONTRADICTION'
    $c=New-ValidCase; $c['validity']['value']='EXPIRED'; $c['validity']['valid_to']='2026-06-30'; Check-Decision $c 'A19_EXPIRED_DATE_CONTRADICTION' 'NON_VERIFICATO' 'VALIDITY_CONTRADICTION'
    $c=New-ValidCase; $c['assignments']=@($c['assigned_ppe']); Check-Decision $c 'A20_SECOND_ASSIGNMENT_REP' 'NON_VERIFICATO' 'SCHEMA_CONFLICTING_REPRESENTATION'
    $c=New-ValidCase; $c['requirements']=@($c['requirement_id']); Check-Decision $c 'A21_SECOND_REQUIREMENT_REP' 'NON_VERIFICATO' 'SCHEMA_CONFLICTING_REPRESENTATION'
    $c=New-ValidCase; $c['alternative_assignments']=@(); Check-Decision $c 'A22_ALT_ASSIGNMENT' 'NON_VERIFICATO' 'SCHEMA_CONFLICTING_REPRESENTATION'
    $c=New-ValidCase; $c['alternative_requirements']=@(); Check-Decision $c 'A23_ALT_REQUIREMENT' 'NON_VERIFICATO' 'SCHEMA_CONFLICTING_REPRESENTATION'
    $c=New-ValidCase; $c['relations']['job_role_risk']['from']='JOB_ROLE_SYN_DIFFERENT'; Check-Decision $c 'A24_RELATION_CONTRADICTION' 'NON_VERIFICATO' 'RELATION_CONTRADICTION'
    $c=New-ValidCase; $c['source_registry']=@((New-Source),(New-Source)); Check-Decision $c 'A25_DUPLICATE_SOURCE' 'NON_VERIFICATO' 'SOURCE_CONFLICT'
    $c=New-ValidCase; $s1=New-Source; $s2=New-Source; $s2['authority_ref']='OTHER'; $c['source_registry']=@($s1,$s2); Check-Decision $c 'A26_CONFLICTING_SOURCE' 'NON_VERIFICATO' 'SOURCE_CONFLICT'
    $c=New-ValidCase; $c['relations']['job_role_risk']['from']='job_role_syn_001'; Check-Decision $c 'A27_CASE_MISMATCH' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['second_assignment']=$c['assigned_ppe']; Check-Decision $c 'A28_HIDDEN_SECOND_ASSIGNMENT' 'NON_VERIFICATO' 'SCHEMA_UNKNOWN_FIELD'
    $c=New-ValidCase; $c['second_requirement']=$c['requirement_id']; Check-Decision $c 'A29_HIDDEN_SECOND_REQUIREMENT' 'NON_VERIFICATO' 'SCHEMA_UNKNOWN_FIELD'
    $c=New-ValidCase; $c['cardinality']['assignment_count']=2; Check-Decision $c 'A30_CARDINALITY_MARKER_GT1' 'NON_VERIFICATO' 'CARDINALITY_UNSUPPORTED'

    # CLAUDE blind attacks designed after implementation, not part of the frozen matrix.
    $c=New-ValidCase; $c['worker_ref']['source_ref']='src_syn'; Check-Decision $c 'B01_SOURCE_ID_CASE_MISMATCH' 'NON_VERIFICATO' 'SOURCE_NOT_BOUND'
    $c=New-ValidCase; $c['source_registry']=@($true); Check-Decision $c 'B02_REGISTRY_ELEMENT_BOOL' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['relations']['assignment_evidence']['status']=$true; Check-Decision $c 'B03_RELATION_STATUS_BOOL' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
    $c=New-ValidCase; $c['job_role_id']['valid_from']='2026-02-30'; Check-Decision $c 'B04_IMPOSSIBLE_DATE' 'NON_VERIFICATO' 'VALIDITY_CONTRADICTION'
    $c=New-ValidCase; $c['source_registry'][0]['authority_ref']=' AUTH_SYN'; Check-Decision $c 'B05_REGISTRY_AUTH_WHITESPACE' 'NON_VERIFICATO' 'SCHEMA_TYPE_INVALID'
}

# Historical 4C regression must execute the unchanged test suite against the candidate runner.
$regOut=Join-Path ([IO.Path]::GetTempPath()) ('dpi4c_r2_'+[guid]::NewGuid().ToString('N')+'.out')
$regErr=$regOut+'.err'
try {
    $reg=Start-Process -FilePath $Shell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $RepoRoot 'tests\dpi-4c-realinput-failclosed.ps1')) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $regOut -RedirectStandardError $regErr
    Assert-Case ($reg.ExitCode -eq 0) 'T10_4C_REGRESSION'
} finally { Remove-Item $regOut,$regErr -Force -ErrorAction SilentlyContinue }

Assert-Case ($script:FalseCovered -eq 0) 'FALSE_COVERED_INTERNAL_ZERO'
Assert-Case ($script:FalseGap -eq 0) 'FALSE_GAP_INTERNAL_ZERO'

Write-Host "R2_RUNTIME_EXECUTIONS=$script:RuntimeExecutions"
Write-Host "R2_ASSERTIONS_PASS=$script:Pass"
Write-Host "R2_FALSE_COVERED=$script:FalseCovered"
Write-Host "R2_FALSE_GAP=$script:FalseGap"
Write-Host "R2_MODE=$Mode"
if($Mode -eq 'Full'){
    Write-Host 'CLAUDE_PREDEFINED_ATTACKS=30/30_BLOCKED'
    Write-Host 'CLAUDE_NEW_BLIND_ATTACKS=5/5_BLOCKED'
}
Write-Host 'DPI_4D_R2_DOMAIN_INFERENCE=ZERO'

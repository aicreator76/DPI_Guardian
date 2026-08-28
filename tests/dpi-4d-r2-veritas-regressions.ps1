$ErrorActionPreference='Stop'
$RepoRoot=Split-Path -Parent $PSScriptRoot
$SourceRunner=Join-Path $RepoRoot 'demo\04_SCRIPT\DPI_GUARDIAN_RUN.ps1'
$SourceContract=Join-Path $RepoRoot 'demo\04_SCRIPT\DPI_4D_CONTRACT.ps1'
$Shell=(Get-Command pwsh -ErrorAction SilentlyContinue).Source
if(-not $Shell){$Shell=(Get-Command powershell -ErrorAction Stop).Source}

function New-Source {
  [ordered]@{source_id='SRC_SYN';source_version='v1';authority_ref='AUTH_SYN';valid_from='2026-01-01';valid_to=''}
}
function New-Node([object]$Value,[string]$From='2026-01-01',[string]$To='') {
  [ordered]@{value=$Value;source_ref='SRC_SYN';source_version='v1';valid_from=$From;valid_to=$To;authority_ref='AUTH_SYN'}
}
function New-Relation([object]$From,[object]$To,[object]$Status='') {
  [ordered]@{from=$From;to=$To;status=$Status;source_ref='SRC_SYN';source_version='v1';valid_from='2026-01-01';valid_to='';authority_ref='AUTH_SYN'}
}
function New-ValidCase {
  $worker='WORKER_SYN_001';$role='JOB_ROLE_SYN_001';$risk='RISK_SYN_001';$req='REQ_SYN_001';$ppe='PPE_SYN_001';$evidence='EVIDENCE_SYN_001'
  [ordered]@{
    case_id='VERITAS_BASE';synthetic_fixture=$true;as_of_date='2026-06-01';source_ref='SRC_SYN';source_version='v1';authority_ref='AUTH_SYN';source_registry=@(New-Source);
    cardinality=[ordered]@{assignment_count=1;requirement_count=1};worker_ref=New-Node $worker;job_role_id=New-Node $role;risk_id=New-Node $risk;requirement_id=New-Node $req;ppe_type_id=New-Node $ppe;assigned_ppe=New-Node 'ASSIGNED';evidence_ref=New-Node $evidence;validity=New-Node 'VALID';
    relations=[ordered]@{worker_job_role=New-Relation $worker $role;job_role_risk=New-Relation $role $risk;risk_requirement=New-Relation $risk $req;requirement_ppe=New-Relation $req $ppe;worker_ppe_assignment=New-Relation $worker $ppe 'ASSIGNED';assignment_evidence=New-Relation $ppe $evidence 'PRESENT'}
  }
}
function Run-Case($Case,[string]$Name) {
  $root=Join-Path ([IO.Path]::GetTempPath()) ('dpi4d_nv_'+$Name+'_'+[guid]::NewGuid().ToString('N'))
  $demo=Join-Path $root 'demo';$scriptDir=Join-Path $demo '04_SCRIPT';$inputDir=Join-Path $demo '01_DEMO_DATI'
  New-Item -ItemType Directory -Force -Path $scriptDir,$inputDir|Out-Null
  Copy-Item $SourceRunner (Join-Path $scriptDir 'DPI_GUARDIAN_RUN.ps1')
  Copy-Item $SourceContract (Join-Path $scriptDir 'DPI_4D_CONTRACT.ps1')
  $Case['case_id']=$Name
  $Case|ConvertTo-Json -Depth 20|Set-Content (Join-Path $inputDir 'DPI_4D_CHAIN.json') -Encoding UTF8
  $out=Join-Path $root 'out.txt';$err=Join-Path $root 'err.txt'
  $p=Start-Process -FilePath $Shell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $scriptDir 'DPI_GUARDIAN_RUN.ps1')) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
  $decision=Get-Content (Join-Path $demo '02_OUTPUT\DPI_4D_DECISION.json') -Raw|ConvertFrom-Json
  Remove-Item $root -Recurse -Force
  [pscustomobject]@{ExitCode=$p.ExitCode;Decision=[string]$decision.DECISION;Reason=[string]$decision.REASON_CODE}
}
function Expect-NV([string]$Id,$Case,[string]$Reason) {
  $r=Run-Case $Case $Id
  Write-Host "NV_ATTACK_RESULT ID=$Id EXIT=$($r.ExitCode) DECISION=$($r.Decision) REASON=$($r.Reason)"
  if($r.Decision -cne 'NON_VERIFICATO' -or $r.Reason -cne $Reason){throw "$Id=FAIL actual=$($r.Decision)/$($r.Reason) expected=NON_VERIFICATO/$Reason"}
  Write-Host "$Id=PASS"
}

$c=New-ValidCase;$c['relations']['risk_requirement']['status']='NOT_REQUIRED';Expect-NV 'NV01_RISK_REQUIREMENT_STATUS' $c 'RELATION_STATUS_UNSUPPORTED'
$c=New-ValidCase;$c['relations']['requirement_ppe']['status']='PROHIBITED';Expect-NV 'NV02_REQUIREMENT_PPE_STATUS' $c 'RELATION_STATUS_UNSUPPORTED'
$c=New-ValidCase;$c['relations']['worker_job_role']['status']='REVOKED';Expect-NV 'NV03_WORKER_JOB_ROLE_STATUS' $c 'RELATION_STATUS_UNSUPPORTED'
$c=New-ValidCase;$c['assigned_ppe']['value']='NOT_ASSIGNED';$c['relations']['worker_ppe_assignment']['status']='NOT_ASSIGNED';$c['relations']['risk_requirement']['status']='NOT_REQUIRED';Expect-NV 'NV04_FALSE_GAP_STATUS' $c 'RELATION_STATUS_UNSUPPORTED'
$c=New-ValidCase;$c['validity']['value']='INVALID';$c['validity']['valid_from']='2027-01-01';Expect-NV 'NV05_INVALID_FUTURE_ASOF' $c 'VALIDITY_CONTRADICTION'

Write-Host 'NEW_VERITAS_R2_REGRESSIONS=5/5_BLOCKED'

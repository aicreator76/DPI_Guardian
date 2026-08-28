$ErrorActionPreference='Stop'
$RepoRoot=Split-Path -Parent $PSScriptRoot
$runner=Join-Path $RepoRoot 'demo\04_SCRIPT\DPI_GUARDIAN_RUN.ps1'
$contract=Join-Path $RepoRoot 'demo\04_SCRIPT\DPI_4D_CONTRACT.ps1'
$root=Join-Path ([IO.Path]::GetTempPath()) ('dpi4dr2diag_'+[guid]::NewGuid().ToString('N'))
$demo=Join-Path $root 'demo';$sd=Join-Path $demo '04_SCRIPT';$id=Join-Path $demo '01_DEMO_DATI'
New-Item -ItemType Directory -Force -Path $sd,$id|Out-Null
Copy-Item $runner (Join-Path $sd 'DPI_GUARDIAN_RUN.ps1');Copy-Item $contract (Join-Path $sd 'DPI_4D_CONTRACT.ps1')
$src=[ordered]@{source_id='SRC_SYN';source_version='v1';authority_ref='AUTH_SYN';valid_from='2026-01-01';valid_to=''}
function New-DiagNode($v,$to=''){[ordered]@{value=$v;source_ref='SRC_SYN';source_version='v1';valid_from='2026-01-01';valid_to=$to;authority_ref='AUTH_SYN'}}
function New-DiagRelation($f,$t,$s=''){[ordered]@{from=$f;to=$t;status=$s;source_ref='SRC_SYN';source_version='v1';valid_from='2026-01-01';valid_to='';authority_ref='AUTH_SYN'}}
$w='W';$j='J';$risk='R';$q='Q';$p='P';$e='E'
$c=[ordered]@{case_id='DIAG';synthetic_fixture=$true;as_of_date='2026-06-01';source_ref='SRC_SYN';source_version='v1';authority_ref='AUTH_SYN';source_registry=@($src);worker_ref=(New-DiagNode $w);job_role_id=(New-DiagNode $j);risk_id=(New-DiagNode $risk);requirement_id=(New-DiagNode $q);ppe_type_id=(New-DiagNode $p);assigned_ppe=(New-DiagNode 'ASSIGNED');evidence_ref=(New-DiagNode $e);validity=(New-DiagNode 'VALID');relations=[ordered]@{worker_job_role=(New-DiagRelation $w $j);job_role_risk=(New-DiagRelation $j $risk);risk_requirement=(New-DiagRelation $risk $q);requirement_ppe=(New-DiagRelation $q $p);worker_ppe_assignment=(New-DiagRelation $w $p 'ASSIGNED');assignment_evidence=(New-DiagRelation $p $e 'PRESENT')}}
$c|ConvertTo-Json -Depth 20|Set-Content (Join-Path $id 'DPI_4D_CHAIN.json') -Encoding UTF8
$pwsh=(Get-Command pwsh).Source
$p0=Start-Process $pwsh -ArgumentList @('-NoProfile','-File',(Join-Path $sd 'DPI_GUARDIAN_RUN.ps1')) -Wait -PassThru -NoNewWindow
$d=Get-Content (Join-Path $demo '02_OUTPUT\DPI_4D_DECISION.json') -Raw|ConvertFrom-Json
Write-Host ('DIAG_EXIT='+$p0.ExitCode)
Write-Host ('DIAG_DECISION='+$d.DECISION)
Write-Host ('DIAG_REASON='+$d.REASON_CODE)
Write-Host ('DIAG_TEXT='+$d.REASON_TEXT_MINIMAL)
Remove-Item $root -Recurse -Force
if($d.DECISION -ne 'COVERED'){exit 1}

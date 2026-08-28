# DPI 4D R2 CONTRACT ATTACK MATRIX

STATUS=PRE_FIX_FROZEN
ROLE=CLAUDE_CONTRACT_RED_TEAM_LEAD
BASELINE=28d1272a195703e0e49e248d14f28e7b754b46b1
PURPOSE=Define rejection behavior before R2 implementation.

| ATTACK_ID | INPUT_MUTATION | EXPECTED_DECISION | EXPECTED_REASON | WHY |
|---|---|---|---|---|
| A01 | Unknown top-level field | NON_VERIFICATO | SCHEMA_UNKNOWN_FIELD | Closed schema must not ignore semantics. |
| A02 | Unknown node field | NON_VERIFICATO | SCHEMA_UNKNOWN_FIELD | Node contract must be closed. |
| A03 | Unknown relation field | NON_VERIFICATO | SCHEMA_UNKNOWN_FIELD | Relation contract must be closed. |
| A04 | Unknown source_registry field | NON_VERIFICATO | SCHEMA_UNKNOWN_FIELD | Registry contract must be closed. |
| A05 | Boolean as worker_ref.value | NON_VERIFICATO | SCHEMA_TYPE_INVALID | IDs are strings only. |
| A06 | Integer as risk_id.value | NON_VERIFICATO | SCHEMA_TYPE_INVALID | No numeric coercion. |
| A07 | Array as requirement_id.value | NON_VERIFICATO | SCHEMA_TYPE_INVALID | No array coercion. |
| A08 | Object as ppe_type_id.value | NON_VERIFICATO | SCHEMA_TYPE_INVALID | No object coercion. |
| A09 | Leading whitespace in identifier | NON_VERIFICATO | SCHEMA_TYPE_INVALID | Exact identifiers; no normalization. |
| A10 | Trailing whitespace in source_ref | NON_VERIFICATO | SCHEMA_TYPE_INVALID | Exact source binding. |
| A11 | Empty identifier string | NON_VERIFICATO | SCHEMA_TYPE_INVALID | Empty values are not identifiers. |
| A12 | Null identifier | NON_VERIFICATO | SCHEMA_TYPE_INVALID | Null is not evidence. |
| A13 | Arbitrary unregistered source_ref | NON_VERIFICATO | SOURCE_NOT_BOUND | Provenance requires registry binding. |
| A14 | Missing source registry | NON_VERIFICATO | SOURCE_NOT_BOUND | Tokens alone are not provenance. |
| A15 | Source version differs from registry | NON_VERIFICATO | SOURCE_VERSION_CONFLICT | Version must bind referentially. |
| A16 | Authority differs from registry | NON_VERIFICATO | SOURCE_AUTHORITY_CONFLICT | Authority claim must bind. |
| A17 | valid_from later than valid_to | NON_VERIFICATO | VALIDITY_CONTRADICTION | Impossible source/node interval. |
| A18 | validity.value=VALID but valid_to before AS_OF_DATE | NON_VERIFICATO | VALIDITY_CONTRADICTION | Status and dates conflict. |
| A19 | validity.value=EXPIRED but valid_to after AS_OF_DATE | NON_VERIFICATO | VALIDITY_CONTRADICTION | Status and dates conflict. |
| A20 | assignments[] supplied beside assigned_ppe | NON_VERIFICATO | SCHEMA_CONFLICTING_REPRESENTATION | Minimum supports one representation. |
| A21 | requirements[] supplied beside requirement_id | NON_VERIFICATO | SCHEMA_CONFLICTING_REPRESENTATION | Minimum supports one representation. |
| A22 | alternative_assignments supplied | NON_VERIFICATO | SCHEMA_CONFLICTING_REPRESENTATION | Competing representation forbidden. |
| A23 | alternative_requirements supplied | NON_VERIFICATO | SCHEMA_CONFLICTING_REPRESENTATION | Competing representation forbidden. |
| A24 | relation endpoints contradict node IDs | NON_VERIFICATO | RELATION_CONTRADICTION | Exact referential join required. |
| A25 | duplicate source_id definitions | NON_VERIFICATO | SOURCE_CONFLICT | Registry cannot be ambiguous. |
| A26 | source_id repeated with conflicting claims | NON_VERIFICATO | SOURCE_CONFLICT | One source identity cannot carry two truths. |
| A27 | case_id case mismatch against relation/metadata representation | NON_VERIFICATO | SCHEMA_TYPE_INVALID | No case-folding or fuzzy normalization. |
| A28 | second assignment object hidden in unknown field | NON_VERIFICATO | SCHEMA_UNKNOWN_FIELD | Hidden competing semantics must fail closed. |
| A29 | second requirement object hidden in unknown field | NON_VERIFICATO | SCHEMA_UNKNOWN_FIELD | Hidden competing semantics must fail closed. |
| A30 | cardinality marker >1 for assignment/requirement | NON_VERIFICATO | CARDINALITY_UNSUPPORTED | Minimum is exactly one chain. |

POST_FIX_BLIND_ATTACKS=TO_BE_ADDED_AFTER_IMPLEMENTATION

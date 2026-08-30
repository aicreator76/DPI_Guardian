(function (root, factory) {
  const value = factory();
  if (typeof module === 'object' && module.exports) module.exports = value;
  else root.OP005_CONTRACT = value;
})(typeof self !== 'undefined' ? self : this, function () {
  return {
    slice_id: 'DPI_GUARDIAN_OPERATOR005_EVIDENCE_SLICE_01',
    slice_status: 'SEALED_FOR_NEW_VERITAS',
    generated_at: '2026-08-30T04:14:00+02:00',
    guardrails: {
      core_4d_changed: false,
      scale50_canonical_touched: false,
      founder_wow_freeze_touched: false,
      cesare_archaeology_touched: false,
      legacy_cesare_executed: false,
      false_green_target: 0,
      source_found_is_not_evidence_materialized: true,
      model_is_not_unit: true,
      formation_is_not_addestramento: true
    },
    worker: {
      worker_id: '005',
      name: 'Operatore 005',
      data_class: 'CONTROLLED_SYNTHETIC',
      company: 'CAMELOT DEMO SRL',
      department: 'Manutenzione in quota',
      role: 'Tecnico manutentore',
      status: 'ATTIVO_DEMO_SYNTHETIC',
      formation: {
        status: 'PROVATA',
        evidence_id: 'F005-01',
        evidence_class: 'CONTROLLED_SYNTHETIC',
        description: 'Formazione DPI anticaduta - fixture controllata della slice.'
      },
      addestramento: {
        status: 'NON_VERIFICATO',
        evidence_id: null,
        evidence_class: 'MISSING_EVIDENCE',
        description: 'Nessuna prova di addestramento materializzata nella slice.'
      }
    },
    assignments: [
      {
        assignment_id: 'A005-01',
        worker_id: '005',
        unit_id: 'U005-01',
        assignment_date: '2026-08-30',
        data_class: 'CONTROLLED_SYNTHETIC',
        delivery_evidence: {
          evidence_id: 'DEL-005-01',
          status: 'CONTROLLED_SYNTHETIC',
          description: 'Consegna simulata per validare la catena worker-to-unit.'
        }
      }
    ],
    units: [
      {
        unit_id: 'U005-01',
        unit_class: 'PHYSICAL_UNIT_CONTROLLED_SYNTHETIC',
        serial: 'SYN-EPE-005-0001',
        lot: 'SYN-LOT-2026-005',
        product_id: 'P7330397',
        manufacturer: 'TEUFELBERGER',
        assigned_to: '005',
        assignment_id: 'A005-01',
        assignment_date: '2026-08-30',
        inspection_history: [],
        last_inspection: 'NON_VERIFICATO',
        next_expiry: 'NON_VERIFICATO',
        expiry: 'NON_VERIFICATO',
        status: 'ASSIGNED_RECORD_ONLY',
        claims: {
          safe: 'NON_VERIFICATO',
          fit_for_use: 'NON_VERIFICATO',
          recall_clear: 'NON_VERIFICATO'
        }
      }
    ],
    products: [
      {
        product_id: 'P7330397',
        article_code: '7330397',
        name: 'Energy Pro Evo+',
        family: 'Energy Pro Evo+',
        manufacturer: 'TEUFELBERGER',
        identity_status: 'PROVEN',
        catalog_source: {
          local_copy: '00_MASTER_CATALOG/psa-catalouge-it.pdf',
          page: 13,
          sha256: 'e0cd2761f0acef25c246742e93e5e7d2fad79583a015e6c12bfc8993df64c519',
          status: 'PROVEN'
        },
        product_page: {
          url: 'https://www.teufelberger.com/en/products/energy-pro-evo-1',
          status: 'PROVEN'
        },
        safety_status: 'NOT_FOUND'
      }
    ],
    documents: [
      {
        document_id: 'MANUAL_ENERGY_6801849_2024_12',
        role: 'MANUAL',
        product_ids: ['P7330397'],
        title: 'Energy Pro / Energy Pro Evo+ / Energy Pro Plus - Manufacturer information and instruction for use',
        version: 'Art.-Nr. 6801849 / Ausgabe 12/2024',
        document_date: '2024-12',
        valid_from: '2024-12-01T00:00:00Z',
        valid_to: null,
        source: {
          url: 'https://a.storyblok.com/f/312698/x/7c400c8129/instruction-manual_energy-pro-evo.pdf',
          source_status: 'PROVEN',
          evidence_materialized: 'NO',
          materialization_status: 'REMOTE_ORIGINAL_NOT_MATERIALIZED',
          local_copy: 'NON_VERIFICATO',
          sha256: 'NON_VERIFICATO',
          pages: {
            product_coverage: [1],
            intended_use: [10, 11],
            training_requirements: [10],
            inspection_requirements: [15],
            service_life: [15]
          }
        },
        fields: {
          PRODUCT_COVERAGE: { value: 'Energy Pro Evo+', pages: [1], confidence: 'PROVEN' },
          INTENDED_USE: { value: 'Tower climbing / fall-protection harness family within the defined intended purpose.', pages: [10, 11], confidence: 'PROVEN' },
          TRAINING_REQUIREMENTS: { value: 'Use only by persons trained in safe use with relevant knowledge and skills, or under direct supervision.', pages: [10], confidence: 'PROVEN' },
          INSPECTION_REQUIREMENTS: { value: 'Occupational use requires documented periodic examination at least every 12 months by a duly qualified person or manufacturer.', pages: [15], confidence: 'PROVEN' }
        }
      }
    ],
    event_time_fixture: {
      data_class: 'CONTROLLED_SYNTHETIC_ALGORITHM_TEST_ONLY',
      description: 'Fixture isolata per provare CURRENT_DOCUMENT != DOCUMENT_AT_EVENT_TIME senza affermare storia reale del prodotto.',
      event_at: '2024-06-15T12:00:00Z',
      expected_document_id: 'D-ET-V1',
      versions: [
        {
          document_id: 'D-ET-V1',
          version: 'V1',
          valid_from: '2024-01-01T00:00:00Z',
          valid_to: '2024-12-14T23:59:59Z'
        },
        {
          document_id: 'D-ET-V2',
          version: 'V2',
          valid_from: '2024-12-15T00:00:00Z',
          valid_to: null
        }
      ]
    },
    resident_contract: {
      RESIDENT_OBSERVER: 'osserva / indicizza / segnala',
      DOCUMENT_SPECIALIST: 'recupera e spiega la fonte',
      CESARE: 'trasporta',
      ARTEMIS: 'decide',
      '4D': 'controlla ciò che può essere affermato'
    },
    reuse_class: {
      RESIDENZA: 'REFERENCE_ONLY',
      MONITORAGGIO: 'REFERENCE_ONLY',
      SPECIALISTA_DOCUMENTALE: 'ADAPT',
      GYM_TEST: 'ADAPT',
      SCORECARD: 'ADAPT',
      FAIL_CLOSED: 'USE_NOW',
      SPECIALIZZAZIONE_PER_DOMINIO: 'ADAPT',
      PROVENIENZA_STORICA_END_TO_END: 'PARK'
    },
    founder_query: 'Trovami il manuale del DPI assegnato all\'Operatore 005.'
  };
});

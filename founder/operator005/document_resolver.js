(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.Operator005Resolver = api;
})(typeof self !== 'undefined' ? self : this, function () {
  function result(status, value, reason) {
    return { status, value: value ?? null, reason: reason ?? null };
  }

  function exactOne(rows, predicate, label) {
    const matches = rows.filter(predicate);
    if (matches.length === 0) return result('NON_VERIFICATO', null, `${label}_NOT_FOUND`);
    if (matches.length > 1) return result('NON_VERIFICATO', null, `${label}_AMBIGUOUS_${matches.length}`);
    return result('PASS', matches[0], null);
  }

  function getWorker(contract, workerId) {
    if (String(contract.worker.worker_id) !== String(workerId)) {
      return result('NON_VERIFICATO', null, 'WORKER_NOT_FOUND');
    }
    return result('PASS', contract.worker, null);
  }

  function getAssignmentForWorker(contract, workerId) {
    return exactOne(contract.assignments, x => String(x.worker_id) === String(workerId), 'ASSIGNMENT');
  }

  function getUnit(contract, unitId) {
    return exactOne(contract.units, x => String(x.unit_id) === String(unitId), 'UNIT');
  }

  function getProduct(contract, productId) {
    return exactOne(contract.products, x => String(x.product_id) === String(productId), 'PRODUCT');
  }

  function getDocumentsForProduct(contract, productId) {
    const product = getProduct(contract, productId);
    if (product.status !== 'PASS') return result('NON_VERIFICATO', [], product.reason);
    const docs = contract.documents.filter(d => Array.isArray(d.product_ids) && d.product_ids.includes(productId));
    return docs.length ? result('PASS', docs, null) : result('NON_VERIFICATO', [], 'DOCUMENTS_NOT_FOUND');
  }

  function isActiveAt(doc, isoDate) {
    const at = new Date(isoDate).getTime();
    if (Number.isNaN(at)) return false;
    const from = new Date(doc.valid_from).getTime();
    const to = doc.valid_to ? new Date(doc.valid_to).getTime() : Number.POSITIVE_INFINITY;
    return at >= from && at <= to;
  }

  function getCurrentManual(contract, productId, asOf) {
    const docs = getDocumentsForProduct(contract, productId);
    if (docs.status !== 'PASS') return result('NON_VERIFICATO', null, docs.reason);
    const when = asOf || contract.generated_at;
    return exactOne(docs.value, d => d.role === 'MANUAL' && isActiveAt(d, when), 'CURRENT_MANUAL');
  }

  function getDocumentAtDate(contract, productId, eventDate) {
    const docs = getDocumentsForProduct(contract, productId);
    if (docs.status !== 'PASS') return result('NON_VERIFICATO', null, docs.reason);
    return exactOne(docs.value, d => isActiveAt(d, eventDate), 'EVENT_DOCUMENT');
  }

  function selectDocumentVersionAtDate(versions, eventDate) {
    return exactOne(versions, d => isActiveAt(d, eventDate), 'EVENT_VERSION');
  }

  function getSourceForField(contract, documentId, fieldName) {
    const doc = exactOne(contract.documents, d => d.document_id === documentId, 'DOCUMENT');
    if (doc.status !== 'PASS') return result('NON_VERIFICATO', null, doc.reason);
    const field = doc.value.fields?.[fieldName];
    if (!field) return result('NON_VERIFICATO', null, 'FIELD_NOT_FOUND');
    const pages = Array.isArray(field.pages) ? field.pages : [];
    if (!pages.length) return result('NON_VERIFICATO', null, 'SOURCE_PAGE_NOT_BOUND');
    return result('PASS', {
      document_id: doc.value.document_id,
      field: fieldName,
      value: field.value,
      confidence: field.confidence,
      source: doc.value.source.url,
      pages,
      evidence_materialized: doc.value.source.evidence_materialized,
      materialization_status: doc.value.source.materialization_status,
      local_copy: doc.value.source.local_copy,
      sha256: doc.value.source.sha256
    }, null);
  }

  function getDocumentsForWorker(contract, workerId) {
    const worker = getWorker(contract, workerId);
    if (worker.status !== 'PASS') return result('NON_VERIFICATO', [], worker.reason);
    const assignment = getAssignmentForWorker(contract, workerId);
    if (assignment.status !== 'PASS') return result('NON_VERIFICATO', [], assignment.reason);
    const unit = getUnit(contract, assignment.value.unit_id);
    if (unit.status !== 'PASS') return result('NON_VERIFICATO', [], unit.reason);
    return getDocumentsForProduct(contract, unit.value.product_id);
  }

  function answerFounderQuery(contract, workerId) {
    const worker = getWorker(contract, workerId);
    if (worker.status !== 'PASS') return result('NON_VERIFICATO', null, worker.reason);

    const assignment = getAssignmentForWorker(contract, workerId);
    if (assignment.status !== 'PASS') return result('NON_VERIFICATO', null, assignment.reason);

    const unit = getUnit(contract, assignment.value.unit_id);
    if (unit.status !== 'PASS') return result('NON_VERIFICATO', null, unit.reason);

    const product = getProduct(contract, unit.value.product_id);
    if (product.status !== 'PASS') return result('NON_VERIFICATO', null, product.reason);

    const manual = getCurrentManual(contract, product.value.product_id, contract.generated_at);
    if (manual.status !== 'PASS') return result('NON_VERIFICATO', null, manual.reason);

    const coverage = getSourceForField(contract, manual.value.document_id, 'PRODUCT_COVERAGE');
    if (coverage.status !== 'PASS') return result('NON_VERIFICATO', null, coverage.reason);

    const materialized = manual.value.source.evidence_materialized === 'YES';
    const answerStatus = materialized ? 'PROVEN' : 'PARTIAL_SOURCE_BYTES_NOT_MATERIALIZED';

    const whyHuman = `Questo è il manuale ufficiale che copre ${product.value.name}, il modello collegato all'unità ${unit.value.unit_id} assegnata all'Operatore ${worker.value.worker_id}. La fonte è identificata e la pagina di copertura è nota; la copia remota originale non è materializzata localmente.`;
    const whyTechnical = `worker ${worker.value.worker_id} -> assignment ${assignment.value.assignment_id} -> unit ${unit.value.unit_id} -> product ${product.value.product_id}/article ${product.value.article_code} -> document ${manual.value.document_id} -> source ${manual.value.source.source_status} -> page ${coverage.value.pages.join(',')} -> materialization ${manual.value.source.materialization_status}`;

    return result('PASS', {
      WORKER: worker.value.worker_id,
      ASSIGNMENT: assignment.value.assignment_id,
      UNIT: unit.value.unit_id,
      SERIAL: unit.value.serial,
      LOT: unit.value.lot,
      PRODUCT: product.value.product_id,
      ARTICLE_CODE: product.value.article_code,
      MANUFACTURER: product.value.manufacturer,
      DOCUMENT_TITLE: manual.value.title,
      DOCUMENT_VERSION: manual.value.version,
      DOCUMENT_DATE: manual.value.document_date,
      SOURCE: manual.value.source.url,
      PAGE: coverage.value.pages[0],
      LOCAL_COPY: manual.value.source.local_copy,
      SHA256: manual.value.source.sha256,
      STATUS: answerStatus,
      WHY_SELECTED: whyHuman,
      WHY_HUMAN: whyHuman,
      WHY_TECHNICAL: whyTechnical,
      FORMATION: worker.value.formation.status,
      ADDESTRAMENTO: worker.value.addestramento.status,
      SAFE_TO_USE: unit.value.claims.safe,
      FIT_FOR_USE: unit.value.claims.fit_for_use,
      RECALL_CLEAR: unit.value.claims.recall_clear
    }, null);
  }

  function evaluateGate(contract) {
    const founder = answerFounderQuery(contract, '005');
    const assignment = getAssignmentForWorker(contract, '005');
    const unit = assignment.status === 'PASS' ? getUnit(contract, assignment.value.unit_id) : result('NON_VERIFICATO');
    const product = unit.status === 'PASS' ? getProduct(contract, unit.value.product_id) : result('NON_VERIFICATO');
    const manual = product.status === 'PASS' ? getCurrentManual(contract, product.value.product_id, contract.generated_at) : result('NON_VERIFICATO');
    const source = manual.status === 'PASS' ? getSourceForField(contract, manual.value.document_id, 'PRODUCT_COVERAGE') : result('NON_VERIFICATO');
    const event = selectDocumentVersionAtDate(contract.event_time_fixture.versions, contract.event_time_fixture.event_at);

    const gate = {
      OPERATOR_005_MATERIALIZED: contract.worker.worker_id === '005' ? 'YES' : 'NO',
      WORKER_TO_UNIT: assignment.status === 'PASS' && unit.status === 'PASS' ? 'PASS' : 'FAIL',
      UNIT_TO_PRODUCT: unit.status === 'PASS' && product.status === 'PASS' && unit.value.product_id === product.value.product_id ? 'PASS' : 'FAIL',
      PRODUCT_TO_DOCUMENT: product.status === 'PASS' && manual.status === 'PASS' && manual.value.product_ids.includes(product.value.product_id) ? 'PASS' : 'FAIL',
      DOCUMENT_TO_SOURCE: manual.status === 'PASS' && manual.value.source.source_status === 'PROVEN' ? 'PASS' : 'FAIL',
      SOURCE_TO_PAGE: source.status === 'PASS' && source.value.pages.length > 0 ? 'PASS' : 'FAIL',
      WHY_HUMAN: founder.status === 'PASS' && !!founder.value.WHY_HUMAN ? 'PASS' : 'FAIL',
      WHY_TECHNICAL: founder.status === 'PASS' && !!founder.value.WHY_TECHNICAL ? 'PASS' : 'FAIL',
      FORMATION_SEPARATION: contract.worker.formation.status !== contract.worker.addestramento.status ? 'PASS' : 'FAIL',
      TRAINING_SEPARATION: !Object.prototype.hasOwnProperty.call(contract.worker, 'trained') ? 'PASS' : 'FAIL',
      EVENT_TIME_CASE: event.status === 'PASS' && event.value.document_id === contract.event_time_fixture.expected_document_id ? 'PASS' : 'FAIL',
      FALSE_GREEN: 0
    };
    return gate;
  }

  return {
    getWorker,
    getAssignmentForWorker,
    getUnit,
    getProduct,
    getDocumentsForProduct,
    getCurrentManual,
    getDocumentAtDate,
    getSourceForField,
    getDocumentsForWorker,
    selectDocumentVersionAtDate,
    answerFounderQuery,
    evaluateGate
  };
});

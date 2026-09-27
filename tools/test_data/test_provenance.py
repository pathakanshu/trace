import copy
import unittest
from audit_provenance import dag_errors,provenance_errors
from generate_queries import ROOT,read_catalog


def sample():
    org={'id':'org-000001','kind':'organization','organization_type':'POLICE_RESCUE'}
    contributor={'id':'act-000001','kind':'contributor'}
    source={'id':'src-000001','kind':'source','incident_id':'inc-000001','publisher':{'kind':'organization','id':org['id']},'report_reference':'LOCAL-1','source_type':'POLICE_RESCUE','dependencies':[],'dependency_disclosure':'no_dependency_declared'}
    return [org,contributor,source]


class ProvenanceTests(unittest.TestCase):
    def test_current_catalog_scope_and_dag_checks_pass_but_no_correction_edges_exist(self):
        errors,observed=provenance_errors(list(read_catalog(ROOT).values()))
        self.assertEqual(errors,[])
        self.assertEqual(observed,{'sources_checked':1800,'unique_publication_scopes':1800,'declared_dependency_edges':450,'claim_correction_edges':0})

    def test_topological_order_ignores_numeric_id_order_and_handles_long_chains(self):
        self.assertEqual(dag_errors(['src-1','src-2'],[('src-1','src-2')],'lineage'),[])
        nodes=[str(i) for i in range(5000)]
        self.assertEqual(dag_errors(nodes,list(zip(nodes,nodes[1:])),'lineage'),[])

    def test_dags_reject_cycle_self_missing_and_duplicate_edges(self):
        for edges,fragment in [([('a','b'),('b','a')],'cycle'),([('a','a')],'self-reference'),([('a','missing')],'missing endpoint'),([('a','b'),('a','b')],'duplicate edge')]:
            with self.subTest(edges=edges):self.assertTrue(any(fragment in error for error in dag_errors(['a','b'],edges,'lineage')))

    def test_reference_uniqueness_is_scoped_to_incident_and_typed_publisher(self):
        rows=sample();other=copy.deepcopy(rows[-1]);other['id']='src-000002';rows.append(other)
        self.assertTrue(any('duplicates' in error for error in provenance_errors(rows)[0]))
        other['incident_id']='inc-000002';self.assertEqual(provenance_errors(rows)[0],[])
        other['incident_id']='inc-000001';other['publisher']={'kind':'contributor','id':'act-000001'};other['source_type']='INDIVIDUAL'
        self.assertEqual(provenance_errors(rows)[0],[])

    def test_organization_contributor_and_unknown_publisher_types(self):
        for publisher,source_type,fragment in [({'kind':'organization','id':'org-000001'},'HOSPITAL','differs'),({'kind':'contributor','id':'act-000001'},'HOSPITAL','institutional'),({'kind':'organization','id':'act-000001'},'POLICE_RESCUE','wrong-kind'),({'kind':'organization','id':'org-999999'},'POLICE_RESCUE','missing')]:
            rows=sample();rows[-1]['publisher']=publisher;rows[-1]['source_type']=source_type
            self.assertTrue(any(fragment in error for error in provenance_errors(rows)[0]))

    def test_disclosure_requires_matching_presence_of_dependencies(self):
        rows=sample();rows[-1]['dependency_disclosure']='declared'
        self.assertTrue(any('no source reference' in error for error in provenance_errors(rows)[0]))
        rows[-1]['dependencies']=[{'source_id':'src-000002','relationship':'cites'}]
        other=copy.deepcopy(rows[-1]);other.update(id='src-000002',report_reference='LOCAL-2',dependencies=[],dependency_disclosure='unknown');rows.append(other)
        self.assertEqual(provenance_errors(rows)[0],[])
        rows[-2]['dependency_disclosure']='unknown'
        self.assertTrue(any('contradict' in error for error in provenance_errors(rows)[0]))

    def test_correction_graph_cycles_are_checked_independently(self):
        rows=sample()+[{'id':'clm-000001','kind':'claim','corrects_claim_ids':['clm-000002']},{'id':'clm-000002','kind':'claim','corrects_claim_ids':[]}]
        self.assertEqual(provenance_errors(rows)[0],[])
        rows[-1]['corrects_claim_ids']=['clm-000001']
        self.assertTrue(any('claim corrections: cycle' in error for error in provenance_errors(rows)[0]))

    def test_fixture_audit_does_not_mutate_input_records(self):
        rows=sample();before=copy.deepcopy(rows);provenance_errors(rows);self.assertEqual(rows,before)


if __name__=='__main__':unittest.main()

/* Indexing eQTL collection to cover all API queries 
 *   BRAVO database needs to be specified at the command line 
 */

let cpra_idx    = {'chrom': 1, 'pos': 1}
let pheno_idx   = {'phenotype_id': 1}
let var_idx     = {'variant_id': 1}
let credset_idx = {'tissue': 1, 'phenotype_id': 1, 'cs_id': 1}

db.eqtl_susie.createIndex(cpra_idx)
db.eqtl_susie.createIndex(pheno_idx)
db.eqtl_susie.createIndex(var_idx)
db.eqtl_susie.createIndex(credset_idx, {'name': 'credset_idx'})
